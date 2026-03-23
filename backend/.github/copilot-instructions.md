# Re-Hers Backend: AI Agent Instructions

## Architecture Overview

**FastAPI server** + **Redis Queue (RQ) workers** + **Supabase** (PostgreSQL + Storage + Auth)

- **API Layer**: [app/main.py](../app/main.py) exposes `/convert`, `/jobs`, `/sheets`, `/admin/orphans/*` endpoints
- **Job Queue**: Redis-backed RQ named `sheet_jobs` (15-min timeout per job), workers spawned via [supervisor.conf](../supervisor.conf)
- **User Isolation**: Supabase Row-Level Security (RLS) policies enforce data separation; all endpoints require JWT token
- **Processing Pipeline**: 
  1. User uploads PDF → stored in `pdf_uploads` bucket under `{user_id}/{job_id}/`
  2. API enqueues job to Redis queue
  3. 4 Worker processes (supervisor-managed) execute [app/dispatcher.py](../app/dispatcher.py)
  4. Worker calls Audiveris OCR API, then labels notes with pitch (A4, E5, etc.) via [app/label_notes.py](../app/label_notes.py)
  5. Outputs stored: JSON + labeled PDF in `sheet_data` bucket

## Critical Dev Workflows

### Start/Stop Services
```bash
# macOS: Uses Supervisor to manage FastAPI + 4 workers + Redis
brew services start redis
supervisorctl start all  # starts fastapi, worker1-4
supervisorctl stop all

# Verify health
curl http://localhost:8000/health
supervisorctl status
.venv/bin/rq info  # shows worker queue depth
```

### Database Migrations
- Schema lives in [migrations/001_user_isolation.sql](../migrations/001_user_isolation.sql)
- RLS policies are **critical**: `auth.uid()` checks prevent cross-user data leaks
- Always include `auth_uid_eq()` checks in WHERE clauses for user-scoped queries

### Adding New Endpoints
- Protected routes: use `async def endpoint(request: Request, ..., user: dict = Depends(get_current_user))`
- Admin routes: use `Depends(require_admin)` — gated by `ADMIN_USER_IDS` env var (see [app/auth.py](../app/auth.py))
- **Every rate-limited endpoint must have `request: Request` as first parameter** (slowapi requirement)
- Apply `@limiter.limit(RATE_LIMIT_API)` decorator **below** `@app.route()` and above the function
- Pass `user["id"]` to database and storage calls for RLS enforcement

### Debugging Workers
- Worker logs: `/logs/worker1.out.log`, `/logs/worker1.err.log`, `/logs/dispatcher.log`
- Failed jobs stay in Redis; check with `rq failed -u redis://localhost:6379` → requeue or clear
- If a worker crashes, Supervisor restarts it (check logs for reason)

## Code Patterns & Conventions

### Security: Rate Limiting
All endpoints are rate-limited via [app/limiter.py](../app/limiter.py) (slowapi + Redis, moving-window strategy):
- Keys are **user-scoped** (JWT `sub` claim) when a Bearer token is present, **IP-based** otherwise
- Limits: upload `10/min`, API `100/min`, health `60/min`, admin `20/min` — all configurable via env vars
- `@limiter.limit(RATE_LIMIT_UPLOAD)` must appear **after** `@app.route()` and **before** the function
- The endpoint function **must** include `request: Request` as its first parameter

### Security: CORS
`allow_origins=["*"]` was replaced with an explicit allowlist from `ALLOWED_ORIGINS` env var (see [app/config.py](../app/config.py)). Wildcard + `allow_credentials=True` is invalid per the CORS spec and exposes the API to cross-origin attacks. Default origins cover localhost dev ports; production deployments must set `ALLOWED_ORIGINS` explicitly.

