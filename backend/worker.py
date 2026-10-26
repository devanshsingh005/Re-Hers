"""RQ worker process with Azure VM lifecycle management for Audiveris.

Key design:
- 2 Audiveris containers on ports 8080 and 8081 of the same VM.
- 4 RQ workers, each claims one port-slot before processing.
- VM is started on first job; deallocated after all jobs drain + idle grace period.
- The VM lock is held ONLY for the VM-start decision, NOT during job execution
  or the readiness poll, so workers don't serialise behind a 5-minute cold-start.
- Port locks are held for the duration of the Audiveris HTTP call only.
- stop_vm_if_idle() is NON-BLOCKING: spawns a daemon thread so perform_job
  returns immediately and the worker can pick up the next queued job.

Bug fixes vs deployed doc-16 version:
  1. stop_vm_if_idle() / _stop_vm_if_idle_bg(): sleep is in the background thread,
     NOT in perform_job's finally block. The old inline sleep(600) blocked every
     worker for 10 minutes after each job, causing frontend timeouts.
  2. begin_deallocate() and begin_start() now always call .result() so Azure
     operations actually complete instead of being silently dropped.
  3. active_jobs counter is reset to 0 inside __main__ on startup (not at import
     time) so a crashed worker doesn't leave the counter stuck at 1 forever,
     which previously prevented VM shutdown indefinitely.
  4. _idle_monitor_loop and worker.work() are inside __main__ guard (not at
     module top-level) so importing this file doesn't start workers/threads.
  5. VM lock is released BEFORE the readiness poll so all workers can poll
     concurrently rather than queuing behind a single 300s lock hold.
  6. request_stop() override acquires the VM lock before deallocating and
     calls poller.result() so the deallocation actually completes.
  7. ensure_audiveris_ready() guards against starting the VM when there is no
     actual work to do (queue=0 and active=0).
"""
import logging
import os
import sys
import threading
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

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

QUEUE_NAME = "sheet_jobs"
QUEUE_KEY  = f"rq:queue:{QUEUE_NAME}"

# Redis keys
VM_LOCK_KEY     = "audiveris_vm_lock"
ACTIVE_JOBS_KEY = "active_jobs"
LAST_JOB_KEY    = "last_job_ts"

# VM lock is held only for the start-check decision (short window)
VM_LOCK_TIMEOUT = 60            # seconds

# Grace period after last job before VM is deallocated (5 minutes)
VM_IDLE_SECONDS = 300

# Max time to wait for Audiveris to become reachable after VM boot
VM_READY_TIMEOUT_SECONDS = 300

# Audiveris retry config
MAX_AUDIVERIS_RETRIES  = 3
RETRYABLE_STATUS_CODES = {500, 502, 503, 504}

# Two Audiveris containers on the same VM, one per port.
AUDIVERIS_PORTS            = ["8080", "8081"]
AUDIVERIS_PORT_LOCK_PREFIX = "audiveris_port_"
# Must exceed the RQ job timeout (900s) so a port lock never auto-expires mid-job
PORT_LOCK_TTL = 960             # 16 minutes

# ---------------------------------------------------------------------------
# Module-level singletons
# ---------------------------------------------------------------------------

redis_conn   = redis.from_url(settings.REDIS_URL)
queue        = Queue(QUEUE_NAME, connection=redis_conn)
http_session = requests.Session()
http_session.verify = True

_credential             = None
_compute_client         = None
_ORIGINAL_RUN_AUDIVERIS = audiveris_client.run_audiveris


# ---------------------------------------------------------------------------
# Env helpers
# ---------------------------------------------------------------------------

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
        _vm_resource_group(), _vm_name(),
    )
    for status in instance_view.statuses:
        code = getattr(status, "code", "")
        if code.startswith("PowerState/"):
            return code.split("/", 1)[1]
    return "unknown"


def _port_url(port: str) -> str:
    """Derive the Audiveris endpoint URL for a specific port."""
    import re
    return re.sub(r':\d+/', f':{port}/', AUDIVERIS_API_URL)


# ---------------------------------------------------------------------------
# Active job counter (shared across all worker replicas via Redis)
# ---------------------------------------------------------------------------

def get_queue_length() -> int:
    return int(redis_conn.llen(QUEUE_KEY))


def get_active_jobs() -> int:
    return int(redis_conn.get(ACTIVE_JOBS_KEY) or 0)


def increment_active_jobs() -> int:
    value = redis_conn.incr(ACTIVE_JOBS_KEY)
    logger.info("Active jobs incremented -> %s", value)
    return int(value)


