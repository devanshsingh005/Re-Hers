"""FastAPI application with endpoints for PDF conversion with user isolation."""
import os
import uuid
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse, FileResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from rq import Queue
from rq.registry import StartedJobRegistry
from app.limiter import limiter
from app.queue import enqueue_job, redis_conn, QueueFullError
from app.auth import get_current_user, require_admin
from app.database import DatabaseClient
from app.storage import StorageManager
from app.orphan_detector import OrphanDetector
from app.config import (
    SUPABASE_URL, SUPABASE_KEY, ALLOWED_ORIGINS,
    RATE_LIMIT_UPLOAD, RATE_LIMIT_API, RATE_LIMIT_HEALTH, RATE_LIMIT_ADMIN,
    MAX_CONCURRENT_JOBS_PER_USER, MAX_FILE_SIZE,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Verify Redis before serving traffic, then start the recovery task."""
    logger.info("Starting application...")
    try:
        redis_conn.ping()
        logger.info("Redis connection verified")
    except Exception as exc:
        raise RuntimeError(
            f"Redis is not available — cannot start server. "
            f"Ensure Redis is running. Detail: {exc}"
        ) from exc
    asyncio.create_task(recovery_loop())
    logger.info("Application started")
    yield


app = FastAPI(title="Audiveris PDF Conversion API with User Isolation", lifespan=lifespan)

# CORS — explicit trusted origins only.
# "*" is invalid with allow_credentials=True (browsers reject it) and
# exposes the API to CSRF-style cross-origin abuse from any website.
# Set ALLOWED_ORIGINS in .env as a comma-separated list per environment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    max_age=600,  # cache preflight responses for 10 minutes
)

# Rate limiting — Redis-backed, user-scoped with IP fallback.
# Limits are configurable per endpoint via RATE_LIMIT_* env vars.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Initialize managers
db_client = DatabaseClient(SUPABASE_URL, SUPABASE_KEY)
storage_manager = StorageManager(SUPABASE_URL, SUPABASE_KEY, db_client)
orphan_detector = OrphanDetector(db_client, storage_manager)

# Ensure jobs directory exists
JOBS_DIR = "jobs"
os.makedirs(JOBS_DIR, exist_ok=True)


def _authenticated_result_route(job_id: str) -> str:
    return f"/sheets/{job_id}"


def _authenticated_pdf_route(job_id: str) -> str:
    return f"/sheets/{job_id}/pdf"


def _generic_processing_error() -> str:
    return "Processing failed. Please try again or contact support."


def _generic_processing_warning() -> str:
    return "Processing completed with warnings."


def _sanitize_job_summary(job: dict) -> dict:
    job_id = job["id"]
    summary = {
        "id": job_id,
        "status": job["status"],
        "created_at": job["created_at"],
    }
    if job["status"] in {"completed", "completed_with_warning"}:
        summary["result_url"] = _authenticated_result_route(job_id)
    if job.get("label_status") == "success":
        summary["pdf_url"] = _authenticated_pdf_route(job_id)
    if job.get("error_message"):
        summary["error"] = _generic_processing_error()
    if job.get("label_warning"):
        summary["warning"] = _generic_processing_warning()
    return summary


def _validate_upload_bytes(file_content: bytes, content_type: str) -> None:
    if not file_content:
        raise HTTPException(status_code=422, detail="Uploaded file is empty")

    if content_type == "application/pdf":
        if not file_content.startswith(b"%PDF"):
            raise HTTPException(status_code=422, detail="File content does not match declared type")
        if len(file_content) < 32 or b"%%EOF" not in file_content[-1024:]:
            raise HTTPException(status_code=422, detail="Uploaded PDF is truncated or invalid")
        return

    if content_type in {"image/jpeg", "image/jpg"}:
        if not file_content.startswith(b"\xff\xd8\xff") or not file_content.endswith(b"\xff\xd9"):
            raise HTTPException(status_code=422, detail="File content does not match declared type")
        if len(file_content) < 16:
            raise HTTPException(status_code=422, detail="Uploaded JPEG is truncated or invalid")
        return

async def recover_stuck_jobs() -> None:
    """Requeue any job that is 'processing' in the DB but absent from RQ StartedJobRegistry.

    A job is considered validly processing only when:
        job.status == 'processing'  AND  job_id in StartedJobRegistry

    If the worker crashed, its entry in StartedJobRegistry expires (worker_ttl=420s).
    The next recovery cycle detects the gap and resets the job to 'pending' then requeues it.

    Safety:
        * Never requeues a job that is still actively running.
        * Skips jobs already in a terminal state.
        * Uses enqueue_job() which guards against double-enqueue via status check.
    """
    try:
        registry = StartedJobRegistry("sheet_jobs", connection=redis_conn)
        active_rq_ids = set(registry.get_job_ids())

        resp = (
            db_client.client.table("jobs")
            .select("id, user_id")
            .eq("status", "processing")
            .execute()
        )

        for job in (resp.data or []):
            job_id = job["id"]
            if job_id not in active_rq_ids:
                logger.warning(
                    f"[recovery] Stuck job detected: {job_id} — "
                    f"status=processing but not in StartedJobRegistry. Requeueing."
                )
                await db_client.update_job_status(job_id, job["user_id"], "pending")
                enqueue_job({"job_id": job_id})
                logger.info(f"[recovery] Requeued job {job_id}")

    except Exception as e:
        logger.error(f"[recovery] Error during stuck job recovery: {e}")


async def recovery_loop() -> None:
    """Background task: check for stuck jobs every 120 seconds."""
    while True:
        await recover_stuck_jobs()
        await asyncio.sleep(120)


@app.get("/health")
@limiter.limit(RATE_LIMIT_HEALTH)
async def health_check(request: Request):
    """Health check endpoint."""
    return {"status": "healthy"}


@app.post("/convert")
@limiter.limit(RATE_LIMIT_UPLOAD)
async def convert_pdf(
    request: Request,
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user)
):
    """Accept PDF upload and create a conversion job linked to user.
    
    Args:
        request: FastAPI request (required for rate limiter)
        file: PDF file to convert
        user: Authenticated user (from JWT token)
    
    Returns:
        JSON with job_id and status
    """
    user_id = user["id"]
    
    try:
        # Validate file type (PDF or JPEG)
        allowed_types = ["application/pdf", "image/jpeg", "image/jpg"]
        if file.content_type not in allowed_types:
            raise HTTPException(
                status_code=400,
                detail="File must be a PDF or JPEG image"
            )

        magic_bytes = await file.read(8)
        file_content = magic_bytes + await file.read()
        _validate_upload_bytes(file_content, file.content_type)

        # Generate unique job ID
        job_id = str(uuid.uuid4())
        
        # Validate file size (max 100MB)
        if len(file_content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File too large. Maximum size: {MAX_FILE_SIZE / 1024 / 1024}MB"
            )
        
        # Per-user concurrent job cap — prevents one account from monopolising
        # all workers. Checked before any storage I/O so we fail fast.
        active_jobs = await db_client.get_user_active_job_count(user_id)
        if active_jobs >= MAX_CONCURRENT_JOBS_PER_USER:
            raise HTTPException(
                status_code=429,
                detail=(
                    f"Too many jobs in progress ({active_jobs}/{MAX_CONCURRENT_JOBS_PER_USER}). "
                    "Wait for existing jobs to complete before submitting new ones."
                ),
            )
        
        # Upload file to Supabase Storage (user-scoped)
        file_path = await storage_manager.upload_pdf(user_id, job_id, file_content)
        
        # Create job in database linked to user
        job = await db_client.create_job(
            job_id=job_id,
            user_id=user_id,
            pdf_path=file_path,
            status="pending"
        )

        # CRITICAL: Force status to pending regardless of Supabase defaults
        # Supabase table has DEFAULT 'completed' trigger that overrides our insert
        logger.warning(f"[CONVERT] Job {job_id} initial status={job.get('status')}, forcing to pending")
        update_result = await db_client.update_job_status(job_id, user_id, "pending")
        logger.warning(f"[CONVERT] After force update, job status={update_result.get('status')}")

        # Enqueue for processing
        logger.warning(f"[CONVERT] Calling enqueue_job for {job_id}")
        try:
            enqueue_result = enqueue_job({"job_id": job_id})
        except QueueFullError as exc:
            # Queue is at capacity — mark the job failed so it doesn't linger
            # as 'pending' and mislead the frontend.
            try:
                await db_client.update_job_status(
                    job_id, user_id, "failed",
                    error_message="Rejected: queue at capacity at submission time",
                )
            except Exception as e:
                logger.error("Failed to update job status to failed: %s", type(e).__name__)
            raise HTTPException(status_code=503, detail=str(exc))
        logger.warning(f"[CONVERT] enqueue_job returned: {enqueue_result}")
        
        logger.info(f"Created job {job_id} for user {user_id}")
        
        return {
            "job_id": job_id,
            "status": "pending",
            "user_id": user_id
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Upload failed for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Upload failed")


@app.get("/jobs/{job_id}")
@limiter.limit(RATE_LIMIT_API)
async def get_job_status(
    request: Request,
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Get job status with user validation.
    
    Args:
        request: FastAPI request (required for rate limiter)
        job_id: Job ID
        user: Authenticated user (from JWT token)
    
    Returns:
        JSON with job status and result_url (if completed)
    """
    user_id = user["id"]
    
    try:
        # Query DB scoped by user_id (RLS enforced)
        job = await db_client.get_job(job_id, user_id)
        
        if not job:
            # Don't reveal if job exists for other users
            raise HTTPException(status_code=404, detail="Job not found")
        
        response = {
            "job_id": job_id,
            "status": job["status"],
            "user_id": user_id
        }
        
        if job.get("result_url"):
            response["result_url"] = _authenticated_result_route(job_id)
        if job.get("label_status") == "success":
            response["pdf_url"] = _authenticated_pdf_route(job_id)
        
        if job.get("error_message"):
            logger.error("Job %s failed; internal error recorded", job_id)
            response["error"] = _generic_processing_error()
        
        return response
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching job {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching job status")


@app.get("/sheets/{job_id}")
@limiter.limit(RATE_LIMIT_API)
async def get_sheet_json(
    request: Request,
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Download JSON sheet with user validation.
    
    Args:
        request: FastAPI request (required for rate limiter)
        job_id: Job ID
        user: Authenticated user (from JWT token)
    
    Returns:
        JSON sheet data
    """
    user_id = user["id"]
    
    try:
        result = await storage_manager.get_file_for_user(user_id, job_id)
        return result["data"]
    
    except PermissionError:
        raise HTTPException(status_code=403, detail="Unauthorized")
    except Exception as e:
        logger.error(f"Error fetching sheet {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=404, detail="Sheet not found")


@app.get("/jobs")
@limiter.limit(RATE_LIMIT_API)
async def list_user_jobs(
    request: Request,
    user: dict = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """List all jobs for authenticated user.
    
    Args:
        request: FastAPI request (required for rate limiter)
        user: Authenticated user (from JWT token)
        limit: Number of results
        offset: Pagination offset
    
    Returns:
        List of jobs
    """
    user_id = user["id"]
    
    try:
        jobs = await db_client.get_user_jobs(user_id, limit, offset)
        sanitized_jobs = [_sanitize_job_summary(job) for job in jobs]
        return {
            "jobs": sanitized_jobs,
            "total": len(sanitized_jobs),
            "user_id": user_id
        }
    except Exception as e:
        logger.error(f"Error listing jobs for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error listing jobs")


@app.delete("/sheets/{job_id}")
@limiter.limit(RATE_LIMIT_API)
async def delete_sheet(
    request: Request,
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Delete sheet and associated files with user validation.
    
    Args:
        request: FastAPI request (required for rate limiter)
        job_id: Job ID
        user: Authenticated user (from JWT token)
    
    Returns:
        Success message
    """
    user_id = user["id"]
    
    try:
        await storage_manager.delete_file_for_user(user_id, job_id)
        logger.info(f"Deleted sheet {job_id} for user {user_id}")
        return {"message": "Sheet deleted successfully"}
    
    except PermissionError:
        raise HTTPException(status_code=403, detail="Unauthorized")
    except Exception as e:
        logger.error(f"Error deleting sheet {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error deleting sheet")


# Admin endpoints — gated by require_admin (ADMIN_USER_IDS env var).
@app.get("/admin/orphans/detect")
@limiter.limit(RATE_LIMIT_ADMIN)
async def detect_orphans(
    request: Request,
    user: dict = Depends(require_admin),
):
    """Detect orphaned files (admin only — requires ADMIN_USER_IDS env var)."""
    try:
        report = await orphan_detector.detect_orphans()
        return report
    except Exception as e:
        logger.error("Admin endpoint error: %s", type(e).__name__, exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/admin/orphans/cleanup")
@limiter.limit(RATE_LIMIT_ADMIN)
async def cleanup_orphans(
    request: Request,
    dry_run: bool = True,
    user: dict = Depends(require_admin),
):
    """Clean up orphaned files (admin only — requires ADMIN_USER_IDS env var).
    
    Args:
        dry_run: If true, only report without deleting
    """
    try:
        result = await orphan_detector.cleanup_orphans(dry_run)
        return result
    except Exception as e:
        logger.error("Admin endpoint error: %s", type(e).__name__, exc_info=True)
        raise HTTPException(status_code=500, detail="Internal server error")


@app.get("/sheets/{job_id}/pdf")
@limiter.limit(RATE_LIMIT_API)
async def get_labeled_pdf(
    request: Request,
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Download labeled PDF with note labels overlaid.
    
    Args:
        request: FastAPI request (required for rate limiter)
        job_id: Job ID
        user: Authenticated user (from JWT token)
    
    Returns:
        PDF file bytes with Content-Type: application/pdf
    """
    user_id = user["id"]
    
    try:
        # Download labeled PDF (validates user ownership via RLS)
        pdf_content = await storage_manager.get_labeled_pdf_for_user(user_id, job_id)
        
        return Response(
            content=pdf_content,
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="labeled_{job_id}.pdf"'},
        )
    
    except PermissionError:
        raise HTTPException(status_code=403, detail="Unauthorized")
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Labeled PDF not found")
    except Exception as e:
        logger.error(f"Error fetching labeled PDF {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error downloading PDF")


@app.get("/sheets/{job_id}/status")
@limiter.limit(RATE_LIMIT_API)
async def get_job_status_details(
    request: Request,
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Get detailed job status including labeling status.
    
    Args:
        request: FastAPI request (required for rate limiter)
        job_id: Job ID
        user: Authenticated user (from JWT token)
    
    Returns:
        JSON with status, json_ready, pdf_ready, and any warnings
    """
    user_id = user["id"]
    
    try:
        # Query DB scoped by user_id (RLS enforced)
        job = await db_client.get_job(job_id, user_id)
        
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        response = {
            "job_id": job_id,
            "status": job["status"],
            "user_id": user_id,
            "json_ready": job["status"] in ["completed", "completed_with_warning"],
            "pdf_ready": job.get("label_status") == "success",
            "created_at": job["created_at"],
            "updated_at": job["updated_at"]
        }
        
        # Include error/warning messages if present
        if job.get("error_message"):
            response["error"] = _generic_processing_error()
        
        if job.get("label_warning"):
            response["warning"] = _generic_processing_warning()
        
        if job.get("label_status"):
            response["label_status"] = job["label_status"]
        
        return response
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching job status {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching job status")
