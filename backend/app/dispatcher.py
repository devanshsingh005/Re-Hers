"""Background dispatcher for processing jobs from the queue."""
import time
import threading
import logging
import asyncio
import tempfile
import os
import json
from uuid import uuid4
from app.queue import job_queue
from app.models import job_store, JobStatus
from app.audiveris_client import run_audiveris
from app.database import DatabaseClient
from app.storage import StorageManager
from app.config import SUPABASE_URL, SUPABASE_KEY

logger = logging.getLogger(__name__)

# Initialize database and storage clients for dispatcher
db_client = DatabaseClient(SUPABASE_URL, SUPABASE_KEY)
storage_manager = StorageManager(SUPABASE_URL, SUPABASE_KEY, db_client)

# Lock to ensure only one job runs at a time
_execution_lock = threading.Lock()


async def process_job(job_id: str) -> None:
    """Process a single job from database.
    
    Args:
        job_id: The job ID to process.
    """
    try:
        # Fetch job from database
        jobs_response = db_client.client.table("jobs").select("*").eq("id", job_id).execute()
        
        if not jobs_response.data or len(jobs_response.data) == 0:
            logger.error(f"Job {job_id} not found in database")
            return
        
        job = jobs_response.data[0]
        user_id = job['user_id']
        pdf_path = job['pdf_path']
        
        # Mark job as processing in database
        await db_client.update_job_status(job_id, user_id, "processing")
        logger.info(f"Processing job {job_id} for user {user_id}")
        
        # Download PDF from Supabase Storage
        logger.info(f"Downloading PDF from {pdf_path}")
        pdf_content = storage_manager.client.storage.from_("pdf_uploads").download(pdf_path)
        
        # Write to temporary file for Audiveris
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp.write(pdf_content)
            tmp_path = tmp.name
        
        try:
            # Call Audiveris API
            logger.info(f"Calling Audiveris API for job {job_id}")
            json_output = run_audiveris(tmp_path)
            
            # Convert to bytes if needed
            if isinstance(json_output, dict):
                json_bytes = json.dumps(json_output).encode('utf-8')
            elif isinstance(json_output, str):
                json_bytes = json_output.encode('utf-8')
            else:
                json_bytes = json_output
            
            # Store output JSON in Supabase Storage
            output_path = f"{user_id}/{job_id}/output.json"
            logger.info(f"Uploading output to {output_path}")
            storage_manager.client.storage.from_("sheet_data").upload(output_path, json_bytes)
            
            # Create sheet_file record in database
            file_id = str(uuid4())
            await db_client.create_sheet_file(
                file_id=file_id,
                user_id=user_id,
                job_id=job_id,
                storage_path=output_path,
                file_size_bytes=len(json_bytes),
                status="completed"
            )
            
            # Mark job as completed in database
            result_url = f"sheet_data/{output_path}"
            await db_client.update_job_status(
                job_id,
                user_id,
                "completed",
                result_url=result_url
            )
            logger.info(f"Job {job_id} completed successfully. Output: {result_url}")
            
        finally:
            # Cleanup temporary file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
        
    except Exception as e:
        # Mark job as failed in database
        error_message = str(e)
        try:
            jobs_response = db_client.client.table("jobs").select("*").eq("id", job_id).execute()
            if jobs_response.data:
                user_id = jobs_response.data[0]['user_id']
                await db_client.update_job_status(
                    job_id,
                    user_id,
                    "failed",
                    error_message=error_message
                )
        except Exception as db_error:
            logger.error(f"Failed to update job status: {db_error}")
        
        logger.error(f"Job {job_id} failed: {error_message}", exc_info=True)


def dispatcher_loop() -> None:
    """Main dispatcher loop that processes jobs from the queue.
    
    This function runs in an infinite loop, processing one job at a time.
    Only one job can run at a time due to the execution lock.
    """
    logger.info("Dispatcher started")
    
    while True:
        # Dequeue a job (with timeout to allow periodic checks)
        job_id = job_queue.dequeue(timeout=1.0)
        
        if job_id:
            # Acquire lock to ensure only one job runs at a time
            with _execution_lock:
                logger.info(f"Dequeued job: {job_id}")
                # Run async process_job synchronously
                asyncio.run(process_job(job_id))
        else:
            # No job available, sleep briefly before checking again
            time.sleep(0.1)


def start_dispatcher() -> threading.Thread:
    """Start the dispatcher in a background thread.
    
    Returns:
        The thread running the dispatcher.
    """
    thread = threading.Thread(target=dispatcher_loop, daemon=True)
    thread.start()
    logger.info("Dispatcher thread started")
    return thread