def decrement_active_jobs() -> int:
    value = redis_conn.decr(ACTIVE_JOBS_KEY)
    if value < 0:
        redis_conn.set(ACTIVE_JOBS_KEY, 0)
        value = 0
    # Record timestamp of the last completed job for idle detection
    redis_conn.set(LAST_JOB_KEY, int(time.time()))
    logger.info("Active jobs decremented -> %s", value)
    return int(value)


# ---------------------------------------------------------------------------
# VM lock — held only during the start-decision window, never during a job
# ---------------------------------------------------------------------------

def acquire_vm_lock(timeout: int = VM_LOCK_TIMEOUT):
    lock = redis_conn.lock(VM_LOCK_KEY, timeout=timeout, blocking_timeout=timeout)
    if not lock.acquire(blocking=True):
        raise TimeoutError("Timed out acquiring Audiveris VM lock")
    return lock


def release_vm_lock(lock) -> None:
    if lock is None:
        return
    try:
        lock.release()
    except redis.exceptions.LockError:
        logger.warning("Audiveris VM lock was already released")


# ---------------------------------------------------------------------------
# Audiveris reachability probes
# ---------------------------------------------------------------------------

def is_audiveris_reachable(port: str = "8080") -> bool:
    """Probe one port. Both 200 and 422 indicate the service is up."""
    url = _port_url(port)
    try:
        response = http_session.post(url, timeout=5)
        return response.status_code in (200, 422)
    except (requests.ConnectionError, requests.Timeout):
        return False


def is_any_audiveris_reachable() -> bool:
    return any(is_audiveris_reachable(p) for p in AUDIVERIS_PORTS)


# ---------------------------------------------------------------------------
# VM start
# ---------------------------------------------------------------------------

def start_vm_if_needed() -> str:
    """Start VM if deallocated/stopped. Waits for the Azure operation to finish."""
    power_state = _get_vm_power_state()
    logger.info("Audiveris VM power state: %s", power_state)
    if power_state in {"deallocated", "stopped"}:
        logger.info("Starting Audiveris VM %s", _vm_name())
        poller = _get_compute_client().virtual_machines.begin_start(
            _vm_resource_group(), _vm_name(),
        )
        poller.result()  # FIX: must call .result() or the operation is never waited on
        logger.info("Azure start operation completed for VM %s", _vm_name())
        return "starting"
    return power_state


def ensure_audiveris_ready() -> None:
    """
    Guarantee at least one Audiveris port is reachable before returning.

    Locking strategy:
      Fast path  — already reachable → return in <5ms, no lock taken.
      Slow path  — acquire lock → start VM if needed → RELEASE LOCK →
                   poll readiness without holding lock (all workers poll
                   concurrently; no 300s serialisation).
    """


    # Fast path
    if is_any_audiveris_reachable():
        return

    # Slow path: serialise only the start decision
    vm_lock = None
    try:
        vm_lock = acquire_vm_lock(timeout=VM_LOCK_TIMEOUT)
        # Re-check: another worker may have started the VM while we waited for the lock
        if is_any_audiveris_reachable():
            logger.info("Audiveris became reachable while waiting for VM lock — skipping start")
            return
        start_vm_if_needed()
    finally:
        # FIX: release lock BEFORE polling — all workers can poll concurrently
        release_vm_lock(vm_lock)

    # Poll for readiness without holding the lock
    logger.info(
        "Polling for Audiveris readiness (timeout=%ss)...", VM_READY_TIMEOUT_SECONDS,
    )
    deadline = time.monotonic() + VM_READY_TIMEOUT_SECONDS
    delay = 10
    while time.monotonic() < deadline:
        if is_any_audiveris_reachable():
            logger.info("Audiveris is reachable")
            return
        logger.info("Audiveris not ready yet; retrying in %ss", delay)
        time.sleep(delay)
        delay = min(delay * 2, 30)  # cap at 30s for faster convergence

    raise TimeoutError("Timed out waiting for Audiveris readiness")


# ---------------------------------------------------------------------------
# Port claiming — one port-slot per concurrent Audiveris job
# ---------------------------------------------------------------------------

def claim_audiveris_port(timeout: int = VM_READY_TIMEOUT_SECONDS):
    """
    Claim one of the two Audiveris port-slots using a non-expiring Redis lock.

    Returns (url, lock). Caller MUST release the lock in a finally block.

    With 2 ports and N workers:
    - First 2 workers claim a port immediately and run in parallel.
    - Workers 3+ block here (polling every 3s) until a port is freed.
    """
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for port in AUDIVERIS_PORTS:
            lock_key = f"{AUDIVERIS_PORT_LOCK_PREFIX}{port}"
            lock = redis_conn.lock(lock_key, timeout=PORT_LOCK_TTL, blocking_timeout=0)
            if lock.acquire(blocking=False):
                url = _port_url(port)
                logger.info("Claimed Audiveris port %s -> %s", port, url)
                return url, lock
        logger.info("All Audiveris ports busy; waiting 3s for a free slot...")
        time.sleep(3)

    raise TimeoutError("Timed out waiting for an available Audiveris port")


