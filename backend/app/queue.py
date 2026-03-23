"""Redis-backed queue for job processing."""
import logging
import redis
from rq import Queue
from supabase import create_client
from app.config import settings, SUPABASE_URL, SUPABASE_KEY, MAX_QUEUE_DEPTH

logger = logging.getLogger(__name__)

# Redis connection — shared by the API process; workers create their own
redis_conn = redis.from_url(settings.REDIS_URL)

# RQ queue with a 15-minute per-job timeout
job_queue = Queue(
    "sheet_jobs",
    connection=redis_conn,
    default_timeout=900,
)

# Supabase client used only for the status guard (no user context available here)
_supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Statuses that mean the job should never be enqueued again.
# NOTE: 'completed' is intentionally excluded — the iOS frontend may write
# status='completed' directly to Supabase before the worker has run.
# The dispatcher will detect this case (label_status=None) and process anyway.
_BLOCK_STATUSES = {"processing", "completed_with_warning", "failed"}


class QueueFullError(RuntimeError):
    """Raised when the job queue has reached MAX_QUEUE_DEPTH capacity.

    The /convert endpoint catches this and returns HTTP 503 so clients
    know to retry later rather than receiving a silent 500.
    """


def enqueue_job(job_payload: dict) -> str:
    """Enqueue a job only when it is still in 'queued' status.

    Queries the database directly (no user context required) and skips
    enqueue if the job has already advanced past the queued state.

    Args:
        job_payload: Must contain {"job_id": str}.

    Returns:
        The job_id string.
    """
    job_id = job_payload["job_id"]

    result = _supabase.table("jobs").select("status").eq("id", job_id).execute()

    if not result.data:
        logger.error(f"enqueue_job: job {job_id} not found in database — skipping")
        return job_id

    status = result.data[0]["status"]
    logger.info(f"enqueue_job: job {job_id} has status='{status}'")

    if status in _BLOCK_STATUSES:
        logger.warning(
            f"enqueue_job: job {job_id} already '{status}' — skipping duplicate enqueue"
        )
        return job_id

    # Queue overflow guard — reject before touching the queue so the caller
    # receives a clear 503 instead of a silent backlog that delays all users.
    current_depth = len(job_queue)
    if current_depth >= MAX_QUEUE_DEPTH:
        logger.error(
            f"Queue overflow: job {job_id} rejected "
            f"(depth={current_depth}/{MAX_QUEUE_DEPTH})"
        )
        raise QueueFullError(
            f"Service is temporarily at capacity "
            f"({current_depth} jobs queued). Please try again later."
        )

    logger.info(f"enqueue_job: enqueueing job {job_id} with status={status}")
    job_queue.enqueue(
        "app.dispatcher.process_job",
        job_payload,
        job_id=job_id,          # RQ job ID = DB job ID → enables StartedJobRegistry lookups
        job_timeout=900,
        result_ttl=3600,        # keep result metadata in Redis for 1 hour
        failure_ttl=86400,      # keep failure details for 24 hours
    )
    logger.info(f"enqueue_job: job {job_id} added to sheet_jobs queue")
    return job_id
