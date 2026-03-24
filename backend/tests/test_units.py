"""Lower-level unit coverage for backend modules."""
from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace

import pytest
import requests
import jwt

from tests.conftest import BackendState, InMemoryDatabaseClient, InMemoryStorageManager, InMemorySupabaseClient


def test_models_job_store_round_trip():
    from app.models import JobStatus, JobStore

    store = JobStore()
    job = store.create_job("job-1", "input.pdf")
    assert job.status == JobStatus.QUEUED
    store.update_job("job-1", status=JobStatus.COMPLETED, output_url="done")
    loaded = store.get_job("job-1")
    assert loaded.output_url == "done"
    assert "job-1" in store.get_all_jobs()


@pytest.mark.asyncio
async def test_auth_manager_verify_and_current_user(monkeypatch):
    from app import auth

    fake_user = SimpleNamespace(
        user=SimpleNamespace(
            id="user-1",
            email="user@example.com",
            user_metadata={"role": "member"},
        )
    )

    monkeypatch.setattr(auth, "create_client", lambda *args, **kwargs: SimpleNamespace(auth=SimpleNamespace(get_user=lambda token: fake_user)))
    manager = auth.AuthManager('http://localhost', "key")
    verified = await manager.verify_token("token")
    assert verified["id"] == "user-1"
    assert verified["email"] == "user@example.com"
    current = await manager.get_current_user("Bearer token")
    assert current["user_metadata"]["role"] == "member"


@pytest.mark.asyncio
async def test_auth_manager_rejects_bad_headers_and_admin(monkeypatch):
    from app import auth

    monkeypatch.setattr(auth, "create_client", lambda *args, **kwargs: SimpleNamespace(auth=SimpleNamespace(get_user=lambda token: (_ for _ in ()).throw(RuntimeError("bad")))))
    manager = auth.AuthManager('http://localhost', "key")

    with pytest.raises(Exception):
        await manager.verify_token("bad")
    with pytest.raises(Exception):
        await manager.get_current_user(None)
    with pytest.raises(Exception):
        await manager.get_current_user("Basic nope")

    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {"admin-user"})
    with pytest.raises(Exception):
        await auth.require_admin({"id": "user-2"})
    allowed = await auth.require_admin({"id": "admin-user"})
    assert allowed["id"] == "admin-user"


@pytest.mark.asyncio
async def test_auth_manager_user_not_found_and_missing_admin_fields(monkeypatch):
    from app import auth

    monkeypatch.setattr(auth, "create_client", lambda *args, **kwargs: SimpleNamespace(auth=SimpleNamespace(get_user=lambda token: None)))
    manager = auth.AuthManager('http://localhost', "key")

    with pytest.raises(Exception):
        await manager.verify_token("token-without-user")
    with pytest.raises(Exception):
        await manager.get_current_user("Token nope")

    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {"admin-user"})
    with pytest.raises(Exception):
        await auth.require_admin({})


@pytest.mark.asyncio
async def test_auth_dependency_wrappers(monkeypatch):
    from app import auth

    class FakeManager:
        async def get_current_user(self, authorization):
            return {"id": "user-1", "authorization": authorization}

    monkeypatch.setattr(auth, "_auth_manager", None)
    monkeypatch.setattr(auth, "AuthManager", lambda *_args: FakeManager())
    manager = auth.get_auth_manager()
    assert await auth.get_current_user("Bearer token") == {"id": "user-1", "authorization": "Bearer token"}
    assert auth.get_auth_manager() is manager

    monkeypatch.setattr("app.config.ADMIN_USER_IDS", set())
    with pytest.raises(Exception):
        await auth.require_admin({"id": "user-1"})


@pytest.mark.asyncio
async def test_auth_manager_wraps_unexpected_verify_failure(monkeypatch):
    from app import auth

    monkeypatch.setattr(auth, "create_client", lambda *args, **kwargs: SimpleNamespace(auth=SimpleNamespace(get_user=lambda token: SimpleNamespace(user=SimpleNamespace(id="user-1", email="user@example.com", user_metadata={})))))
    manager = auth.AuthManager('http://localhost', "key")
    monkeypatch.setattr(manager, "verify_token", lambda _token: (_ for _ in ()).throw(RuntimeError("boom")))

    with pytest.raises(Exception):
        await manager.get_current_user("Bearer token")


