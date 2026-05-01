# Audiveris PDF Conversion Backend with User Isolation & Note Labels

A FastAPI backend service with **user isolation and data security** that accepts PDF uploads, queues them for processing, uses Audiveris HTTP API to convert PDFs to JSON, and overlays note pitch labels on annotated PDFs. All outputs are stored in Supabase Storage with full user authentication and Row-Level Security (RLS).

## ✨ Key Features

- **User Isolation**: Every file is linked to the authenticated user who uploaded it
- **Data Security**: Row-Level Security (RLS) prevents users from accessing other users' data
- **JWT Authentication**: Secure endpoints with Supabase Auth
- **Rate Limiting**: Redis-backed, user-scoped rate limits on every endpoint (10/min upload, 100/min API)
- **CORS Protection**: Explicit trusted-origin allowlist — no wildcard `*` with credentials
- **Admin Authorization**: `/admin/*` routes gated by `ADMIN_USER_IDS` env var (fail-secure)
- **Queue Overflow Protection**: Rejects uploads with HTTP 503 when queue depth ≥ `MAX_QUEUE_DEPTH`
- **Per-User Job Cap**: Enforces max concurrent in-flight jobs per user (HTTP 429)
- **Note Label Overlay**: Automatic pitch label generation (e.g., "A4", "E5") on sheet music PDFs
- **Dual Output Format**: JSON (Audiveris output) + Labeled PDF (annotated with note names)
- **Orphan Detection**: Built-in tools to detect and clean up orphaned files
- **Horizontal Scalable**: Redis-ready queue and PostgreSQL backend
- **File Validation**: MIME type and size validation
- **Graceful Error Handling**: Labeling failures don't prevent JSON access
- **TCP Connection Reuse**: Per-worker `requests.Session` reduces Audiveris API latency
- **Compact JSON Storage**: In-memory pipeline eliminates redundant storage round-trip

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTHENTICATED USER                        │
│              (Supabase Auth JWT Token)                       │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────▼────────┐
        │   Load Balancer  │
        │   (Nginx/HAProxy)│
        └────────┬────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│  API-1  │ │  API-2  │ │  API-3  │
│(FastAPI)│ │(FastAPI)│ │(FastAPI)│
└────┬────┘ └────┬────┘ └────┬────┘
     │           │           │
     └───────────┼───────────┘
                 │
        ┌────────▼────────────┐
        │   Redis Instance    │
        │  (Persistent Queue) │
        │  [RQ: sheet_jobs]   │
        └────────┬────────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Worker-1 │ │ Worker-2 │ │ Worker-3 │
│ (RQ Proc)│ │ (RQ Proc)│ │ (RQ Proc)│
│ (via SV) │ │ (via SV) │ │ (via SV) │
└────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │
     └────────────┼────────────┘
                  │
        ┌─────────▼──────────┐
        │   Audiveris API    │
        │   (HTTP Service)   │
        └─────────┬──────────┘
                  │
        ┌─────────▼──────────┐
        │  Supabase          │
        │ ┌─────────────────┐│
        │ │  PostgreSQL DB  ││  jobs (user_id -> jobs)
        │ │  jobs table     ││  sheet_files (user_id -> files)
        │ │  sheet_files    ││  RLS policies enforce isolation
        │ └─────────────────┘│
        │ ┌─────────────────┐│
        │ │  Storage        ││  sheet_data bucket
        │ │  (with RLS)     ││  pdf_uploads bucket
        │ │  {user_id}/...  ││  User-scoped paths
        │ └─────────────────┘│
        └────────────────────┘
```

## Queue Architecture (Redis + RQ)

This backend uses **Redis Queue (RQ)** for job persistence and distributed worker processing:

- **Redis**: Persistent job queue at `redis://localhost:6379` (or remote Redis URL)
- **RQ Queue**: Named `sheet_jobs` with 15-minute per-job timeout (`900s`)
- **Workers**: Standalone Python processes managed by Supervisor
  - Each worker pulls jobs from the `sheet_jobs` queue
  - Multiple workers process jobs in parallel
  - Supervisor automatically restarts crashed workers
- **Persistence**: Jobs survive server restarts (stored in Redis)
- **Scaling**: Add more workers by adding `[program:workerN]` blocks to Supervisor config

### Advantages over in-memory queue

| Feature | In-Memory Queue | Redis + RQ |
|---------|-----------------|-----------|
| **Persistence** | Lost on restart | Survives restarts |
| **Parallel Workers** | 1 thread | 4+ independent processes |
| **Horizontal Scaling** | Single server | Multi-server shared queue |
| **Crash Recovery** | Manual restart | Automatic via Supervisor |
| **Job Monitoring** | Custom code | `rq info` CLI tool |
| **Deployment** | Simple | Production-ready |