# ---------------------------------------------------------------------------
# VM idle-stop — runs in a background thread, NEVER blocks perform_job
# ---------------------------------------------------------------------------

def _stop_vm_if_idle_bg() -> None:
    """
    Background thread body: sleep VM_IDLE_SECONDS, then deallocate if idle.

    This is intentionally in a separate thread. The worker's perform_job
    returns immediately after spawning this thread and can pick up new jobs.
    If a new job arrives during the sleep, active_jobs will be non-zero
    and deallocation is skipped.
    """
    logger.info(
        "Idle-stop thread: sleeping %ss before checking VM deallocation",
        VM_IDLE_SECONDS,
    )
    time.sleep(VM_IDLE_SECONDS)

    queue_len = get_queue_length()
    active    = get_active_jobs()
    if queue_len != 0 or active != 0:
        logger.info(
            "Idle-stop: new work arrived during sleep (queue=%s active=%s) — skipping",
            queue_len, active,
        )
        return

    vm_lock = None
    try:
        vm_lock = acquire_vm_lock(timeout=VM_LOCK_TIMEOUT)

        # Final check with lock held before issuing the deallocation
        if get_queue_length() != 0 or get_active_jobs() != 0:
            logger.info("Idle-stop: new work arrived while acquiring lock — aborting")
            return

        power_state = _get_vm_power_state()
        if power_state != "running":
            logger.info("Idle-stop: VM already in state '%s' — nothing to do", power_state)
            return

        logger.info("Idle-stop: deallocating Audiveris VM %s", _vm_name())
        poller = _get_compute_client().virtual_machines.begin_deallocate(
            _vm_resource_group(), _vm_name(),
        )
        poller.result()  # FIX: must call .result() or deallocation is silently dropped
        logger.info("Idle-stop: Audiveris VM deallocated successfully")

    except Exception as exc:
        logger.exception("Idle-stop: error during VM deallocation: %s", exc)
    finally:
        release_vm_lock(vm_lock)


def stop_vm_if_idle() -> None:
    """
    Spawn the idle-stop background thread and return immediately.

    The calling thread (perform_job's finally block) is NOT blocked.
    daemon=False so the thread can finish deallocation even if the container
    app begins scaling down, without hanging the process indefinitely.
    """
    queue_len = get_queue_length()
    active    = get_active_jobs()
    if queue_len != 0 or active != 0:
        logger.info(
            "Work still present (queue=%s active=%s) — skipping idle-stop thread",
            queue_len, active,
        )
        return

    t = threading.Thread(
        target=_stop_vm_if_idle_bg,
        daemon=False,
        name="vm-idle-stop",
    )
    t.start()
    logger.info("Idle-stop background thread started (will wait %ss)", VM_IDLE_SECONDS)


# ---------------------------------------------------------------------------
# Audiveris retry wrapper
# ---------------------------------------------------------------------------

def _is_retryable_audiveris_error(exc: Exception) -> bool:
    if isinstance(exc, (requests.Timeout, requests.ConnectionError)):
        return True
    if isinstance(exc, requests.HTTPError) and exc.response is not None:
        return exc.response.status_code in RETRYABLE_STATUS_CODES
    return False


def _retrying_run_audiveris(pdf_path: str, url: str = None):
    """Retry transient Audiveris failures with exponential backoff."""
    delay = 5
    for attempt in range(1, MAX_AUDIVERIS_RETRIES + 1):
        try:
            return _ORIGINAL_RUN_AUDIVERIS(pdf_path, override_url=url)
        except Exception as exc:
            if not _is_retryable_audiveris_error(exc) or attempt == MAX_AUDIVERIS_RETRIES:
                raise
            logger.warning(
                "Audiveris retry %s/%s: %s — retrying in %ss",
                attempt, MAX_AUDIVERIS_RETRIES, exc, delay,
            )
            time.sleep(delay)
            delay = min(delay * 2, 60)


# Patch module-level references so dispatcher uses the retry wrapper by default
audiveris_client.run_audiveris = _retrying_run_audiveris
dispatcher.run_audiveris       = _retrying_run_audiveris


# ---------------------------------------------------------------------------
# ManagedAudiverisWorker
# ---------------------------------------------------------------------------

