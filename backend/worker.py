"""RQ worker process with Azure VM lifecycle management for Audiveris."""
import logging
import os
import sys
import time

import redis
import requests
from azure.identity import ClientSecretCredential
from azure.mgmt.compute import ComputeManagementClient
from rq import Queue, Worker

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

_credential = None
_compute_client = None
_ORIGINAL_RUN_AUDIVERIS = audiveris_client.run_audiveris


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def _get_credential() -> ClientSecretCredential:
    global _credential
    if _credential is None:
        _credential = ClientSecretCredential(
            tenant_id=_required_env("AZURE_TENANT_ID"),
            client_id=_required_env("AZURE_CLIENT_ID"),
            client_secret=_required_env("AZURE_CLIENT_SECRET"),
        )
    return _credential


def _get_compute_client() -> ComputeManagementClient:
    global _compute_client
    if _compute_client is None:
        _compute_client = ComputeManagementClient(
            credential=_get_credential(),
            subscription_id=_required_env("AZURE_SUBSCRIPTION_ID"),
        )
    return _compute_client


def _vm_resource_group() -> str:
    return _required_env("AZURE_RESOURCE_GROUP")


def _vm_name() -> str:
    return _required_env("AUDIVERIS_VM_NAME")


def _get_vm_power_state() -> str:
    instance_view = _get_compute_client().virtual_machines.instance_view(
        _vm_resource_group(),
        _vm_name(),
    )
    for status in instance_view.statuses:
        code = getattr(status, "code", "")
        if code.startswith("PowerState/"):
            return code.split("/", 1)[1]
    return "unknown"


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


def start_vm_if_needed() -> str:
    """Start the Audiveris VM when it is not already running."""
    power_state = _get_vm_power_state()
    logger.info("Audiveris VM power state: %s", power_state)
    if power_state in {"deallocated", "stopped"}:
        logger.info("Starting Audiveris VM %s", _vm_name())
        poller = _get_compute_client().virtual_machines.begin_start(
            _vm_resource_group(),
            _vm_name(),
        )
        poller.result()
        return "starting"
    return power_state


def ensure_audiveris_ready() -> None:
    """Make sure the Audiveris VM is reachable before processing a job."""
    if is_audiveris_reachable():
        return

    power_state = start_vm_if_needed()
    if power_state not in {"running", "starting", "deallocated", "stopped"}:
        raise RuntimeError(f"Unexpected Audiveris VM power state: {power_state}")

    deadline = time.monotonic() + VM_READY_TIMEOUT_SECONDS
    delay = 10
    while time.monotonic() < deadline:
        if is_audiveris_reachable():
            logger.info("Audiveris is reachable at %s", AUDIVERIS_API_URL)
            return
        logger.info("Audiveris not ready yet; retrying in %ss", delay)
        time.sleep(delay)
        delay = min(delay * 2, 60)

    raise TimeoutError("Timed out waiting for Audiveris readiness")


def stop_vm_if_idle() -> None:
    """Deallocate the Audiveris VM when the queue and worker pool are idle."""
    if get_queue_length() != 0 or get_active_jobs() != 0:
        logger.info(
            "Skipping Audiveris VM stop; queue_length=%s active_jobs=%s",
            get_queue_length(),
            get_active_jobs(),
        )
        return

    logger.info("Audiveris appears idle; waiting %ss before deallocating VM", VM_IDLE_SECONDS)
    time.sleep(VM_IDLE_SECONDS)

    lock = acquire_vm_lock(timeout=VM_LOCK_TIMEOUT)
    try:
        if get_queue_length() != 0 or get_active_jobs() != 0:
            logger.info(
                "Aborting Audiveris VM stop; queue_length=%s active_jobs=%s",
                get_queue_length(),
                get_active_jobs(),
            )
            return

        power_state = _get_vm_power_state()
        if power_state != "running":
            logger.info("Skipping Audiveris VM deallocation; power_state=%s", power_state)
            return

        logger.info("Deallocating Audiveris VM %s", _vm_name())
        poller = _get_compute_client().virtual_machines.begin_deallocate(
            _vm_resource_group(),
            _vm_name(),
        )
        poller.result()
    finally:
        release_vm_lock(lock)


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


class ManagedAudiverisWorker(Worker):
    """RQ worker that manages Audiveris VM readiness around each job."""

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
        _required_env("AZURE_TENANT_ID")
        _required_env("AZURE_CLIENT_ID")
        _required_env("AZURE_CLIENT_SECRET")
        _required_env("AZURE_SUBSCRIPTION_ID")
        _required_env("AZURE_RESOURCE_GROUP")
        _required_env("AUDIVERIS_VM_NAME")
    except (RuntimeError, ValueError) as exc:
        logger.error("Worker configuration error: %s", exc)
        sys.exit(1)
    logger.info("Starting RQ worker on queue '%s' (Redis: %s)", QUEUE_NAME, settings.REDIS_URL)
    worker = ManagedAudiverisWorker([queue], connection=redis_conn, default_worker_ttl=420)
    worker.work()