## Job Lifecycle

1. **Upload**: User uploads PDF via `POST /convert` with JWT token
   - ✅ Validates JWT token
   - ✅ Validates MIME type (PDF/JPEG) and file size (≤100MB)
   - ✅ Generates unique `job_id`
   - ✅ Uploads PDF to `pdf_uploads/{user_id}/{job_id}/input.pdf` (user-scoped)
   - ✅ Creates job record in PostgreSQL with `user_id` FK
   - ✅ Enqueues to FIFO queue
   - ✅ Returns immediately with `job_id` and status `queued`

2. **Processing** (Dispatcher Background Thread):
   - ✅ Download `input.pdf` from storage
   - ✅ Run Audiveris API → generate `output.json`
   - ✅ Save JSON to `sheet_data/{user_id}/{job_id}/output.json`
   - ✅ **Run label_notes.py** → overlay note pitch labels
   - ✅ Save labeled PDF to `pdf_uploads/{user_id}/{job_id}/labeled.pdf`
   - ✅ Update job status and label_status
   - Status: `completed` (if labeling succeeds) or `completed_with_warning` (if labeling fails)

3. **Retrieval**: User gets results via protected endpoints
   - `GET /sheets/{job_id}` → Download JSON output
   - `GET /sheets/{job_id}/pdf` → Download labeled PDF
   - `GET /sheets/{job_id}/status` → Check job status + labeling status

## Job Processing Pipeline

Jobs are processed by **independent RQ worker processes** (not background threads):

1. **Enqueue**: API receives upload and calls `enqueue_job({"job_id": job_id})`
   - Queries DB to check if job status is `"queued"` (prevents re-enqueuing)
   - If already `processing`/`completed`/`completed_with_warning`/`failed`, skips enqueue
   - Otherwise, pushes job to Redis queue `sheet_jobs`

2. **Worker Pickup**: One of 4 RQ workers picks up the job
   - Worker calls `process_job(job_data)` synchronously
   - Worker fetches full job record from DB
   - Duplicate guard: returns immediately if job is already terminal

3. **Stuck Job Recovery**: At start of every job
   - Queries for jobs stuck in `processing` for >15 minutes
   - Marks them `failed` with error message: "Job timed out — worker likely crashed"
   - Prevents stuck jobs from being lost if worker crashes

4. **Processing**: Download PDF → Audiveris API → JSON → label_notes → labeled PDF
   - Status updates: `processing` → `completed`/`completed_with_warning`/`failed`

5. **Supervision**: Supervisor monitors all processes
   - If a worker crashes, Supervisor automatically restarts it
   - If FastAPI crashes, Supervisor automatically restarts it
   - All processes are configured with `autostart=true` and `autorestart=true`

### Process Flow

```
FastAPI (Supervisor)          RQ Worker 1 (Supervisor)
        │                              │
   POST /convert                      │
        │                              │
   enqueue_job()  ──Redis───>  Worker dequeue()
        │                              │
        ├─ check status                │
        │                              ├─ recover stuck jobs
        │                              │
        ├─ skip if terminal            ├─ fetch job from DB
        │                              │
        └─ push to queue               ├─ duplicate guard
           (returns 202)               │
                                       ├─ mark "processing"
                                       │
                                       ├─ download PDF
                                       │
                                       ├─ Audiveris API
                                       │
                                       ├─ save JSON
                                       │
                                       ├─ label_notes
                                       │
                                       ├─ save labeled PDF
                                       │
                                       └─ mark "completed"
```

**Key differences from in-memory queue:**
- ✅ **Parallel**: 4 workers run simultaneously (vs. 1 thread)
- ✅ **Persistent**: Jobs survive Redis restart
- ✅ **Recoverable**: Stuck jobs auto-detected and marked failed
- ✅ **Supervised**: Supervisor monitors and restarts workers
- ✅ **Monitorable**: Use `rq info` to see queue depth and worker status

## How the Label_Notes Pipeline Works

The **label_notes** module processes Audiveris JSON output to automatically overlay musical note pitch labels on PDF pages:

- **Input**: Original PDF + Audiveris MusicXML JSON with note geometry and pitch data
- **Processing**:
  1. Parse JSON for note positions, clefs, and pitches
  2. Derive all geometry from JSON values (scaling, margins, staff layout)
  3. Reconstruct coordinate system calibrated to actual PDF page dimensions
  4. Iterate over measures and notes, computing screen positions
  5. Handle collisions (overlapping labels) by bumping labels downward
  6. Insert pitch labels (e.g., "A4", "G#5", "Bb3") below each note head
- **Output**: Annotated PDF with readable pitch labels
- **Error Handling**: If labeling fails, JSON is still preserved and returned

### Supported Features

