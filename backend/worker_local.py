"""RQ worker process — local development mode.

Identical to worker.py except Azure VM lifecycle calls are stubbed out.
No Azure credentials are required. The Audiveris API must already be
reachable at AUDIVERIS_API_URL before jobs are submitted.
"""
import logging
import os
import sys
import time

import redis
import requests
from rq import Queue, SimpleWorker as Worker

import app.audiveris_client as audiveris_client
import app.dispatcher as dispatcher
from app.config import AUDIVERIS_API_URL, settings, validate_audiveris_api_url

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

QUEUE_NAME = "sheet_jobs"
QUEUE_KEY = f"rq:queue:{QUEUE_NAME}"
VM_LOCK_KEY = "audiveris_vm_lock"
ACTIVE_JOBS_KEY = "active_jobs"
VM_LOCK_TIMEOUT = 120
VM_IDLE_SECONDS = 600
VM_READY_TIMEOUT_SECONDS = 300
MAX_AUDIVERIS_RETRIES = 3
RETRYABLE_STATUS_CODES = {500, 502, 503, 504}
AUDIVERIS_PORTS = ["8080", "8081"]
AUDIVERIS_PORT_LOCK_PREFIX = "audiveris_port_"

redis_conn = redis.from_url(settings.REDIS_URL)
queue = Queue(QUEUE_NAME, connection=redis_conn)
http_session = requests.Session()
http_session.verify = True

_ORIGINAL_RUN_AUDIVERIS = audiveris_client.run_audiveris


# ── Azure stubs (local dev: VM is always assumed running) ─────────────────────

def _get_vm_power_state() -> str:
    """Local dev stub — assume the VM (local Audiveris process) is always running."""
    logger.debug("LOCAL MODE: _get_vm_power_state() → 'running'")
    return "running"


def start_vm_if_needed() -> str:
    """Local dev stub — nothing to start; return 'running'."""
    logger.info("LOCAL MODE: start_vm_if_needed() → no-op, returning 'running'")
    return "running"


def stop_vm_if_idle() -> None:
    """Local dev stub — nothing to stop."""
    logger.debug("LOCAL MODE: stop_vm_if_idle() → no-op")


# ── Shared helpers (identical to worker.py) ───────────────────────────────────

def get_queue_length() -> int:
    """Return the number of pending RQ jobs in Redis."""
    return int(redis_conn.llen(QUEUE_KEY))


def get_active_jobs() -> int:
    """Return the current distributed active job count."""
    return int(redis_conn.get(ACTIVE_JOBS_KEY) or 0)


def increment_active_jobs() -> int:
    """Increment the active job counter."""
    value = redis_conn.incr(ACTIVE_JOBS_KEY)
    logger.info("Active jobs incremented -> %s", value)
    return int(value)


def decrement_active_jobs() -> int:
    """Decrement the active job counter, clamping the value at zero."""
    value = redis_conn.decr(ACTIVE_JOBS_KEY)
    if value < 0:
        redis_conn.set(ACTIVE_JOBS_KEY, 0)
        value = 0
    logger.info("Active jobs decremented -> %s", value)
    return int(value)


def acquire_vm_lock(timeout: int = VM_LOCK_TIMEOUT):
    """Acquire the Redis lock that serializes Audiveris VM transitions."""
    lock = redis_conn.lock(VM_LOCK_KEY, timeout=timeout, blocking_timeout=timeout)
    if not lock.acquire(blocking=True):
        raise TimeoutError("Timed out acquiring Audiveris VM lock")
    return lock


def release_vm_lock(lock) -> None:
    """Release the Redis lock that serializes Audiveris VM transitions."""
    if lock is None:
        return
    try:
        lock.release()
    except redis.exceptions.LockError:
        logger.warning("Audiveris VM lock was already released")


def is_audiveris_reachable() -> bool:
    """Probe Audiveris via HTTP and accept a validation failure as readiness."""
    try:
        response = http_session.post(AUDIVERIS_API_URL, timeout=5)
        return response.status_code in (200, 422)
    except (requests.ConnectionError, requests.Timeout):
        return False


def ensure_audiveris_ready() -> None:
    """Make sure the Audiveris API is reachable.

    In local dev mode we never start an Azure VM — instead we poll until
    the locally-running Audiveris process responds, then give up after
    VM_READY_TIMEOUT_SECONDS.
    """
    if is_audiveris_reachable():
        return

    logger.warning(
        "Audiveris not reachable at %s — waiting up to %ss "
        "(LOCAL MODE: will NOT start an Azure VM)",
        AUDIVERIS_API_URL,
        VM_READY_TIMEOUT_SECONDS,
    )

    deadline = time.monotonic() + VM_READY_TIMEOUT_SECONDS
    delay = 10
    while time.monotonic() < deadline:
        if is_audiveris_reachable():
            logger.info("Audiveris is reachable at %s", AUDIVERIS_API_URL)
            return
        logger.info("Audiveris not ready yet; retrying in %ss", delay)
        time.sleep(delay)
        delay = min(delay * 2, 60)

    raise TimeoutError(
        f"Timed out waiting for Audiveris readiness at {AUDIVERIS_API_URL}. "
        "Please ensure the Audiveris service is running locally on port 8080."
    )


