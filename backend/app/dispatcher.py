"""Background dispatcher for processing jobs from the queue."""
import time
import threading
import logging
from app.queue import job_queue
from app.models import job_store, JobStatus
from app.audiveris_client import run_audiveris
from app.storage import store_output

logger = logging.getLogger(__name__)

# Lock to ensure only one job runs at a time
_execution_lock = threading.Lock()


def process_job(job_id: str) -> None:
    """Process a single job.
    
    Args:
        job_id: The job ID to process.
    """
    job = job_store.get_job(job_id)
    if not job:
        logger.error(f"Job {job_id} not found in store")
        return
    
    try:
        # Mark job as running
        job_store.update_job(job_id, status=JobStatus.RUNNING)
        logger.info(f"Processing job {job_id}")
        
        # Call Audiveris API
        json_output = run_audiveris(job.input_pdf_path)
        
        # Store output in Supabase
        output_url = store_output(job_id, json_output)
        
        # Mark job as completed
        job_store.update_job(
            job_id,
            status=JobStatus.COMPLETED,
            output_url=output_url
        )
        logger.info(f"Job {job_id} completed successfully. Output URL: {output_url}")
        
    except Exception as e:
        # Mark job as failed
        error_message = str(e)
        job_store.update_job(
            job_id,
            status=JobStatus.FAILED,
            error=error_message
        )
        logger.error(f"Job {job_id} failed: {error_message}")


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
                process_job(job_id)
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