- Single-staff and grand staff (treble + bass) scores
- Multi-system and multi-page scores
- Accidentals (sharps `#`, flats `b`)
- All clefs (treble G, bass F, alto C)
- Collision detection and smart label placement
- Optional debug mode (draws geometry guides)

## Dependencies

### Core Framework
- **fastapi** (0.104.1): Web framework
- **uvicorn** (0.24.0): ASGI server

### Queue & Workers
- **redis** (5.0.1): Redis client library
- **rq** (1.16.2): Redis Queue for job processing
- **rq-dashboard** (0.6.1): Optional monitoring UI for RQ jobs

### Database & Storage
- **supabase** (2.0.0): PostgreSQL + Storage client
- **pydantic** (2.5.0): Data validation

### Security & Auth
- **pyjwt** (2.8.0): JWT token handling
- **slowapi** (0.1.9): Rate limiting middleware for FastAPI (Redis-backed moving-window strategy)

### File Processing
- **pymupdf** (1.23.8): PDF manipulation for label overlay

### Utilities
- **requests** (2.31.0): HTTP client for Audiveris API
- **python-dotenv** (1.0.0): Environment variable management
- **python-multipart** (0.0.9): File upload handling

See `requirements.txt` for exact versions.

The backend treats Audiveris as a **black-box HTTP service**:

- **Endpoint**: `POST {AUDIVERIS_API_URL}?format=json`
- **Method**: HTTP POST with multipart/form-data
- **Input**: PDF file uploaded as form field `file`
- **Output**: MusicXML JSON response with note geometry and pitch data
- **Error Handling**: Raises exception if status code is not 200

The backend **never** runs Audiveris CLI directly - it only makes HTTP requests.

## Setup

### 0. Install System Dependencies (macOS)

```bash
# Install Redis (persistent job queue)
brew install redis

# Install Supervisor (process manager for workers)
brew install supervisor

# Start Redis service
brew services start redis

# Verify Redis is running
redis-cli ping  # Should respond with PONG
```

For **Linux** (Ubuntu/Debian):
```bash
sudo apt install redis-server supervisor
sudo systemctl start redis-server
```

### 1. Install Python Dependencies

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate  # or: . .venv/bin/activate.fish
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Audiveris API
AUDIVERIS_API_URL=http://localhost:8080
REQUEST_TIMEOUT=300

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-public-key

# Storage Buckets
SUPABASE_BUCKET=sheet_data
PDF_BUCKET=pdf_uploads

# File Size Limits
MAX_FILE_SIZE=104857600

# Redis Configuration
REDIS_URL=redis://localhost:6379

# ── Security ──────────────────────────────────────────────────────────
# CORS: comma-separated list of trusted origins.
# NEVER use * in production — browsers reject * with credentials=true.
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8081,http://localhost:8000

# Rate limits (format: "<count>/<period>" — second|minute|hour|day)
RATE_LIMIT_UPLOAD=10/minute
RATE_LIMIT_API=100/minute
RATE_LIMIT_HEALTH=60/minute
RATE_LIMIT_ADMIN=20/minute

# Admin: comma-separated Supabase UUIDs. Empty = all admin access blocked (fail-secure).
ADMIN_USER_IDS=

# Queue / concurrency limits
MAX_QUEUE_DEPTH=200
MAX_CONCURRENT_JOBS_PER_USER=5

# Environment
ENVIRONMENT=development
```

> **Production note**: always set `ALLOWED_ORIGINS` to your real domain(s) and populate `ADMIN_USER_IDS` with the Supabase UUIDs of admin users.

### 3. Create Supabase Storage Buckets

In your Supabase dashboard:

1. Go to **Storage** → **New Bucket**
2. Create `pdf_uploads` bucket (for PDFs)
3. Create `sheet_data` bucket (for JSON outputs)
4. For each bucket, go to **Policies** and add:

```sql
-- Allow users to only access files in their user_id folder
(bucket_id = 'pdf_uploads'::text) AND 
(auth.uid()::text = (storage.foldername[1])::text)
```

### 4. Apply Database Migration

Run this in your Supabase SQL editor:

```sql
-- From: migrations/001_user_isolation.sql
```

This creates:
- `jobs` table with columns: `id`, `user_id`, `pdf_path`, `result_url`, `status`, `label_status`, `label_warning`, `error_message`, `created_at`, `updated_at`
- `sheet_files` table for tracking stored files
- RLS policies enforcing user isolation

### 5. Run FastAPI Locally (Testing Only)

```bash
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The startup logs should show:
```
INFO:app.main:Starting application...
INFO:app.main:Redis connection verified
INFO:app.main:Application started
```

If Redis is not running, startup will fail with:
```
ERROR: Redis is not available — cannot start server
```

