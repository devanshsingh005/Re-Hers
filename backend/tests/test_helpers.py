"""Helper functions and mock jobs for tests."""
import time
import logging

logger = logging.getLogger(__name__)


def long_running_job(timeout: int = 10):
    """Mock job that runs for a long time (used for timeout testing)."""
    logger.info(f"Starting long-running job (will run {timeout}s)")
    for i in range(timeout * 10):
        time.sleep(0.1)
    logger.info("Long-running job completed")
    return {"status": "completed"}


def quick_job():
    """Mock job that completes quickly."""
    logger.info("Running quick job")
    time.sleep(0.5)
    return {"status": "completed"}


def failing_job():
    """Mock job that always fails."""
    logger.error("Intentional job failure")
    raise RuntimeError("Mock job failure")


def infinite_loop_job():
    """Mock job that loops infinitely (for timeout testing)."""
    logger.info("Starting infinite loop job")
    while True:
        time.sleep(0.1)
