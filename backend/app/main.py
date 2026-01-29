"""FastAPI application with endpoints for PDF conversion with user isolation."""
import os
import uuid
import logging
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from app.models import job_store, JobStatus
from app.queue import job_queue
from app.dispatcher import start_dispatcher
from app.auth import get_current_user
from app.database import DatabaseClient
from app.storage import StorageManager
from app.orphan_detector import OrphanDetector
from app.config import SUPABASE_URL, SUPABASE_KEY

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Audiveris PDF Conversion API with User Isolation")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize managers
db_client = DatabaseClient(SUPABASE_URL, SUPABASE_KEY)
storage_manager = StorageManager(SUPABASE_URL, SUPABASE_KEY, db_client)
orphan_detector = OrphanDetector(db_client, storage_manager)

# Ensure jobs directory exists
JOBS_DIR = "jobs"
os.makedirs(JOBS_DIR, exist_ok=True)


@app.on_event("startup")
async def startup_event():
    """Start the dispatcher on application startup."""
    logger.info("Starting application...")
    start_dispatcher()
    logger.info("Application started")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.post("/convert")
async def convert_pdf(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user)
):
    """Accept PDF upload and create a conversion job linked to user.
    
    Args:
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
        
        # Generate unique job ID
        job_id = str(uuid.uuid4())
        
        # Read file content
        file_content = await file.read()
        
        # Validate file size (max 100MB)
        MAX_FILE_SIZE = 100 * 1024 * 1024
        if len(file_content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File too large. Maximum size: {MAX_FILE_SIZE / 1024 / 1024}MB"
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
        
        # Enqueue for processing
        job_queue.enqueue(job_id)
        
        logger.info(f"Created job {job_id} for user {user_id}")
        
        return {
            "job_id": job_id,
            "status": "queued",
            "user_id": user_id
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Upload failed for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Upload failed")


@app.get("/jobs/{job_id}")
async def get_job_status(
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Get job status with user validation.
    
    Args:
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
            response["result_url"] = job["result_url"]
        
        if job.get("error_message"):
            response["error"] = job["error_message"]
        
        return response
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching job {job_id} for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error fetching job status")


@app.get("/sheets/{job_id}")
async def get_sheet_json(
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Download JSON sheet with user validation.
    
    Args:
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
async def list_user_jobs(
    user: dict = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """List all jobs for authenticated user.
    
    Args:
        user: Authenticated user (from JWT token)
        limit: Number of results
        offset: Pagination offset
    
    Returns:
        List of jobs
    """
    user_id = user["id"]
    
    try:
        jobs = await db_client.get_user_jobs(user_id, limit, offset)
        return {
            "jobs": jobs,
            "total": len(jobs),
            "user_id": user_id
        }
    except Exception as e:
        logger.error(f"Error listing jobs for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Error listing jobs")


@app.delete("/sheets/{job_id}")
async def delete_sheet(
    job_id: str,
    user: dict = Depends(get_current_user)
):
    """Delete sheet and associated files with user validation.
    
    Args:
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


# Admin endpoints (should be protected separately in production)
@app.get("/admin/orphans/detect")
async def detect_orphans(user: dict = Depends(get_current_user)):
    """Detect orphaned files (admin only).
    
    Note: In production, add proper admin role verification
    """
    try:
        report = await orphan_detector.detect_orphans()
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/admin/orphans/cleanup")
async def cleanup_orphans(
    dry_run: bool = True,
    user: dict = Depends(get_current_user)
):
    """Clean up orphaned files (admin only).
    
    Args:
        dry_run: If true, only report without deleting
    
    Note: In production, add proper admin role verification
    """
    try:
        result = await orphan_detector.cleanup_orphans(dry_run)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