### 6. Run Workers Locally (Testing Only)

In separate terminal windows (with `.venv` activated):

```bash
# Terminal 1
.venv/bin/python worker.py

# Terminal 2
.venv/bin/python worker.py

# Terminal 3
.venv/bin/python worker.py

# Terminal 4
.venv/bin/python worker.py
```

Each worker logs:
```
Starting RQ worker on queue 'sheet_jobs' (Redis: redis://localhost:6379)
Worker rq:worker:xxx started with PID yyyy
*** Listening on sheet_jobs...
```

### 7. Deploy with Supervisor (Production)

Copy the Supervisor configuration and reload:

```bash
# macOS (Homebrew)
sudo cp supervisor.conf /opt/homebrew/etc/supervisor.d/backend.ini

# Linux (Ubuntu)
sudo cp supervisor.conf /etc/supervisor/conf.d/backend.conf

# Reload Supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
sudo supervisorctl status
```

Expected output:
```
fastapi                          RUNNING   pid 12345, uptime 0:00:30
worker1                          RUNNING   pid 12346, uptime 0:00:30
worker2                          RUNNING   pid 12347, uptime 0:00:30
worker3                          RUNNING   pid 12348, uptime 0:00:30
worker4                          RUNNING   pid 12349, uptime 0:00:30
```

### 0. Install Supabase Storage Buckets

In your Supabase dashboard, create two buckets:

## API Endpoints (8 Total)

### Public Endpoints

#### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy"
}
```

### Protected Endpoints (Require JWT Authorization Header)

#### POST /convert

Upload a PDF file for OCR conversion and note labeling.

**Request:**
- Method: `POST`
- Content-Type: `multipart/form-data`
- Headers: `Authorization: Bearer <jwt_token>`
- Body: PDF or JPEG file

**Response:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued",
  "user_id": "user-uuid"
}
```

#### GET /jobs

List all jobs for authenticated user (paginated).

**Query Parameters:**
- `limit` (int, default 50): Number of results
- `offset` (int, default 0): Pagination offset

**Response:**
```json
{
  "jobs": [
    {
      "id": "job-id",
      "status": "completed",
      "created_at": "2026-03-07T10:00:00Z",
      "label_status": "success"
    }
  ],
  "total": 42,
  "user_id": "user-uuid"
}
```

#### GET /jobs/{job_id}

Get single job status (legacy endpoint).

**Response:**
```json
{
  "job_id": "job-id",
  "status": "completed",
  "user_id": "user-uuid",
  "result_url": "sheet_data/{user_id}/{job_id}/output.json"
}
```

#### GET /sheets/{job_id}

Download the Audiveris JSON output (note geometry and pitch data).

**Response:** JSON file (application/json)

Example response structure:
```json
{
  "score-partwise": {
    "defaults": { "scaling": { "millimeters": 7.05, "tenths": 40 } },
    "part": {
      "measure": [
        {
          "attributes": { "clef": { "sign": "G" } },
          "note": [
            {
              "@default-x": 50,
              "pitch": { "step": "A", "octave": 4 },
              "duration": 4
            }
          ]
        }
      ]
    }
  }
}
```

#### GET /sheets/{job_id}/pdf

**Download labeled PDF** with note pitch labels overlaid on the sheet music.

**Response:** PDF file (application/pdf)

This returns the annotated PDF with labels like "A4", "E5", "G#3" below each note.

#### GET /sheets/{job_id}/status

Get detailed job status including both Audiveris and labeling results.

**Response (success):**
```json
{
  "job_id": "job-id",
  "status": "completed",
  "user_id": "user-uuid",
  "json_ready": true,
  "pdf_ready": true,
  "label_status": "success",
  "created_at": "2026-03-07T10:00:00Z",
  "updated_at": "2026-03-07T10:05:00Z"
}
```

**Response (labeling failed but JSON available):**
```json
{
  "job_id": "job-id",
  "status": "completed_with_warning",
  "user_id": "user-uuid",
  "json_ready": true,
  "pdf_ready": false,
  "label_status": "failed",
  "warning": "Note labeling failed: corrupted JSON geometry",
  "created_at": "2026-03-07T10:00:00Z",
  "updated_at": "2026-03-07T10:05:00Z"
}
```

**Response (still processing):**
```json
{
  "job_id": "job-id",
  "status": "processing",
  "user_id": "user-uuid",
  "json_ready": false,
  "pdf_ready": false,
  "created_at": "2026-03-07T10:00:00Z",
  "updated_at": "2026-03-07T10:00:30Z"
}
```

#### DELETE /sheets/{job_id}

Delete a job and all associated files (PDF, JSON, labeled PDF).

**Response:**
```json
{
  "message": "Sheet deleted successfully"
}
```