@pytest.mark.asyncio
async def test_database_client_job_methods(monkeypatch):
    from app import database

    state = BackendState()
    monkeypatch.setattr(database, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    client = database.DatabaseClient('http://localhost', "key")

    created = await client.create_job("job-1", "user-1", "path/input.pdf")
    assert created["status"] == "pending"
    fetched = await client.get_job("job-1", "user-1")
    assert fetched["pdf_path"] == "path/input.pdf"
    updated = await client.update_job_status("job-1", "user-1", "completed", result_url="out.json", error_message="oops", label_status="success", label_warning="warn")
    assert updated["result_url"] == "out.json"
    jobs = await client.get_user_jobs("user-1")
    assert jobs[0]["id"] == "job-1"
    count = await client.get_user_active_job_count("user-1")
    assert count == 0


@pytest.mark.asyncio
async def test_database_client_sheet_file_methods(monkeypatch):
    from app import database

    state = BackendState()
    monkeypatch.setattr(database, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    client = database.DatabaseClient('http://localhost', "key")

    await client.create_sheet_file("file-1", "user-1", "job-1", "user-1/job-1/output.json", 10, status="completed")
    record = await client.get_sheet_file("file-1", "user-1")
    assert record["job_id"] == "job-1"
    by_job = await client.get_sheet_file_by_job("job-1", "user-1")
    assert by_job["id"] == "file-1"
    user_files = await client.get_user_sheet_files("user-1")
    assert len(user_files) == 1
    updated = await client.update_sheet_file_status("file-1", "user-1", "orphaned")
    assert updated["status"] == "orphaned"
    assert await client.delete_sheet_file("file-1", "user-1") is True
    assert await client.get_all_sheet_files() == []


@pytest.mark.asyncio
async def test_database_client_orphan_marking(monkeypatch):
    from app import database

    state = BackendState()
    monkeypatch.setattr(database, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    client = database.DatabaseClient('http://localhost', "key")
    await client.create_sheet_file("file-2", "user-2", "job-2", "user-2/job-2/output.json", 10, status="completed")
    marked = await client.mark_sheet_file_orphaned("file-2")
    assert marked["status"] == "orphaned"
    orphaned = await client.get_orphaned_db_records()
    assert orphaned[0]["id"] == "file-2"


@pytest.mark.asyncio
async def test_storage_manager_methods(monkeypatch, valid_pdf_bytes):
    from app import storage

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    monkeypatch.setattr(storage, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    manager = storage.StorageManager('http://localhost', "key", db)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "22222222-2222-2222-2222-222222222222"

    uploaded = await manager.upload_json(user_id, job_id, {"hello": "world"})
    assert uploaded["success"] is True
    pdf_path = await manager.upload_pdf(user_id, job_id, valid_pdf_bytes)
    assert pdf_path.endswith("/input.pdf")
    assert await manager.download_pdf(pdf_path) == valid_pdf_bytes
    labeled = await manager.upload_labeled_pdf(user_id, job_id, valid_pdf_bytes)
    assert labeled["storage_path"].endswith("/labeled.pdf")


@pytest.mark.asyncio
async def test_storage_manager_fetch_and_delete(monkeypatch):
    from app import storage

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    monkeypatch.setattr(storage, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    manager = storage.StorageManager('http://localhost', "key", db)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "33333333-3333-3333-3333-333333333333"
    await manager.upload_json(user_id, job_id, {"ok": True})
    result = await manager.get_file_for_user(user_id, job_id)
    assert result["data"]["ok"] is True
    assert await manager.delete_file_for_user(user_id, job_id) is True
    with pytest.raises(PermissionError):
        await manager.get_file_for_user(user_id, job_id)


@pytest.mark.asyncio
async def test_storage_manager_errors_and_legacy_store(monkeypatch, valid_pdf_bytes):
    from app import storage

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    monkeypatch.setattr(storage, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    manager = storage.StorageManager('http://localhost', "key", db)

    with pytest.raises(ValueError):
        await manager.upload_pdf("bad-user", "job", valid_pdf_bytes)

    await db.create_job("job-4", "11111111-1111-1111-1111-111111111111", "x/input.pdf")
    with pytest.raises(FileNotFoundError):
        await manager.get_labeled_pdf_for_user("11111111-1111-1111-1111-111111111111", "job-4")

    monkeypatch.setattr(storage, "create_client", lambda *args, **kwargs: InMemorySupabaseClient(state))
    legacy_url = storage.store_output("legacy-job", {"legacy": True})
    assert legacy_url.startswith('http://signed.local/')


def test_queue_enqueue_job_paths(monkeypatch):
    from app import queue

    class FakeQueue:
        def __init__(self, depth: int):
            self.depth = depth
            self.calls = []

        def __len__(self):
            return self.depth

        def enqueue(self, *args, **kwargs):
            self.calls.append((args, kwargs))

    class FakeSupabase:
        def __init__(self, data):
            self.data = data

        def table(self, name):
            class Query:
                def __init__(self, data):
                    self.data = data

                def select(self, _fields):
                    return self

                def eq(self, _field, _value):
                    return self

                def execute(self):
                    return SimpleNamespace(data=self.data)

            return Query(self.data)

    fake_queue = FakeQueue(0)
    monkeypatch.setattr(queue, "job_queue", fake_queue)
    monkeypatch.setattr(queue, "_supabase", FakeSupabase([]))
    assert queue.enqueue_job({"job_id": "missing"}) == "missing"

    monkeypatch.setattr(queue, "_supabase", FakeSupabase([{"status": "failed"}]))
    assert queue.enqueue_job({"job_id": "blocked"}) == "blocked"

    monkeypatch.setattr(queue, "_supabase", FakeSupabase([{"status": "pending"}]))
    monkeypatch.setattr(queue, "job_queue", FakeQueue(queue.MAX_QUEUE_DEPTH))
    with pytest.raises(queue.QueueFullError):
        queue.enqueue_job({"job_id": "full"})

    fake_queue = FakeQueue(0)
    monkeypatch.setattr(queue, "job_queue", fake_queue)
    assert queue.enqueue_job({"job_id": "ok"}) == "ok"
    assert fake_queue.calls


def test_audiveris_client_success_and_failures(monkeypatch, tmp_path, valid_pdf_bytes):
    import importlib
    from app import audiveris_client as audiveris_client_module

    audiveris_client = importlib.reload(audiveris_client_module)

    pdf_path = tmp_path / "input.pdf"
    pdf_path.write_bytes(valid_pdf_bytes)

    class Response:
        status_code = 200

        def raise_for_status(self):
            return None

        def json(self):
            return {"ok": True}

    monkeypatch.setattr(audiveris_client, "_session", SimpleNamespace(post=lambda *args, **kwargs: Response()))
    assert audiveris_client.run_audiveris(str(pdf_path), override_url='https://api') == {"ok": True}

    monkeypatch.setattr(audiveris_client, "_session", SimpleNamespace(post=lambda *args, **kwargs: (_ for _ in ()).throw(requests.RequestException("boom"))))
    with pytest.raises(requests.RequestException):
        audiveris_client.run_audiveris(str(pdf_path), override_url='https://api')

    with pytest.raises(FileNotFoundError):
        audiveris_client.run_audiveris(str(tmp_path / "missing.pdf"), override_url='https://api')


def test_worker_helper_functions(monkeypatch):
    import worker

    monkeypatch.setenv("AZURE_TENANT_ID", "tenant")
    monkeypatch.setenv("AZURE_CLIENT_ID", "client")
    monkeypatch.setenv("AZURE_CLIENT_SECRET", "secret")
    monkeypatch.setenv("AZURE_SUBSCRIPTION_ID", "sub")
    monkeypatch.setenv("AZURE_RESOURCE_GROUP", "rg")
    monkeypatch.setenv("AUDIVERIS_VM_NAME", "vm")

    assert worker._required_env("AZURE_TENANT_ID") == "tenant"

    class FakeRedis:
        def __init__(self):
            self.data = {worker.ACTIVE_JOBS_KEY: 0, worker.QUEUE_KEY: 0}

        def llen(self, key):
            return self.data.get(key, 0)

        def get(self, key):
            return self.data.get(key, 0)

        def incr(self, key):
            self.data[key] = self.data.get(key, 0) + 1
            return self.data[key]

        def decr(self, key):
            self.data[key] = self.data.get(key, 0) - 1
            return self.data[key]

        def set(self, key, value):
            self.data[key] = value

        def lock(self, name, timeout=0, blocking_timeout=0):
            class Lock:
                def __init__(self):
                    self.released = False

                def acquire(self, blocking=True):
                    return True

                def release(self):
                    self.released = True

            return Lock()

    monkeypatch.setattr(worker, "redis_conn", FakeRedis())
    assert worker.get_queue_length() == 0
    assert worker.increment_active_jobs() == 1
    assert worker.get_active_jobs() == 1
    assert worker.decrement_active_jobs() == 0
    lock = worker.acquire_vm_lock()
    worker.release_vm_lock(lock)


def test_worker_env_and_client_factories(monkeypatch):
    import worker

    monkeypatch.setenv("AZURE_TENANT_ID", "tenant")
    monkeypatch.setenv("AZURE_CLIENT_ID", "client")
    monkeypatch.setenv("AZURE_CLIENT_SECRET", "secret")
    monkeypatch.setenv("AZURE_SUBSCRIPTION_ID", "sub")
    monkeypatch.setenv("AZURE_RESOURCE_GROUP", "rg")
    monkeypatch.setenv("AUDIVERIS_VM_NAME", "vm")

    worker._credential = None
    worker._compute_client = None

    monkeypatch.setattr(worker, "ClientSecretCredential", lambda **kwargs: SimpleNamespace(**kwargs))
    monkeypatch.setattr(worker, "ComputeManagementClient", lambda credential, subscription_id: SimpleNamespace(credential=credential, subscription_id=subscription_id))

    credential = worker._get_credential()
    assert credential.tenant_id == "tenant"
    assert worker._get_credential() is credential

    compute_client = worker._get_compute_client()
    assert compute_client.subscription_id == "sub"
    assert worker._get_compute_client() is compute_client
    assert worker._vm_resource_group() == "rg"
    assert worker._vm_name() == "vm"


def test_worker_vm_power_state_and_lock_edges(monkeypatch):
    import worker
    import redis

    statuses = [SimpleNamespace(code="ProvisioningState/ok"), SimpleNamespace(code="PowerState/running")]
    monkeypatch.setattr(worker, "_get_compute_client", lambda: SimpleNamespace(virtual_machines=SimpleNamespace(instance_view=lambda *_args: SimpleNamespace(statuses=statuses))))
    monkeypatch.setattr(worker, "_vm_resource_group", lambda: "rg")
    monkeypatch.setattr(worker, "_vm_name", lambda: "vm")
    assert worker._get_vm_power_state() == "running"

    monkeypatch.setattr(worker, "_get_compute_client", lambda: SimpleNamespace(virtual_machines=SimpleNamespace(instance_view=lambda *_args: SimpleNamespace(statuses=[]))))
    assert worker._get_vm_power_state() == "unknown"

    class Lock:
        def release(self):
            raise redis.exceptions.LockError("already released")

    worker.release_vm_lock(None)
    worker.release_vm_lock(Lock())


def test_worker_vm_and_port_helpers(monkeypatch):
    import worker

    monkeypatch.setattr(worker, 'http_session', SimpleNamespace(post=lambda *args, **kwargs: SimpleNamespace(status_code=422)))
    assert worker.is_audiveris_reachable() is True

    monkeypatch.setattr(worker, "_get_vm_power_state", lambda: "deallocated")
    monkeypatch.setattr(
        worker,
        "_get_compute_client",
        lambda: SimpleNamespace(
            virtual_machines=SimpleNamespace(
                begin_start=lambda *args, **kwargs: SimpleNamespace(result=lambda: None),
                begin_deallocate=lambda *args, **kwargs: SimpleNamespace(result=lambda: None),
            )
        ),
    )
    monkeypatch.setattr(worker, "_vm_resource_group", lambda: "rg")
    monkeypatch.setattr(worker, "_vm_name", lambda: "vm")
    assert worker.start_vm_if_needed() == "starting"

    monkeypatch.setattr(worker, "is_audiveris_reachable", lambda: True)
    worker.ensure_audiveris_ready()

    monkeypatch.setattr(worker, "get_queue_length", lambda: 0)
    monkeypatch.setattr(worker, "get_active_jobs", lambda: 0)
    monkeypatch.setattr(worker, "time", SimpleNamespace(monotonic=lambda: 0, sleep=lambda _seconds: None))
    monkeypatch.setattr(worker, "acquire_vm_lock", lambda timeout=0: object())
    monkeypatch.setattr(worker, "release_vm_lock", lambda lock: None)
    monkeypatch.setattr(worker, "_get_vm_power_state", lambda: "running")
    worker.stop_vm_if_idle()

    class FakeLock:
        def acquire(self, blocking=False):
            return True

        def release(self):
            return None

    monkeypatch.setattr(worker, "redis_conn", SimpleNamespace(lock=lambda *args, **kwargs: FakeLock()))
    monkeypatch.setattr(worker, "time", SimpleNamespace(monotonic=lambda: 0, sleep=lambda _seconds: None))
    url, _lock = worker.claim_audiveris_port()
    assert ":8080" in url or ":8081" in url


def test_worker_reachability_and_ready_paths(monkeypatch):
    import worker

    monkeypatch.setattr(worker, "http_session", SimpleNamespace(post=lambda *args, **kwargs: (_ for _ in ()).throw(requests.Timeout("timeout"))))
    assert worker.is_audiveris_reachable() is False

    calls = {"ready": 0, "sleep": 0}
    monkeypatch.setattr(worker, "is_audiveris_reachable", lambda: calls.__setitem__("ready", calls["ready"] + 1) or calls["ready"] >= 3)
    monkeypatch.setattr(worker, "start_vm_if_needed", lambda: "starting")
    monkeypatch.setattr(worker, "time", SimpleNamespace(monotonic=lambda: calls["ready"], sleep=lambda _seconds: calls.__setitem__("sleep", calls["sleep"] + 1)))
    worker.ensure_audiveris_ready()
    assert calls["sleep"] == 1

    monkeypatch.setattr(worker, "is_audiveris_reachable", lambda: False)
    monkeypatch.setattr(worker, "start_vm_if_needed", lambda: "weird")
    with pytest.raises(RuntimeError):
        worker.ensure_audiveris_ready()


def test_worker_stop_vm_if_idle_paths(monkeypatch):
    import worker

    monkeypatch.setattr(worker, "get_queue_length", lambda: 1)
    monkeypatch.setattr(worker, "get_active_jobs", lambda: 0)
    worker.stop_vm_if_idle()

    events = {"sleep": 0, "deallocate": 0}
    monkeypatch.setattr(worker, "get_queue_length", lambda: 0)
    monkeypatch.setattr(worker, "get_active_jobs", lambda: 0)
    monkeypatch.setattr(worker, "time", SimpleNamespace(sleep=lambda _seconds: events.__setitem__("sleep", events["sleep"] + 1)))
    monkeypatch.setattr(worker, "acquire_vm_lock", lambda timeout=0: object())
    monkeypatch.setattr(worker, "release_vm_lock", lambda lock: None)
    monkeypatch.setattr(worker, "_get_vm_power_state", lambda: "stopped")
    worker.stop_vm_if_idle()
    assert events["sleep"] == 1

    monkeypatch.setattr(worker, "_get_vm_power_state", lambda: "running")
    monkeypatch.setattr(
        worker,
        "_get_compute_client",
        lambda: SimpleNamespace(virtual_machines=SimpleNamespace(begin_deallocate=lambda *_args: SimpleNamespace(result=lambda: events.__setitem__("deallocate", events["deallocate"] + 1)))),
    )
    monkeypatch.setattr(worker, "_vm_resource_group", lambda: "rg")
    monkeypatch.setattr(worker, "_vm_name", lambda: "vm")
    worker.stop_vm_if_idle()
    assert events["deallocate"] == 1


def test_worker_claim_port_timeout_and_retrying_run(monkeypatch):
    import worker

    class BusyLock:
        def acquire(self, blocking=False):
            return False

    tick = {"now": 0}
    monkeypatch.setattr(worker, "redis_conn", SimpleNamespace(lock=lambda *args, **kwargs: BusyLock()))
    monkeypatch.setattr(worker, "time", SimpleNamespace(monotonic=lambda: tick.__setitem__("now", tick["now"] + 500) or tick["now"], sleep=lambda _seconds: None))
    with pytest.raises(TimeoutError):
        worker.claim_audiveris_port()

    sleeps = []
    attempts = {"count": 0}

    def flaky_run(_pdf_path, override_url=None):
        attempts["count"] += 1
        if attempts["count"] < 3:
            raise requests.Timeout("retry me")
        return {"ok": True, "url": override_url}

    monkeypatch.setattr(worker, "_ORIGINAL_RUN_AUDIVERIS", flaky_run)
    monkeypatch.setattr(worker, "time", SimpleNamespace(sleep=lambda seconds: sleeps.append(seconds)))
    result = worker._retrying_run_audiveris("input.pdf", url="https://audiveris")
    assert result["ok"] is True
    assert sleeps == [5, 10]


def test_worker_retrying_run_non_retryable_and_worker_cleanup(monkeypatch):
    import worker

    monkeypatch.setattr(worker, "_ORIGINAL_RUN_AUDIVERIS", lambda *_args, **_kwargs: (_ for _ in ()).throw(RuntimeError("nope")))
    with pytest.raises(RuntimeError):
        worker._retrying_run_audiveris("input.pdf", url="https://audiveris")

    order = []

    class PortLock:
        def release(self):
            order.append("release-port")

    fake_worker = object.__new__(worker.ManagedAudiverisWorker)
    monkeypatch.setattr(worker, "acquire_vm_lock", lambda timeout=0: object())
    monkeypatch.setattr(worker, "release_vm_lock", lambda lock: order.append("release-vm"))
    monkeypatch.setattr(worker, "ensure_audiveris_ready", lambda: (_ for _ in ()).throw(ConnectionError("boot")) if order.count("release-vm") == 0 else None)
    monkeypatch.setattr(worker, "claim_audiveris_port", lambda: ("http://localhost:8080", PortLock()))
    monkeypatch.setattr(worker, "increment_active_jobs", lambda: order.append("inc"))
    monkeypatch.setattr(worker, "decrement_active_jobs", lambda: order.append("dec"))
    monkeypatch.setattr(worker, "stop_vm_if_idle", lambda: order.append("stop"))
    monkeypatch.setattr(worker.Worker, "perform_job", lambda self, job, queue: "done")

    assert worker.ManagedAudiverisWorker.perform_job(fake_worker, object(), object()) == "done"
    assert "release-vm" in order
    assert "release-port" in order
    assert order[-2:] == ["dec", "stop"] or order[-3:] == ["release-port", "dec", "stop"]


def test_worker_retryable_classifier():
    import worker

    timeout_exc = requests.Timeout("timeout")
    conn_exc = requests.ConnectionError("conn")
    response = SimpleNamespace(status_code=500)
    http_exc = requests.HTTPError(response=response)
    assert worker._is_retryable_audiveris_error(timeout_exc) is True
    assert worker._is_retryable_audiveris_error(conn_exc) is True
    assert worker._is_retryable_audiveris_error(http_exc) is True


def test_label_notes_helpers():
    from app import label_notes

    assert label_notes._sanitize_upstream("bad\x00value") == "badvalue"
    assert label_notes.pitch_to_diatonic_index("C", 4) == 28
    assert label_notes.pitch_label({"pitch": {"step": "A", "octave": "4"}}) == "A4"
    assert label_notes.compute_tenths_to_pt({"millimeters": "7", "tenths": "40"}) > 0
    assert label_notes.staff_space_pt(1.5) == pytest.approx(15.0)
    clefs = label_notes.parse_clefs({"clef": [{"@number": "1", "sign": "G"}, {"@number": "2", "sign": "F"}]})
    assert clefs == {1: "G", 2: "F"}
    assert label_notes.parse_staff_distance({"staff-layout": {"staff-distance": "12"}}, 2.0) == 24.0
    assert label_notes.get_note_staff_number({"staff": "2"}) == 2
    layout = label_notes.extract_system_layout({"system-layout": {"system-distance": "5", "system-margins": {"left-margin": "7"}}})
    assert layout["system_distance"] == 5.0


def test_label_notes_process_success(tmp_path):
    from app import label_notes

    json_path = tmp_path / "score.json"
    out_path = tmp_path / "out.pdf"
    payload = {
        "score-partwise": {
            "defaults": {
                "scaling": {"millimeters": "7", "tenths": "40"},
                "page-layout": {
                    "page-height": "1000",
                    "page-width": "800",
                    "page-margins": {
                        "top-margin": "10",
                        "left-margin": "10",
                        "right-margin": "10",
                        "bottom-margin": "10",
                    },
                },
            },
            "part": {
                "measure": [
                    {
                        "@number": "1",
                        "@width": "200",
                        "attributes": {"clef": {"sign": "G", "line": "2"}},
                        "note": {
                            "@default-x": "20",
                            "pitch": {"step": "C", "octave": "4"},
                        },
                    }
                ]
            },
        }
    }
    json_path.write_text(json.dumps(payload), encoding="utf-8")
    assert label_notes.process("-", str(json_path), str(out_path), debug=False) is True
    assert out_path.exists()


def test_label_notes_page_boundary_multisystem_and_debug(monkeypatch, tmp_path):
    from app import label_notes

    json_path = tmp_path / "score.json"
    out_path = tmp_path / "out.pdf"
    payload = {
        "score-partwise": {
            "defaults": {
                "scaling": {"millimeters": "7", "tenths": "40"},
                "page-layout": {
                    "page-height": "1000",
                    "page-width": "800",
                    "page-margins": {"top-margin": "10", "left-margin": "10", "right-margin": "10", "bottom-margin": "10"},
                },
            },
            "part": {
                "measure": [
                    {
                        "@number": "1",
                        "@width": "780",
                        "attributes": {"clef": [{"@number": "1", "sign": "G"}, {"@number": "2", "sign": "F"}]},
                        "print": {"system-layout": {"system-margins": {"left-margin": "0"}, "top-system-distance": "20"}},
                        "note": [
                            {"@default-x": "779", "pitch": {"step": "C", "octave": "4"}},
                            {"@default-x": "bad", "pitch": {"step": "D", "octave": "4"}},
                            {"@default-x": "0", "pitch": {"step": "E", "octave": "4"}, "staff": "2"},
                        ],
                    },
                    {
                        "@number": "2",
                        "@width": "200",
                        "print": {"@new-system": "yes", "system-layout": {"system-distance": "12", "system-margins": {"left-margin": "5"}}, "staff-layout": {"staff-distance": "15"}},
                        "note": {"@default-x": "10", "pitch": {"step": "F", "octave": "4"}},
                    },
                ]
            },
        }
    }
    json_path.write_text(json.dumps(payload), encoding="utf-8")

    inserts = []
    debug_calls = {"rect": 0, "line": 0, "anchor": 0}

    class FakeRect:
        width = 200
        height = 300

    class FakePage:
        def __init__(self):
            self.rect = FakeRect()
            self.derotation_matrix = 1

        def insert_text(self, point, label, **kwargs):
            inserts.append((point, label, kwargs))

    class FakeDoc:
        def __init__(self):
            self.pages = [FakePage()]

        def __getitem__(self, index):
            return self.pages[index]

        def __len__(self):
            return len(self.pages)

        def new_page(self, width=None, height=None):
            self.pages.append(FakePage())
            return self.pages[-1]

        def save(self, path, garbage=0, deflate=False):
            Path(path).write_bytes(b"%PDF-1.4\n%%EOF")

        def close(self):
            return None

    monkeypatch.setattr(label_notes.os.path, "isfile", lambda _path: True)
    monkeypatch.setattr(label_notes.fitz, "open", lambda _path=None: FakeDoc())
    monkeypatch.setattr(label_notes, "_t", lambda page, x, y: (x, y))
    monkeypatch.setattr(label_notes, "debug_measure_rect", lambda *args, **kwargs: debug_calls.__setitem__("rect", debug_calls["rect"] + 1))
    monkeypatch.setattr(label_notes, "debug_staff_top_line", lambda *args, **kwargs: debug_calls.__setitem__("line", debug_calls["line"] + 1))
    monkeypatch.setattr(label_notes, "debug_note_anchor", lambda *args, **kwargs: debug_calls.__setitem__("anchor", debug_calls["anchor"] + 1))

    assert label_notes.process(str(tmp_path / "input.pdf"), str(json_path), str(out_path), debug=True) is True
    assert out_path.exists()
    assert len(inserts) >= 3
    assert debug_calls["rect"] >= 2
    assert debug_calls["line"] >= 2
    assert debug_calls["anchor"] >= 2


def test_label_notes_malformed_upstream_is_sanitised(tmp_path, caplog):
    from app import label_notes

    json_path = tmp_path / "bad.json"
    out_path = tmp_path / "out.pdf"
    json_path.write_text(json.dumps({"detail": "bad\x00detail", "stderr": "x" * 500, "stdout": "ok\nline"}), encoding="utf-8")

    with caplog.at_level("ERROR"):
        assert label_notes.process(None, str(json_path), str(out_path), debug=False) is False
    assert "baddetail" in caplog.text
    assert "\x00" not in caplog.text


@pytest.mark.asyncio
async def test_main_startup_and_recovery_helpers(monkeypatch):
    from app import main

    created = {"task": False, "updated": []}
    monkeypatch.setattr(main, "redis_conn", SimpleNamespace(ping=lambda: True))
    monkeypatch.setattr(main.asyncio, "create_task", lambda coro: created.__setitem__("task", True) or coro.close() or SimpleNamespace())
    async with main.lifespan(main.app):
        assert created["task"] is True

    class FakeRegistry:
        def __init__(self, *args, **kwargs):
            pass

        def get_job_ids(self):
            return []

    class FakeTable:
        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def execute(self):
            return SimpleNamespace(data=[{"id": "job-1", "user_id": "user-1"}])

    monkeypatch.setattr(main, "StartedJobRegistry", FakeRegistry)
    monkeypatch.setattr(main.db_client, "client", SimpleNamespace(table=lambda _name: FakeTable()))

    async def fake_update(job_id, user_id, status):
        created["updated"].append((job_id, user_id, status))

    monkeypatch.setattr(main.db_client, "update_job_status", fake_update)
    monkeypatch.setattr(main, "enqueue_job", lambda payload: created["updated"].append(("enqueue", payload["job_id"])))
    await main.recover_stuck_jobs()
    assert ("job-1", "user-1", "pending") in created["updated"]


def test_limiter_key_paths():
    from starlette.requests import Request
    from app.limiter import _rate_limit_key

    def request_with_headers(headers):
        scope = {
            "type": 'http',
            "method": "GET",
            "path": "/",
            "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()],
            "client": ("127.0.0.1", 1234),
        }
        return Request(scope)

    valid = jwt.encode({"sub": "user-1", "exp": 9999999999}, "test-jwt-secret", algorithm="HS256")
    expired = jwt.encode({"sub": "user-1", "exp": 1}, "test-jwt-secret", algorithm="HS256")
    assert _rate_limit_key(request_with_headers({"Authorization": f"Bearer {valid}"})) == "user:user-1"
    assert _rate_limit_key(request_with_headers({"Authorization": f"Bearer {expired}"})).startswith("ip:")
    assert _rate_limit_key(request_with_headers({"Authorization": "Bearer bad"})).startswith("ip:")


@pytest.mark.asyncio
async def test_orphan_summary_and_cleanup_error_paths_async(monkeypatch):
    from app.orphan_detector import OrphanDetector

    detector = OrphanDetector(SimpleNamespace(), SimpleNamespace())

    async def detect_error():
        return {"error": "boom"}

    monkeypatch.setattr(detector, "detect_orphans", detect_error)
    summary = await detector.get_orphan_summary()
    assert summary["status"] == "error"

    async def detect_report():
        return {"orphaned_storage_files": ["a"], "orphaned_db_records": [], "is_healthy": False, "total_storage_files": 1, "total_db_records": 1}

    detector = OrphanDetector(SimpleNamespace(mark_sheet_file_orphaned=lambda _id: None), SimpleNamespace(client=SimpleNamespace(storage=SimpleNamespace(from_=lambda _bucket: SimpleNamespace(remove=lambda _paths: (_ for _ in ()).throw(RuntimeError("boom"))))), bucket="sheet_data"))
    monkeypatch.setattr(detector, "detect_orphans", detect_report)
    result = await detector.cleanup_orphans(dry_run=False)
    assert "actions" in result


@pytest.mark.asyncio
async def test_orphan_detector_detects_missing_and_extra_files(monkeypatch):
    from app.orphan_detector import OrphanDetector
    from storage3.utils import StorageException

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    storage_client = InMemorySupabaseClient(state)
    detector = OrphanDetector(db, SimpleNamespace(client=SimpleNamespace(storage=storage_client.storage), bucket="sheet_data"))

    await db.create_sheet_file("file-1", "user-1", "job-1", "user-1/job-1/output.json", 10, status="completed")
    await db.create_sheet_file("file-2", "user-1", "job-2", "user-1/job-2/output.json", 10, status="completed")
    state.storage["sheet_data"]["user-1/job-1/output.json"] = b'{"ok":true}'
    state.storage["sheet_data"]["orphan/output.json"] = b'{}'

    bucket = storage_client.storage.from_("sheet_data")

    def custom_download(path: str) -> bytes:
        if path == "user-1/job-2/output.json":
            raise StorageException("not found")
        return state.storage["sheet_data"][path]

    bucket.custom_download = custom_download
    report = await detector.detect_orphans()
    assert "orphan/output.json" in report["orphaned_storage_files"]
    assert any(item["job_id"] == "job-2" for item in report["orphaned_db_records"])
    assert report["is_healthy"] is False


@pytest.mark.asyncio
async def test_orphan_detector_cleanup_marks_orphan_and_deletes_storage():
    from app.orphan_detector import OrphanDetector
    from storage3.utils import StorageException

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    storage_client = InMemorySupabaseClient(state)
    detector = OrphanDetector(db, SimpleNamespace(client=SimpleNamespace(storage=storage_client.storage), bucket="sheet_data"))

    await db.create_sheet_file("file-1", "user-1", "job-1", "user-1/job-1/output.json", 10, status="completed")
    state.storage["sheet_data"]["orphan/output.json"] = b'{}'

    bucket = storage_client.storage.from_("sheet_data")
    bucket.custom_download = lambda _path: (_ for _ in ()).throw(StorageException("not found"))

    result = await detector.cleanup_orphans(dry_run=False)
    assert "orphan/output.json" in result["actions"]["deleted_storage_files"]
    assert result["actions"]["marked_orphaned"][0]["file_id"] == "file-1"


def test_dispatcher_normalize_helpers(tmp_path, valid_pdf_bytes):
    from app import dispatcher

    pdf_path = tmp_path / "score.pdf"
    pdf_path.write_bytes(valid_pdf_bytes)
    normalized = dispatcher.normalize_pdf_ctm(str(pdf_path))
    assert Path(normalized).exists()

    json_data = {
        "score-partwise": {
            "defaults": {
                "scaling": {"millimeters": "7", "tenths": "40"},
                "page-layout": {
                    "page-width": "800",
                    "page-height": "1000",
                    "page-margins": {"left-margin": "10", "right-margin": "10"},
                },
            },
            "part": {"measure": []},
        }
    }
    result = dispatcher.normalize_json_for_pdf(json_data, str(pdf_path))
    assert "score-partwise" in result


def test_dispatcher_normalize_fallbacks(monkeypatch, tmp_path):
    from app import dispatcher

    pdf_path = tmp_path / "missing.pdf"
    json_data = {"score-partwise": {"defaults": {"scaling": {"millimeters": "7", "tenths": "40"}, "page-layout": {"page-width": "10", "page-height": "10", "page-margins": {"left-margin": "0", "right-margin": "0"}}}, "part": {"measure": []}}}

    monkeypatch.setattr(dispatcher, "fitz", None)
    assert dispatcher.normalize_pdf_ctm(str(pdf_path)) == str(pdf_path)
    assert dispatcher.normalize_json_for_pdf(json_data, str(pdf_path)) == json_data


def test_dispatcher_normalize_wrap_and_overflow(monkeypatch, tmp_path):
    from app import dispatcher

    class FakePage:
        def __init__(self, raw: bytes):
            self._raw = raw
            self.wraps = 0
            self.rect = SimpleNamespace(width=100.0, height=200.0)
            self.mediabox = SimpleNamespace(x0=0, y0=0, x1=100, y1=200)
            self.cropbox = SimpleNamespace(x0=0, y0=0, x1=100, y1=200)

        def read_contents(self):
            return self._raw

        def wrap_contents(self):
            self.wraps += 1

    class FakeDoc:
        def __init__(self):
            self.pages = [FakePage(b"0.1 0 0 0.1 0 0 cm q")]

        def __iter__(self):
            return iter(self.pages)

        def __getitem__(self, index):
            return self.pages[index]

        def save(self, path, garbage=0, deflate=False):
            Path(path).write_bytes(b"%PDF-1.4\n%%EOF")

        def close(self):
            return None

    fake_doc = FakeDoc()
    monkeypatch.setattr(dispatcher.fitz, "open", lambda _path: fake_doc)
    wrapped_path = dispatcher.normalize_pdf_ctm(str(tmp_path / "input.pdf"))
    assert Path(wrapped_path).exists()
    assert fake_doc.pages[0].wraps == 1

    json_data = {
        "score-partwise": {
            "defaults": {
                "scaling": {"millimeters": "7", "tenths": "40"},
                "page-layout": {
                    "page-width": "800",
                    "page-height": "1000",
                    "page-margins": {"left-margin": "20", "right-margin": "20"},
                },
            },
            "part": {
                "measure": [
                    {"@width": "900", "print": {"system-layout": {"system-margins": {"left-margin": "50"}}}},
                ]
            },
        }
    }
    normalized = dispatcher.normalize_json_for_pdf(json_data, str(tmp_path / "input.pdf"))
    margins = normalized["score-partwise"]["defaults"]["page-layout"]["page-margins"]
    assert margins["left-margin"] == "0"
    assert margins["right-margin"] == "0"


@pytest.mark.asyncio
async def test_dispatcher_failure_path_updates_job(monkeypatch, valid_pdf_bytes):
    from app import dispatcher

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    storage = InMemorySupabaseClient(state)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "55555555-5555-5555-5555-555555555555"
    await db.create_job(job_id, user_id, f"{user_id}/{job_id}/input.pdf")
    state.storage["pdf_uploads"][f"{user_id}/{job_id}/input.pdf"] = valid_pdf_bytes

    dispatcher.db_client = db
    dispatcher.storage_manager = SimpleNamespace(client=SimpleNamespace(storage=storage.storage), upload_labeled_pdf=lambda *args, **kwargs: None)
    monkeypatch.setattr(dispatcher, "run_audiveris", lambda _path: (_ for _ in ()).throw(RuntimeError("boom")))
    await dispatcher.async_process_job({"job_id": job_id})
    assert state.jobs[job_id]["status"] == "failed"


@pytest.mark.asyncio
async def test_dispatcher_labeled_pdf_upload_failure_becomes_warning(monkeypatch, valid_pdf_bytes):
    from app import dispatcher

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    storage_manager = InMemoryStorageManager(state, db)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "88888888-8888-8888-8888-888888888888"
    pdf_path = await storage_manager.upload_pdf(user_id, job_id, valid_pdf_bytes)
    await db.create_job(job_id, user_id, pdf_path)

    dispatcher.db_client = db
    dispatcher.storage_manager = storage_manager
    monkeypatch.setattr(dispatcher, "run_audiveris", lambda _path: {"score-partwise": {"defaults": {"scaling": {"millimeters": "7", "tenths": "40"}, "page-layout": {"page-width": "800", "page-height": "1000", "page-margins": {"left-margin": "0", "right-margin": "0"}}}, "part": {"measure": []}}})

    def fake_label_notes(pdf_path: str, json_path: str, output_path: str, debug: bool = False) -> bool:
        Path(output_path).write_bytes(b"%PDF-1.4\n%%EOF")
        return True

    async def broken_upload(*args, **kwargs):
        raise RuntimeError("disk full")

    monkeypatch.setattr(dispatcher, "run_label_notes", fake_label_notes)
    monkeypatch.setattr(storage_manager, "upload_labeled_pdf", broken_upload)
    await dispatcher.async_process_job({"job_id": job_id})
    assert state.jobs[job_id]["status"] == "completed_with_warning"
    assert state.jobs[job_id]["label_status"] == "failed"
    assert state.jobs[job_id]["label_warning"] == "Note labeling failed"


@pytest.mark.asyncio
async def test_dispatcher_cleanup_warning_on_unlink_failure(monkeypatch, valid_pdf_bytes, caplog):
    from app import dispatcher

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "99999999-9999-9999-9999-999999999999"
    await db.create_job(job_id, user_id, f"{user_id}/{job_id}/input.pdf")
    state.storage["pdf_uploads"][f"{user_id}/{job_id}/input.pdf"] = valid_pdf_bytes

    dispatcher.db_client = db
    dispatcher.storage_manager = SimpleNamespace(client=SimpleNamespace(storage=InMemorySupabaseClient(state).storage))
    monkeypatch.setattr(dispatcher, "run_audiveris", lambda _path: (_ for _ in ()).throw(RuntimeError("boom")))
    monkeypatch.setattr(dispatcher.os, "unlink", lambda _path: (_ for _ in ()).throw(OSError("nope")))
    with caplog.at_level("WARNING"):
        await dispatcher.async_process_job({"job_id": job_id})
    assert "Failed to cleanup temp file" in caplog.text


@pytest.mark.asyncio
async def test_dispatcher_returns_when_job_missing():
    from app import dispatcher

    state = BackendState()
    dispatcher.db_client = InMemoryDatabaseClient(state)
    dispatcher.storage_manager = InMemoryStorageManager(state, dispatcher.db_client)
    await dispatcher.async_process_job({"job_id": "missing"})
    assert state.jobs == {}


@pytest.mark.asyncio
async def test_dispatcher_skips_terminal_jobs(monkeypatch):
    from app import dispatcher

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "66666666-6666-6666-6666-666666666666"
    await db.create_job(job_id, user_id, f"{user_id}/{job_id}/input.pdf", status="completed")
    state.jobs[job_id]["label_status"] = "success"

    dispatcher.db_client = db
    dispatcher.storage_manager = InMemoryStorageManager(state, db)

    called = {"audiveris": False}
    monkeypatch.setattr(dispatcher, "run_audiveris", lambda _path: called.__setitem__("audiveris", True))
    await dispatcher.async_process_job({"job_id": job_id})
    assert called["audiveris"] is False
    assert state.jobs[job_id]["status"] == "completed"


@pytest.mark.asyncio
async def test_dispatcher_success_path_completes_job(monkeypatch, valid_pdf_bytes):
    from app import dispatcher

    state = BackendState()
    db = InMemoryDatabaseClient(state)
    storage_manager = InMemoryStorageManager(state, db)
    user_id = "11111111-1111-1111-1111-111111111111"
    job_id = "77777777-7777-7777-7777-777777777777"
    pdf_path = await storage_manager.upload_pdf(user_id, job_id, valid_pdf_bytes)
    await db.create_job(job_id, user_id, pdf_path)

    dispatcher.db_client = db
    dispatcher.storage_manager = storage_manager
    monkeypatch.setattr(dispatcher, "run_audiveris", lambda _path: {"score-partwise": {"defaults": {"scaling": {"millimeters": "7", "tenths": "40"}, "page-layout": {"page-width": "800", "page-height": "1000", "page-margins": {"left-margin": "0", "right-margin": "0"}}}, "part": {"measure": []}}})

    def fake_label_notes(pdf_path: str, json_path: str, output_path: str, debug: bool = False) -> bool:
        Path(output_path).write_bytes(b"%PDF-1.4\n%%EOF")
        return True

    monkeypatch.setattr(dispatcher, "run_label_notes", fake_label_notes)
    await dispatcher.async_process_job({"job_id": job_id})
    assert state.jobs[job_id]["status"] == "completed"
    assert state.jobs[job_id]["label_status"] == "success"
    assert state.jobs[job_id]["result_url"].endswith("/labeled.pdf")
    assert any(record["job_id"] == job_id for record in state.sheet_files.values())


def test_worker_perform_job_and_retry_helpers(monkeypatch):
    import worker

    calls = {"inc": 0, "dec": 0, "stop": 0}

    monkeypatch.setattr(worker, "acquire_vm_lock", lambda timeout=0: object())
    monkeypatch.setattr(worker, "release_vm_lock", lambda lock: None)
    monkeypatch.setattr(worker, "ensure_audiveris_ready", lambda: None)
    monkeypatch.setattr(worker, "claim_audiveris_port", lambda: ('http://localhost:8080', SimpleNamespace(release=lambda: None)))
    monkeypatch.setattr(worker, "increment_active_jobs", lambda: calls.__setitem__("inc", calls["inc"] + 1))
    monkeypatch.setattr(worker, "decrement_active_jobs", lambda: calls.__setitem__("dec", calls["dec"] + 1))
    monkeypatch.setattr(worker, "stop_vm_if_idle", lambda: calls.__setitem__("stop", calls["stop"] + 1))
    monkeypatch.setattr(worker.Worker, "perform_job", lambda self, job, queue: "done")
    fake_worker = object.__new__(worker.ManagedAudiverisWorker)
    assert worker.ManagedAudiverisWorker.perform_job(fake_worker, object(), object()) == "done"
    assert calls == {"inc": 1, "dec": 1, "stop": 1}
