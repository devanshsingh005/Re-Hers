# Audiveris PDF Conversion Backend with User Isolation & Note Labels

A FastAPI backend service with **user isolation and data security** that accepts PDF uploads, queues them for processing, uses Audiveris HTTP API to convert PDFs to JSON, and overlays note pitch labels on annotated PDFs. All outputs are stored in Supabase Storage with full user authentication and Row-Level Security (RLS).

## ✨ Key Features

- **User Isolation**: Every file is linked to the authenticated user who uploaded it
- **Data Security**: Row-Level Security (RLS) prevents users from accessing other users' data
- **JWT Authentication**: Secure endpoints with Supabase Auth
- **Note Label Overlay**: Automatic pitch label generation (e.g., "A4", "E5") on sheet music PDFs
- **Dual Output Format**: JSON (Audiveris output) + Labeled PDF (annotated with note names)
- **Orphan Detection**: Built-in tools to detect and clean up orphaned files
- **Horizontal Scalable**: Redis-ready queue and PostgreSQL backend
- **File Validation**: MIME type and size validation
- **Audit Logging**: Track all file operations
- **Graceful Error Handling**: Labeling failures don't prevent JSON access

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
        ┌────────▼────────┐
        │   Redis Queue   │
        │  (Shared Jobs)  │
        └────────┬────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│Worker-1  │ │Worker-2  │ │Worker-3  │
│(Dispatcher│ │(Dispatcher│ │(Dispatcher
│ Process) │ │ Process) │ │ Process) │
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

## Dispatcher Behavior

The dispatcher runs in a **background thread** and implements the following pipeline:

- **Infinite Loop**: Continuously checks for jobs in queue
- **Single Execution**: Only one job runs at a time (enforced by lock)
- **Non-blocking**: API requests return immediately, processing happens asynchronously
- **Graceful Degradation**: Labeling failures don't prevent JSON access
- **Comprehensive Cleanup**: Temporary files cleaned up regardless of success/failure
- **Error Tracking**: Separate tracking for Audiveris and labeling errors

### Dispatcher Flow

```
while True:
    acquire execution lock
    dequeue job (with timeout)
    if job exists:
        mark job as "processing"
        download input PDF
        call Audiveris API → output JSON
        save JSON to storage
        run label_notes pipeline
        save labeled PDF (if successful)
        mark job as "completed" or "completed_with_warning"
        update label_status
    release lock
    cleanup temporary files
    sleep briefly
```

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

## How Audiveris API is Integrated

The backend treats Audiveris as a **black-box HTTP service**:

- **Endpoint**: `POST {AUDIVERIS_API_URL}?format=json`
- **Method**: HTTP POST with multipart/form-data
- **Input**: PDF file uploaded as form field `file`
- **Output**: MusicXML JSON response with note geometry and pitch data
- **Error Handling**: Raises exception if status code is not 200

The backend **never** runs Audiveris CLI directly - it only makes HTTP requests.

## Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file in the `backend/` directory (copy from `.env.example`):

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
```

### 3. Create Supabase Storage Buckets

In your Supabase dashboard, create two buckets:

- **pdf_uploads**: For storing input PDFs and labeled PDFs
- **sheet_data**: For storing Audiveris JSON outputs

### 4. Apply Database Migration

Run the migration in your Supabase SQL editor:

```sql
-- Copy and run migrations/001_user_isolation.sql in Supabase
```

This creates:
- `jobs` table with `label_status` and `label_warning` columns
- `sheet_files` table for tracking stored files
- RLS policies for user isolation

### 5. Set Storage RLS Policies

In Supabase Dashboard → Storage → Edit policies for each bucket:

**pdf_uploads** and **sheet_data** policies:
```
Auth users can only access files in their user_id folder:
(bucket_id = 'pdf_uploads'::text) AND (auth.uid()::text = (storage.foldername[1])::text)
```

### 4. Run the Backend

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or use Python directly:

```bash
cd backend
python -m uvicorn app.main:app --reload
```

The dispatcher thread starts automatically on startup and begins processing queued jobs.

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
│   ├── auth.py                  # JWT authentication & user verification
│   ├── database.py              # PostgreSQL operations with RLS
│   ├── storage.py               # Supabase Storage operations
│   ├── queue.py                 # FIFO job queue
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

## Constraints & Design Decisions

- ✅ **Non-blocking**: API requests return immediately after upload
- ✅ **Single Worker**: Only one Audiveris job runs at a time (enforced by lock)
- ✅ **HTTP-only**: Backend never runs Audiveris CLI directly
- ✅ **Queue-based**: Jobs processed in FIFO order
- ✅ **Deterministic Labeling**: Same PDF+JSON always produces identical labeled PDF
- ✅ **User Isolation**: RLS enforced on all database and storage operations
- ✅ **Graceful Degradation**: Labeling failures don't prevent JSON access
- ❌ **No Parallel Labeling**: Labeling runs sequentially after Audiveris (future optimization opportunity)
- ℹ️ **Redis Optional**: In-memory queue used by default; Redis ready for horizontal scaling

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

- [ ] Install dependencies: `pip install -r requirements.txt`
- [ ] Create `.env` file with Supabase and Audiveris credentials
- [ ] Apply database migration in Supabase
- [ ] Create `pdf_uploads` and `sheet_data` buckets
- [ ] Set bucket RLS policies for user isolation
- [ ] Verify Audiveris API is running and accessible
- [ ] Start backend: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
- [ ] Test health endpoint: `curl http://localhost:8000/health`
- [ ] Test full pipeline with sample PDF
- [ ] Verify labeled PDF output contains note labels
- [ ] Check logs for any warnings during processing

## Known Limitations & Future Improvements

### Current Limitations
- Labeling runs sequentially after Audiveris (could be parallelized)
- Label_notes relies on JSON geometry accuracy (fails gracefully if corrupted)
- No caching of labeling results
- Labeling performance depends on score complexity

### Future Optimizations
- [ ] Run Audiveris and labeling in parallel threads
- [ ] Cache labeling results for identical PDFs
- [ ] Add configurable label font size and color
- [ ] Support alternative label formats (solfège, note names)
- [ ] Add batch processing for multiple PDFs
- [ ] Implement Redis queue for true horizontal scaling
- [ ] Add webhook notifications for job completion