### Admin Endpoints

#### GET /admin/orphans/detect

Detect orphaned files (storage files without DB records, and vice versa).

**Response:**
```json
{
  "orphaned_storage_files": ["path1", "path2"],
  "orphaned_db_records": [
    {
      "file_id": "uuid",
      "user_id": "uuid",
      "storage_path": "path"
    }
  ],
  "is_healthy": false,
  "total_storage_files": 150,
  "total_db_records": 148
}
```

#### POST /admin/orphans/cleanup

Clean up orphaned files (with optional dry-run).

**Query Parameters:**
- `dry_run` (bool, default true): If true, only report without deleting

**Response:**
```json
{
  "dry_run": false,
  "report": { "..." },
  "actions": {
    "deleted_storage_files": ["path1"],
    "deleted_db_records": [],
    "marked_orphaned": ["file_id"]
  }
}
```

## Project Structure

```
backend/
├── .env                          # Environment variables (DO NOT COMMIT)
├── .env.example                  # Template for .env
├── .gitignore                    # Git ignore patterns
├── requirements.txt              # Python dependencies
├── README.md                     # This file
├── PROJECT_STRUCTURE.md          # Architecture documentation
│
├── app/                          # Main application package
│   ├── __init__.py              # Package initializer
│   ├── main.py                  # FastAPI app with 8 endpoints
│   ├── config.py                # Configuration from environment
│   ├── models.py                # Data models (JobStore, JobStatus)
│   │
│   ├── auth.py                  # JWT authentication, user verification & require_admin
│   ├── database.py              # PostgreSQL operations with RLS
│   ├── storage.py               # Supabase Storage operations
│   ├── limiter.py               # Redis-backed rate limiter (user-scoped key function)
│   ├── queue.py                 # Redis job queue with overflow guard (QueueFullError)
│   │
│   ├── audiveris_client.py      # OCR service HTTP client
│   ├── dispatcher.py            # Background job processor
│   ├── label_notes.py           # Note label overlay module ← NEW
│   └── orphan_detector.py       # Data integrity monitoring
│
├── migrations/
│   └── 001_user_isolation.sql   # Database schema with RLS
│
└── jobs/                         # Temporary job directories (gitignored)
```

## Storage Structure

```
Supabase Storage:

pdf_uploads/                     # PDF files
├── {user_id}/
│   └── {job_id}/
│       ├── input.pdf           # Original upload
│       └── labeled.pdf         # Note labels overlaid ← NEW

sheet_data/                      # JSON outputs
├── {user_id}/
│   └── {job_id}/
│       └── output.json         # Audiveris MusicXML JSON
```

## Database Schema

### jobs table
```sql
id              UUID PRIMARY KEY
user_id         UUID NOT NULL (FK → auth.users)
pdf_path        TEXT            -- Storage path to input.pdf
result_url      TEXT            -- URL to output.json
status          TEXT            -- 'pending'|'processing'|'completed'|'completed_with_warning'|'failed'
label_status    TEXT            -- 'success'|'failed'|NULL
error_message   TEXT            -- Audiveris error message (if failed)
label_warning   TEXT            -- Labeling error message (if failed)
created_at      TIMESTAMPTZ
updated_at      TIMESTAMPTZ
```

### sheet_files table
```sql
id              UUID PRIMARY KEY
user_id         UUID NOT NULL (FK → auth.users)
job_id          UUID NOT NULL (FK → jobs)
storage_path    TEXT            -- Full path in storage
file_size_bytes BIGINT
status          TEXT            -- 'processing'|'completed'|'failed'|'orphaned'
created_at      TIMESTAMPTZ
updated_at      TIMESTAMPTZ
```

Both tables have RLS policies enforcing `user_id = auth.uid()`

## Error Handling & Status Codes

### HTTP Error Codes

| Code | Endpoint | Cause |
|------|----------|-------|
| `400` | `POST /convert` | Wrong MIME type (not PDF/JPEG) |
| `401` | All protected | Missing or expired JWT token |
| `403` | `/admin/*` | User not in `ADMIN_USER_IDS` |
| `404` | `/jobs/{id}`, `/sheets/{id}` | Job not found or owned by another user |
| `413` | `POST /convert` | File exceeds `MAX_FILE_SIZE` (100 MB) |
| `429` | `POST /convert` | User has ≥ `MAX_CONCURRENT_JOBS_PER_USER` active jobs, **or** rate limit exceeded |
| `500` | Any | Unexpected server error |
| `503` | `POST /convert` | Queue depth ≥ `MAX_QUEUE_DEPTH` — retry later |

### Job Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Queued but not started |
| `processing` | Currently running Audiveris |
| `completed` | Audiveris succeeded AND labeling succeeded |
| `completed_with_warning` | Audiveris succeeded BUT labeling failed (JSON still available) |
| `failed` | Audiveris failed (JSON not available) |

