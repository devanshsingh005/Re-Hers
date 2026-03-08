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
from app.label_notes import process as run_label_notes
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
    
    Pipeline:
        1. Download input PDF from storage
        2. Call Audiveris API → get JSON
        3. Save JSON to storage
        4. Run label_notes → create labeled PDF
        5. Save labeled PDF to storage
        6. Update job status
    
    Args:
        job_id: The job ID to process.
    """
    tmp_pdf_path = None
    tmp_json_path = None
    tmp_labeled_pdf_path = None
    
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
        
        # =========================================================================
        # STEP 1: Download PDF from Supabase Storage
        # =========================================================================
        logger.info(f"Downloading PDF from {pdf_path}")
        pdf_content = storage_manager.client.storage.from_("pdf_uploads").download(pdf_path)
        
        # Write to temporary file for Audiveris
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp.write(pdf_content)
            tmp_pdf_path = tmp.name
        
        # =========================================================================
        # STEP 2: Call Audiveris API → get JSON
        # =========================================================================
        logger.info(f"Calling Audiveris API for job {job_id}")
        json_output = run_audiveris(tmp_pdf_path)
        
        # Convert to dict if needed
        if isinstance(json_output, str):
            json_output = json.loads(json_output)
        
        # =========================================================================
        # STEP 3: Save JSON to storage
        # =========================================================================
        output_json_path = f"{user_id}/{job_id}/output.json"
        json_str = json.dumps(json_output, indent=2)
        json_bytes = json_str.encode('utf-8')
        
        logger.info(f"Uploading JSON to {output_json_path}")
        storage_manager.client.storage.from_("sheet_data").upload(
            output_json_path, 
            json_bytes,
            file_options={"content-type": "application/json", "upsert": "true"}
        )
        
        # Create sheet_file record for JSON
        json_file_id = str(uuid4())
        await db_client.create_sheet_file(
            file_id=json_file_id,
            user_id=user_id,
            job_id=job_id,
            storage_path=output_json_path,
            file_size_bytes=len(json_bytes),
            status="completed"
        )
        
        # =========================================================================
        # STEP 4: Run label_notes → create labeled PDF
        # =========================================================================
        logger.info(f"Running label_notes for job {job_id}")
        
        # Download JSON from sheet_data bucket (source of truth)
        logger.info(f"Downloading JSON from sheet_data bucket: {output_json_path}")
        json_content = storage_manager.client.storage.from_("sheet_data").download(output_json_path)
        
        # Write downloaded JSON to temp file
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode='wb') as tmp:
            tmp.write(json_content if isinstance(json_content, bytes) else json_content.encode('utf-8'))
            tmp_json_path = tmp.name
        
        # Create temp path for labeled PDF
        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp_labeled_pdf_path = tmp.name
        
        # Run label_notes (returns True/False for success)
        label_success = run_label_notes(
            pdf_path=tmp_pdf_path,
            json_path=tmp_json_path,
            output_path=tmp_labeled_pdf_path,
            debug=False
        )
        
        # =========================================================================
        # STEP 5: Save labeled PDF to storage (if labeling succeeded)
        # =========================================================================
        label_status = None
        label_warning = None
        
        if label_success and os.path.exists(tmp_labeled_pdf_path):
            try:
                logger.info(f"Uploading labeled PDF for job {job_id}")
                
                with open(tmp_labeled_pdf_path, 'rb') as f:
                    labeled_pdf_content = f.read()
                
                pdf_result = await storage_manager.upload_labeled_pdf(
                    user_id, 
                    job_id, 
                    labeled_pdf_content
                )
                
                label_status = "success"
                logger.info(f"Labeled PDF saved: {pdf_result['storage_path']}")
                
            except Exception as e:
                logger.warning(f"Failed to save labeled PDF for {job_id}: {e}")
                label_status = "failed"
                label_warning = f"Note labeling failed: {str(e)}"
        else:
            logger.warning(f"Label_notes processing failed for job {job_id}")
            label_status = "failed"
            label_warning = "Note labeling pipeline failed"
        
        # =========================================================================
        # STEP 6: Update job status
        # =========================================================================
        final_status = "completed" if label_status == "success" else "completed_with_warning"
        
        result_url = f"sheet_data/{output_json_path}"
        
        await db_client.update_job_status(
            job_id,
            user_id,
            final_status,
            result_url=result_url,
            label_status=label_status,
            label_warning=label_warning
        )
        
        logger.info(f"Job {job_id} completed with status={final_status}, label_status={label_status}")
        
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
    
    finally:
        # Cleanup temporary files
        for tmp_path in [tmp_pdf_path, tmp_json_path, tmp_labeled_pdf_path]:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except Exception as e:
                    logger.warning(f"Failed to cleanup temp file {tmp_path}: {e}")


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