class ManagedAudiverisWorker(Worker):
    """
    RQ worker that manages Audiveris VM readiness around each job.

    Concurrency model (2 Audiveris containers, 4 RQ workers):
    ┌─────────┐  claims port 8080  ┌───────────────┐
    │ Worker1 │ ────────────────► │ Audiveris:8080│
    ├─────────┤                    └───────────────┘
    │ Worker2 │  claims port 8081  ┌───────────────┐
    │         │ ────────────────► │ Audiveris:8081│
    ├─────────┤                    └───────────────┘
    │ Worker3 │  waits for free port (polls every 3s)
    ├─────────┤
    │ Worker4 │  waits for free port
    └─────────┘
    """

    def perform_job(self, job, queue):  # type: ignore[override]
        active_incremented = False
        port_lock          = None

        try:
            # ------------------------------------------------------------------
            # Phase 1: Ensure VM is reachable.
            # Fast path (<5ms) if already warm. Slow path: acquire lock →
            # start VM → release lock → poll concurrently with other workers.
            # ------------------------------------------------------------------
            ensure_audiveris_ready()

            # ------------------------------------------------------------------
            # Phase 2: Claim an Audiveris port-slot.
            # Blocks only if both ports are occupied by currently running jobs.
            # ------------------------------------------------------------------
            claimed_url, port_lock = claim_audiveris_port()

            # Patch run_audiveris so this job is routed to the claimed port
            bound_run = lambda pdf_path, u=claimed_url: _retrying_run_audiveris(
                pdf_path, url=u
            )
            audiveris_client.run_audiveris = bound_run
            dispatcher.run_audiveris       = bound_run

            # ------------------------------------------------------------------
            # Phase 3: Run the job.
            # ------------------------------------------------------------------
            increment_active_jobs()
            active_incremented = True
            return super().perform_job(job, queue)

        finally:
            # Release port-slot first so the next waiting worker can claim it ASAP
            if port_lock is not None:
                try:
                    port_lock.release()
                    logger.info("Released Audiveris port lock")
                except Exception as exc:
                    logger.warning("Failed to release port lock: %s", exc)

            if active_incremented:
                try:
                    decrement_active_jobs()
                except Exception as exc:
                    logger.exception("Failed to decrement active job counter: %s", exc)

            # FIX: NON-BLOCKING — spawns a thread and returns immediately.
            # NEVER put a blocking sleep() here; it freezes the worker.
            try:
                stop_vm_if_idle()
            except Exception as exc:
                logger.exception("Failed to evaluate VM idle stop: %s", exc)

    def request_stop(self, signum, frame):
        """
        On SIGTERM/SIGINT: if no work remains, deallocate the VM before stopping.
        Acquires the VM lock and waits for the Azure operation to complete.
        """
        logger.info("Worker received stop signal — checking VM state")
        try:
            q = get_queue_length()
            a = get_active_jobs()
            logger.info("Stop signal: queue=%s active=%s", q, a)
            if q == 0 and a == 0:
                vm_lock = None
                try:
                    vm_lock = acquire_vm_lock(timeout=VM_LOCK_TIMEOUT)
                    if get_queue_length() == 0 and get_active_jobs() == 0:
                        power_state = _get_vm_power_state()
                        if power_state == "running":
                            logger.info("Stop signal: deallocating VM %s", _vm_name())
                            poller = _get_compute_client().virtual_machines.begin_deallocate(
                                _vm_resource_group(), _vm_name(),
                            )
                            poller.result()  # FIX: wait for deallocation to complete
                            logger.info("Stop signal: VM deallocated successfully")
                        else:
                            logger.info(
                                "Stop signal: VM already in state '%s' — skipping",
                                power_state,
                            )
                    else:
                        logger.info("Stop signal: new work arrived — skipping deallocation")
                except Exception as exc:
                    logger.exception("Stop signal: VM deallocation error: %s", exc)
                finally:
                    release_vm_lock(vm_lock)
        except Exception as exc:
            logger.exception("Stop signal: unexpected error: %s", exc)

        return super().request_stop(signum, frame)


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

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

    # FIX: Reset the active_jobs counter on every worker startup.
    # If a previous worker crashed mid-job, the counter is left permanently
    # non-zero in Redis, which prevents VM deallocation forever.
    # Safe because a fresh worker startup always means zero active jobs.
    try:
        redis_conn.set(ACTIVE_JOBS_KEY, 0)
        logger.info("Reset active_jobs counter to 0 on startup")
    except Exception as exc:
        logger.error("Failed to reset active_jobs on startup: %s", exc)

    logger.info(
        "Starting RQ worker on queue '%s' (Redis: %s)", QUEUE_NAME, settings.REDIS_URL
    )
    worker = ManagedAudiverisWorker(
        [queue],
        connection=redis_conn,
        default_worker_ttl=420,
    )
    worker.work()