### Label Status Values

| Status | Meaning |
|--------|---------|
| `null` | Labeling not attempted (Audiveris failed) |
| `success` | Note labels successfully overlaid |
| `failed` | Labeling failed but JSON is preserved |

### Recovery Strategy

- **Audiveris fails** → Job marked `failed`, user cannot retrieve any output
- **Labeling fails** → Job marked `completed_with_warning`, user can retrieve JSON but not labeled PDF
  - API returns `warning` field with error message
  - `pdf_ready` flag is `false`
  - `json_ready` flag is `true`

This graceful degradation ensures users always have access to the Audiveris JSON output, even if labeling fails.

## Security Model

### Rate Limiting

All endpoints are rate-limited via [`app/limiter.py`](app/limiter.py) using **slowapi** with a Redis moving-window strategy:

| Endpoint group | Default limit | Env var |
|---------------|--------------|--------|
| `POST /convert` (upload) | 10/minute | `RATE_LIMIT_UPLOAD` |
| All other API endpoints | 100/minute | `RATE_LIMIT_API` |
| `GET /health` | 60/minute | `RATE_LIMIT_HEALTH` |
| `/admin/*` | 20/minute | `RATE_LIMIT_ADMIN` |

- Keys are **user-scoped** when a valid Bearer token is present (`user:<uuid>`)
- Falls back to **IP-based** key for unauthenticated requests
- `swallow_errors` must stay disabled so Redis failures do not fail open
- Returns `429 Too Many Requests` on breach

### CORS

`allow_origins` is set to an explicit allowlist loaded from the `ALLOWED_ORIGINS` environment variable.  
Wildcard `*` is **never used** because it is invalid with `allow_credentials=True` and exposes the API to CSRF-style cross-origin attacks.

### Admin Authorization

`/admin/*` routes use `Depends(require_admin)` — only Supabase UUIDs listed in `ADMIN_USER_IDS` are granted access. An empty `ADMIN_USER_IDS` blocks all admin access by default (fail-secure).

### Queue & Upload Protection

- **Queue overflow**: `POST /convert` returns **HTTP 503** when the Redis queue depth reaches `MAX_QUEUE_DEPTH` (default 200). The job is marked `failed` immediately so it doesn't linger as `pending`.
- **Per-user cap**: `POST /convert` checks active (pending/queued/processing) job count before any storage I/O. Returns **HTTP 429** if the user already has ≥ `MAX_CONCURRENT_JOBS_PER_USER` (default 5) jobs in flight.

---

## Constraints & Design Decisions

- ✅ **Non-blocking**: API requests return immediately after upload
- ✅ **Parallel Workers**: 4 RQ workers run simultaneously
- ✅ **HTTP-only**: Backend never runs Audiveris CLI directly
- ✅ **Queue-based**: Jobs processed in FIFO order
- ✅ **Deterministic Labeling**: Same PDF+JSON always produces identical labeled PDF
- ✅ **User Isolation**: RLS enforced on all database and storage operations
- ✅ **Graceful Degradation**: Labeling failures don't prevent JSON access
- ✅ **In-Memory JSON Pipeline**: JSON is normalized in-process — no storage round-trip
- ✅ **TCP Connection Reuse**: One `requests.Session` per worker process
- ❌ **No Parallel Labeling**: Labeling runs sequentially after Audiveris (future optimization opportunity)
- ℹ️ **Redis Required**: Used for both the job queue and rate-limiting storage

## Testing

### 1. Health Check

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{"status": "healthy"}
```

### 2. Upload PDF

```bash
curl -X POST "http://localhost:8000/convert" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -F "file=@example.pdf"
```

Example response:
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "queued",
  "user_id": "user-uuid"
}
```

### 3. Check Job Status