### Security: Admin Authorization
`/admin/*` endpoints use `Depends(require_admin)` ([app/auth.py](../app/auth.py)). Admin access is configured via `ADMIN_USER_IDS` env var (comma-separated Supabase UUIDs). An empty `ADMIN_USER_IDS` blocks all admin access by default (fail-secure).

### Security: Queue & Upload Protection
- **`QueueFullError`** in [app/queue.py](../app/queue.py): raised when queue depth ≥ `MAX_QUEUE_DEPTH` (default 200); `/convert` catches it and returns HTTP 503
- **Per-user concurrent job cap**: `/convert` calls `db_client.get_user_active_job_count(user_id)` before any storage I/O; returns HTTP 429 if user has ≥ `MAX_CONCURRENT_JOBS_PER_USER` (default 5) active jobs

### User-Scoped Database Queries
Use `DatabaseClient` methods — they append `eq("user_id", user_id)` automatically:
```python
# app/database.py pattern:
async def get_job(self, job_id: str, user_id: str):
    response = self.client.table("jobs").select("*").eq("id", job_id).eq("user_id", user_id).execute()
    return response.data[0] if response.data else None
```

### File Paths in Storage
All paths use pattern `{user_id}/{job_id}/filename` — RLS policies check `auth.uid()`:
```python
# app/storage.py:
file_path = f"{user_id}/{job_id}/{filename}"
storage_manager.upload(file_path, buffer)
```

### Job Status Lifecycle
`pending` → `queued` → `processing` → `completed` / `failed` / `completed_with_warning`

**Special case**: iOS frontend may write `status='completed'` before worker runs. Dispatcher checks `label_status=None` to detect and reprocess (see [app/queue.py](../app/queue.py#L22)).

### PDF Label Offset Issue
[app/dispatcher.py](../app/dispatcher.py#L45) includes `normalize_pdf_ctm()` helper:
- Some PDFs (MuseScore/Audiveris exports) set page-level CTM (~0.06 scale)
- PyMuPDF text insertion inherits CTM, placing labels at 0.06x intended position
- Wrapper wraps content in q/Q graphics-state pairs to isolate CTM (see comments for rationale)

### Audiveris Integration
- Calls HTTP API at `AUDIVERIS_API_URL` (see [app/config.py](../app/config.py))
- [app/audiveris_client.py](../app/audiveris_client.py) handles PDF → JSON conversion
- Timeout: `REQUEST_TIMEOUT` env var (default 300s)

### Orphan Detection
[app/orphan_detector.py](../app/orphan_detector.py) runs on-demand admin routes:
- Finds files in Storage without DB entries
- Finds DB entries without files in Storage
- `/admin/orphans/detect` returns list; `/admin/orphans/cleanup` deletes them

## Environment Variables
See [.env.example](./.env.example):
- `SUPABASE_URL`, `SUPABASE_KEY`: Auth + DB + Storage
- `AUDIVERIS_API_URL`: OMR service endpoint
- `REDIS_URL`: Queue broker (default `redis://localhost:6379`)
- `REQUEST_TIMEOUT`, `MAX_FILE_SIZE`: Limits

## Key Files Reference
| File | Purpose |
|------|---------|
| [app/main.py](../app/main.py) | FastAPI routes + job submission |
| [app/dispatcher.py](../app/dispatcher.py) | Worker job processor (PDF → JSON → labeled PDF) |
| [app/auth.py](../app/auth.py) | JWT token verification + user extraction |
| [app/database.py](../app/database.py) | Supabase ORM (user-scoped queries) |
| [app/storage.py](../app/storage.py) | File upload/download (user-isolated paths) |
| [app/queue.py](../app/queue.py) | Redis enqueue logic + duplicate guard |
| [app/label_notes.py](../app/label_notes.py) | Pitch labeling engine (OCR JSON → PDF annotations) |
| [worker.py](../worker.py) | Worker entrypoint (spawned by Supervisor) |
| [supervisor.conf](../supervisor.conf) | Process management config (4 workers + API) |
