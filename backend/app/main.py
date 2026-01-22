"""FastAPI application with endpoints for PDF conversion."""
import os
import uuid
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from app.models import job_store, JobStatus
from app.queue import job_queue
from app.dispatcher import start_dispatcher
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Audiveris PDF Conversion API")

# Ensure jobs directory exists
JOBS_DIR = "jobs"
os.makedirs(JOBS_DIR, exist_ok=True)


@app.on_event("startup")
async def startup_event():
    """Start the dispatcher on application startup."""
    logger.info("Starting application...")
    start_dispatcher()
    logger.info("Application started")


@app.post("/convert")
async def convert_pdf(file: UploadFile = File(...)):
    """Accept PDF upload and create a conversion job.
    
    Returns:
        JSON with job_id and status.
    """
    # Generate unique job ID
    job_id = str(uuid.uuid4())
    
    # Create job directory
    job_dir = os.path.join(JOBS_DIR, job_id)
    os.makedirs(job_dir, exist_ok=True)
    
    # Save uploaded file
    input_pdf_path = os.path.join(job_dir, "input.pdf")
    with open(input_pdf_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    # Create job record
    job = job_store.create_job(job_id, input_pdf_path)
    
    # Enqueue job
    job_queue.enqueue(job_id)
    
    logger.info(f"Created job {job_id} and enqueued for processing")
    
    return JSONResponse({
        "job_id": job_id,
        "status": job.status.value
    })


@app.get("/status/{job_id}")
async def get_status(job_id: str):
    """Get the status of a job.
    
    Args:
        job_id: The job ID to query.
    
    Returns:
        Job metadata including status, output_url, and error (if any).
    """
    job = job_store.get_job(job_id)
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    response = {
        "job_id": job.job_id,
        "status": job.status.value,
        "input_pdf_path": job.input_pdf_path,
    }
    
    if job.output_url:
        response["output_url"] = job.output_url
    
    if job.error:
        response["error"] = job.error
    
    return JSONResponse(response)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return JSONResponse({"status": "healthy"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