```bash
curl "http://localhost:8000/sheets/{job_id}/status" \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

Expected response:
```json
{
  "job_id": "...",
  "status": "processing",
  "json_ready": false,
  "pdf_ready": false
}
```

### 4. Download JSON (when ready)

```bash
curl "http://localhost:8000/sheets/{job_id}" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -o output.json
```

### 5. Download Labeled PDF (when ready)

```bash
curl "http://localhost:8000/sheets/{job_id}/pdf" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -o labeled.pdf
```

### 6. Monitor Dispatcher Logs

While processing is running, watch the server logs:
```
[INFO] Processing job {job_id} for user {user_id}
[INFO] Downloading PDF from ...
[INFO] Calling Audiveris API for job {job_id}
[INFO] Running label_notes for job {job_id}
[INFO] Uploading labeled PDF for job {job_id}
[INFO] Job {job_id} completed with status=completed, label_status=success
```

## Deployment Checklist

### Development (Local Testing with Supervisor)

- [ ] Install Redis: `brew install redis && brew services start redis`
- [ ] Install Supervisor: `brew install supervisor`
- [ ] Install Python deps: `pip install -r requirements.txt`
- [ ] Create `.env` file with Supabase and Audiveris credentials
- [ ] Set `ALLOWED_ORIGINS` to your production domain(s)
- [ ] Set `ADMIN_USER_IDS` to comma-separated Supabase UUIDs for admin users
- [ ] Tune `RATE_LIMIT_UPLOAD`, `RATE_LIMIT_API`, `MAX_QUEUE_DEPTH`, `MAX_CONCURRENT_JOBS_PER_USER` as needed
- [ ] Verify Redis: `redis-cli ping` → `PONG`
- [ ] Apply database migration in Supabase
- [ ] Create `pdf_uploads` and `sheet_data` buckets
- [ ] Set bucket RLS policies for user isolation
- [ ] Verify Audiveris API is running and accessible
- [ ] Copy Supervisor config: `cp supervisor.conf /opt/homebrew/etc/supervisor.d/backend.ini` (macOS)
- [ ] Reload Supervisor: `supervisorctl reread && supervisorctl update`
- [ ] Start all processes: `supervisorctl start all`
- [ ] Check status: `supervisorctl status` (should show 5 RUNNING)
- [ ] Test health endpoint: `curl http://localhost:8000/health`
- [ ] Test full pipeline with sample PDF
- [ ] Verify labeled PDF output contains note labels
- [ ] Check logs: `tail -f logs/fastapi.out.log` and `tail -f logs/worker1.out.log`
- [ ] Monitor queue: `.venv/bin/rq info --url redis://localhost:6379`

### Production (Ubuntu Server)

- [ ] Install Redis: `sudo apt install redis-server && sudo systemctl start redis-server`
- [ ] Install Supervisor: `sudo apt install supervisor`
- [ ] Install Python 3.11+ and pip
- [ ] Create project directory: `/home/ubuntu/Re-Hers/backend`
- [ ] Clone repo and install deps: `pip install -r requirements.txt`
- [ ] Create `.env` file with production secrets
- [ ] Set `ALLOWED_ORIGINS=https://yourdomain.com` (never `*`)
- [ ] Set `ADMIN_USER_IDS=<uuid1>,<uuid2>` to enable admin routes
- [ ] Apply database migration in Supabase
- [ ] Verify Supabase buckets and RLS policies are configured
- [ ] Verify Audiveris API endpoint is accessible
- [ ] Copy Supervisor config: `sudo cp supervisor.conf /etc/supervisor/conf.d/backend.conf`
- [ ] Update `directory=` path in config to `/home/ubuntu/Re-Hers/backend`
- [ ] Update `.venv` paths to match server structure
- [ ] Reload Supervisor: `sudo supervisorctl reread && sudo supervisorctl update`
- [ ] Start all processes: `sudo supervisorctl start all`
- [ ] Check status: `sudo supervisorctl status` (all should be RUNNING)
- [ ] Test from a client: upload PDF via API
- [ ] Verify job was queued: `rq info --url redis://localhost:6379`
- [ ] Wait for processing and verify outputs in Supabase Storage
- [ ] Check worker logs: `tail -f logs/worker1.err.log`
- [ ] Set up log rotation: configure Supervisor or use `logrotate`
- [ ] Test crash recovery: kill a worker process and verify Supervisor restarts it
- [ ] Set up monitoring: `rq-dashboard` or custom monitoring dashboard

## Monitoring & Troubleshooting

### Check Queue Status

```bash
# View queue depth and worker information
.venv/bin/rq info --url redis://localhost:6379

# Expected output:
# 1 queue, 4 workers
# queue: sheet_jobs (0 jobs)
# workers: 4 (all idle)
```

### View Process Status

```bash
# Check all Supervisor processes
supervisorctl status

# Expected output:
# fastapi                          RUNNING   pid 12345, uptime 0:05:30
# worker1                          RUNNING   pid 12346, uptime 0:05:30
# worker2                          RUNNING   pid 12347, uptime 0:05:30
# worker3                          RUNNING   pid 12348, uptime 0:05:30
# worker4                          RUNNING   pid 12349, uptime 0:05:30
```

### View Logs

```bash
# FastAPI logs
tail -f logs/fastapi.err.log

# Worker logs
tail -f logs/worker1.out.log
tail -f logs/worker1.err.log

# All logs at once
tail -f logs/*.log
```

### Common Issues & Fixes

#### Issue: "Redis is not available — cannot start server"
```bash
# Check if Redis is running
redis-cli ping  # Should respond with PONG

# If not running, start it
brew services start redis  # macOS
sudo systemctl start redis-server  # Linux
```