def claim_audiveris_port():
    """Claim an available Audiveris port from the port pool using Redis locks."""
    deadline = time.monotonic() + VM_READY_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        for port in AUDIVERIS_PORTS:
            lock = redis_conn.lock(f"{AUDIVERIS_PORT_LOCK_PREFIX}{port}", timeout=300)
            if lock.acquire(blocking=False):
                url = AUDIVERIS_API_URL.replace(":8080/", f":{port}/")
                logger.info("Claimed Audiveris port %s", port)
                return url, lock
        logger.info("All Audiveris ports busy, retrying in 5s")
        time.sleep(5)
    raise TimeoutError("Timed out waiting for an available Audiveris port")


def _is_retryable_audiveris_error(exc: Exception) -> bool:
    if isinstance(exc, (requests.Timeout, requests.ConnectionError)):
        return True
    if isinstance(exc, requests.HTTPError) and exc.response is not None:
        return exc.response.status_code in RETRYABLE_STATUS_CODES
    return False


def _retrying_run_audiveris(pdf_path: str, url: str = None):
    """Retry transient Audiveris API failures with exponential backoff."""
    delay = 5
    for attempt in range(1, MAX_AUDIVERIS_RETRIES + 1):
        try:
            return _ORIGINAL_RUN_AUDIVERIS(pdf_path, override_url=url)
        except Exception as exc:  # noqa: BLE001
            if not _is_retryable_audiveris_error(exc) or attempt == MAX_AUDIVERIS_RETRIES:
                raise
            logger.warning(
                "Audiveris request retry %s/%s because %s",
                attempt,
                MAX_AUDIVERIS_RETRIES,
                exc,
            )
            time.sleep(delay)
            delay = min(delay * 2, 60)


audiveris_client.run_audiveris = _retrying_run_audiveris
dispatcher.run_audiveris = _retrying_run_audiveris


# ── Worker (identical to worker.py) ──────────────────────────────────────────

class ManagedAudiverisWorker(Worker):
    """RQ worker that manages Audiveris readiness around each job.

    In local dev mode the Azure VM stubs mean no cloud calls are made;
    everything else (port claiming, retry logic, active job counters) is
    identical to production.
    """

    def perform_job(self, job, queue):  # type: ignore[override]
        active_incremented = False
        port_lock = None
        try:
            vm_lock = None
            for attempt in range(1, MAX_AUDIVERIS_RETRIES + 1):
                try:
                    vm_lock = acquire_vm_lock()
                    ensure_audiveris_ready()
                    break
                except (ConnectionError, TimeoutError, OSError) as exc:
                    if attempt == MAX_AUDIVERIS_RETRIES:
                        raise
                    delay = min(5 * (2 ** (attempt - 1)), 60)
                    logger.warning(
                        "Audiveris startup retry %s/%s because %s",
                        attempt,
                        MAX_AUDIVERIS_RETRIES,
                        exc,
                    )
                    time.sleep(delay)
                finally:
                    release_vm_lock(vm_lock)
                    vm_lock = None

            claimed_url, port_lock = claim_audiveris_port()
            audiveris_client.run_audiveris = lambda pdf_path, u=claimed_url: _retrying_run_audiveris(pdf_path, url=u)
            dispatcher.run_audiveris = audiveris_client.run_audiveris

            increment_active_jobs()
            active_incremented = True
            return super().perform_job(job, queue)
        finally:
            if port_lock is not None:
                try:
                    port_lock.release()
                except Exception as exc:  # noqa: BLE001
                    logger.warning("Failed to release port lock: %s", exc)
            if active_incremented:
                try:
                    decrement_active_jobs()
                except Exception as exc:  # noqa: BLE001
                    logger.exception("Failed to decrement active job counter: %s", exc)
            try:
                stop_vm_if_idle()
            except Exception as exc:  # noqa: BLE001
                logger.exception("Failed to evaluate Audiveris VM idle stop: %s", exc)


if __name__ == "__main__":
    try:
        validate_audiveris_api_url(AUDIVERIS_API_URL)
    except ValueError as exc:
        logger.error("Worker configuration error: %s", exc)
        sys.exit(1)

    logger.info(
        "Starting LOCAL RQ worker on queue '%s' (Redis: %s) — Azure VM management DISABLED",
        QUEUE_NAME,
        settings.REDIS_URL,
    )
    worker = ManagedAudiverisWorker(
        [queue],
        connection=redis_conn,
        default_worker_ttl=420
    )
    # Disable forking for local development on macOS to avoid fork-safety segfaults (signal 11).
    # This also makes debugging easier as logs from the job will appear in this same process.
    worker.work(with_scheduler=True)
