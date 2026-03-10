"""RQ worker process — launch one instance per worker slot via Supervisor."""
import logging
import redis
from rq import Worker, Queue
from app.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

redis_conn = redis.from_url(settings.REDIS_URL)

queue = Queue("sheet_jobs", connection=redis_conn)

if __name__ == "__main__":
    logger.info(f"Starting RQ worker on queue 'sheet_jobs' (Redis: {settings.REDIS_URL})")
    worker = Worker([queue], connection=redis_conn, default_worker_ttl=420)
    worker.work()