#### Issue: Workers are FATAL "can't find command 'python'"
```bash
# The supervisor.conf is using the wrong path
# Edit the config and use the full .venv path:
# command=/Users/user30/Documents/Re-Hers/backend/.venv/bin/python worker.py

# Then reload:
supervisorctl reread && supervisorctl update
supervisorctl restart all
```

#### Issue: Worker crashed but log shows normal exit
```bash
# Worker may have crashed due to uncaught exception
# Check the error log:
cat logs/worker1.err.log

# Manually restart:
supervisorctl restart worker1

# If it keeps crashing, check the error message in logs
```

#### Issue: Job stuck in "processing" status
```bash
# Check if worker is actually processing it
ps aux | grep worker

# If worker process is gone, Supervisor should auto-restart it
supervisorctl status worker1

# If still stuck after 15 minutes, the next job processed will
# detect it and mark it failed automatically
```

#### Issue: Slow job processing
```bash
# Check if multiple jobs are in the queue
.venv/bin/rq info --url redis://localhost:6379

# If queue is large, add more workers:
# 1. Add new [program:worker5] block to supervisor.conf
# 2. Run: supervisorctl reread && supervisorctl update
# 3. Run: supervisorctl start worker5
```

### Monitoring Tools

#### RQ Dashboard (Optional)

```bash
# Run in a separate terminal to view queue in browser
.venv/bin/rq-dashboard --redis-url redis://localhost:6379

# Open browser to http://localhost:9181
```

#### System Metrics

```bash
# Monitor CPU/Memory usage of workers
watch -n 1 'ps aux | grep -E "python|uvicorn"'

# Check Redis memory usage
redis-cli info memory
```

### Performance Tips

1. **Audit Audiveris timeout**: If jobs consistently timeout, increase `AUDIVERIS_REQUEST_TIMEOUT` in `.env`
2. **Monitor Supabase quota**: Large file uploads consume bandwidth
3. **Batch uploads**: Many small jobs faster than few large jobs
4. **Worker scaling**: Add more workers if queue grows beyond 10 pending jobs
5. **Log rotation**: Set up `logrotate` to prevent log files from growing unbounded

### Current Architecture (RQ + Supervisor)
- ✅ Parallel workers (4+ simultaneous jobs)
- ✅ Job persistence (Redis)
- ✅ Automatic crash recovery (Supervisor)
- ✅ Production-ready architecture
- ⚠️ Labeling runs sequentially after Audiveris (could be parallelized)
- ⚠️ Label_notes relies on JSON geometry accuracy (fails gracefully if corrupted)

### Completed Optimizations
- [x] Labeled PDF full public URL fix (was using wrong bucket prefix)
- [x] Eliminate JSON storage round-trip — normalize JSON in-process from memory
- [x] Fix `logging.basicConfig` no-op in worker processes (explicitly attaches FileHandler)
- [x] Remove duplicate client initialization block in dispatcher
- [x] Throttle stuck-job recovery scan (every 10 jobs, not every job)
- [x] `requests.Session` in `audiveris_client.py` for TCP connection reuse
- [x] Compact JSON storage (`json.dumps()` without `indent=2`, ~25% smaller)
- [x] Fix `FileResponse(content=bytes)` → `Response(content=bytes, media_type=…)`
- [x] Redis-backed user-scoped rate limiting on all 9 endpoints
- [x] CORS wildcard replaced with `ALLOWED_ORIGINS` env-var allowlist
- [x] `require_admin` dependency + `ADMIN_USER_IDS` env var for `/admin/*` routes
- [x] Queue overflow guard — HTTP 503 when queue at capacity
- [x] Per-user concurrent job cap — HTTP 429 when user has ≥ 5 active jobs
- [x] RQ `result_ttl=3600`, `failure_ttl=86400` for reliable job introspection

### Future Optimizations
- [ ] Switch `DatabaseClient` to async Supabase client (stop blocking the uvicorn event loop)
- [ ] Add `select("id,status,result_url,…")` on hot-path `/jobs/{job_id}` instead of `select("*")`
- [ ] Parallel execution of `normalize_pdf_ctm` and `normalize_json_for_pdf` via `asyncio.gather`
- [ ] Run Audiveris and labeling in parallel threads within workers
- [ ] Cache labeling results for identical PDFs
- [ ] Add configurable label font size and color
- [ ] Support alternative label formats (solfège, note names)
- [ ] Add batch processing for multiple PDFs
- [ ] Implement distributed Redis instances for HA setup
- [ ] Add webhook notifications for job completion
- [ ] Web UI for monitoring job queue status
- [ ] Auto-scaling workers based on queue depth
