"""Pytest configuration and shared fixtures for backend security tests."""
from __future__ import annotations

import base64
import copy
import io
import os
import re
import time
import warnings
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from typing import Any, Callable
from uuid import uuid4

import fakeredis
import httpx
import jwt
import pytest
import anyio
from fastapi import Header, HTTPException
from storage3.utils import StorageException

os.environ.setdefault("AUDIVERIS_API_URL", 'http://localhost:8080')
os.environ.setdefault("SUPABASE_URL", 'http://localhost:54321')
os.environ.setdefault(
    "SUPABASE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRlc3QiLCJyb2xlIjoic2VydmljZV9yb2xlIiwiZXhwIjo0MTAyNDQ0ODAwfQ."
    "dGVzdC1zaWduYXR1cmU",
)
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-jwt-secret")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379")
os.environ.setdefault("ADMIN_USER_IDS", "")


TEST_JWT_SECRET = os.environ["SUPABASE_JWT_SECRET"]


def _iso_now() -> str:
    return datetime.now(UTC).isoformat()


@dataclass
class BackendState:
    users: dict[str, dict[str, Any]] = field(default_factory=dict)
    jobs: dict[str, dict[str, Any]] = field(default_factory=dict)
    sheet_files: dict[str, dict[str, Any]] = field(default_factory=dict)
    storage: dict[str, dict[str, bytes]] = field(
        default_factory=lambda: {"sheet_data": {}, "pdf_uploads": {}}
    )
    enqueued_jobs: list[str] = field(default_factory=list)
    deleted_storage_paths: list[str] = field(default_factory=list)
    current_time: float = field(default_factory=lambda: time.time())

    def add_user(self, email: str | None = None) -> dict[str, Any]:
        user_id = str(uuid4())
        user = {
            "id": user_id,
            "email": email or f"{user_id[:8]}@example.com",
            "user_metadata": {},
        }
        self.users[user_id] = user
        return user

    def remove_user(self, user_id: str) -> None:
        self.users.pop(user_id, None)
        self.jobs = {job_id: job for job_id, job in self.jobs.items() if job["user_id"] != user_id}
        self.sheet_files = {
            file_id: record
            for file_id, record in self.sheet_files.items()
            if record["user_id"] != user_id
        }


class FakeQuery:
    def __init__(self, state: BackendState, table_name: str):
        self.state = state
        self.table_name = table_name
        self.filters: list[tuple[str, str, Any]] = []
        self.operation = "select"
        self.payload: Any = None
        self.order_field: str | None = None
        self.order_desc = False
        self.range_start: int | None = None
        self.range_end: int | None = None

    def select(self, _fields: str) -> "FakeQuery":
        self.operation = "select"
        return self

    def insert(self, payload: dict[str, Any]) -> "FakeQuery":
        self.operation = "insert"
        self.payload = payload
        return self

    def update(self, payload: dict[str, Any]) -> "FakeQuery":
        self.operation = "update"
        self.payload = payload
        return self

    def delete(self) -> "FakeQuery":
        self.operation = "delete"
        return self

    def upsert(self, payload: dict[str, Any], on_conflict: str | None = None) -> "FakeQuery":
        self.operation = "upsert"
        self.payload = payload
        self.on_conflict = on_conflict
        return self

    def eq(self, field_name: str, value: Any) -> "FakeQuery":
        self.filters.append(("eq", field_name, value))
        return self

    def in_(self, field_name: str, values: list[Any]) -> "FakeQuery":
        self.filters.append(("in", field_name, values))
        return self

    def order(self, field_name: str, desc: bool = False) -> "FakeQuery":
        self.order_field = field_name
        self.order_desc = desc
        return self

    def range(self, start: int, end: int) -> "FakeQuery":
        self.range_start = start
        self.range_end = end
        return self

    def _rows(self) -> dict[str, dict[str, Any]]:
        return self.state.jobs if self.table_name == "jobs" else self.state.sheet_files

    def _matches(self, row: dict[str, Any]) -> bool:
        for operator, field_name, value in self.filters:
            if operator == "eq" and row.get(field_name) != value:
                return False
            if operator == "in" and row.get(field_name) not in value:
                return False
        return True

    def execute(self) -> SimpleNamespace:
        rows = self._rows()
        if self.operation == "insert":
            payload = copy.deepcopy(self.payload)
            rows[payload["id"]] = payload
            return SimpleNamespace(data=[copy.deepcopy(payload)])
        if self.operation == "upsert":
            payload = copy.deepcopy(self.payload)
            rows[payload["id"]] = payload
            return SimpleNamespace(data=[copy.deepcopy(payload)])
        if self.operation == "update":
            updated = []
            for row_id, row in list(rows.items()):
                if self._matches(row):
                    row.update(copy.deepcopy(self.payload))
                    rows[row_id] = row
                    updated.append(copy.deepcopy(row))
            return SimpleNamespace(data=updated)
        if self.operation == "delete":
            deleted = []
            for row_id, row in list(rows.items()):
                if self._matches(row):
                    deleted.append(copy.deepcopy(row))
                    del rows[row_id]
            return SimpleNamespace(data=deleted)

        data = [copy.deepcopy(row) for row in rows.values() if self._matches(row)]
        if self.order_field:
            data.sort(key=lambda item: item.get(self.order_field, ""), reverse=self.order_desc)
        if self.range_start is not None and self.range_end is not None:
            data = data[self.range_start : self.range_end + 1]
        return SimpleNamespace(data=data)


class FakeSupabaseTableClient:
    def __init__(self, state: BackendState):
        self.state = state

    def table(self, table_name: str) -> FakeQuery:
        return FakeQuery(self.state, table_name)


class InMemoryDatabaseClient:
    def __init__(self, state: BackendState):
        self.state = state
        self.client = FakeSupabaseTableClient(state)

    async def create_job(self, job_id: str, user_id: str, pdf_path: str, status: str = "pending") -> dict[str, Any]:
        now = _iso_now()
        job = {
            "id": job_id,
            "user_id": user_id,
            "pdf_path": pdf_path,
            "status": status,
            "result_url": None,
            "error_message": None,
            "label_status": None,
            "label_warning": None,
            "created_at": now,
            "updated_at": now,
        }
        self.state.jobs[job_id] = job
        return copy.deepcopy(job)

    async def get_job(self, job_id: str, user_id: str) -> dict[str, Any] | None:
        job = self.state.jobs.get(job_id)
        if not job or job["user_id"] != user_id:
            return None
        return copy.deepcopy(job)

    async def update_job_status(
        self,
        job_id: str,
        user_id: str,
        status: str,
        result_url: str | None = None,
        error_message: str | None = None,
        label_status: str | None = None,
        label_warning: str | None = None,
    ) -> dict[str, Any]:
        job = self.state.jobs.get(job_id)
        if not job or job["user_id"] != user_id:
            raise Exception("Job not found or unauthorized")
        job["status"] = status
        job["updated_at"] = _iso_now()
        if result_url is not None:
            job["result_url"] = result_url
        if error_message is not None:
            job["error_message"] = error_message
        if label_status is not None:
            job["label_status"] = label_status
        if label_warning is not None:
            job["label_warning"] = label_warning
        return copy.deepcopy(job)

    async def get_user_jobs(self, user_id: str, limit: int = 50, offset: int = 0) -> list[dict[str, Any]]:
        jobs = [copy.deepcopy(job) for job in self.state.jobs.values() if job["user_id"] == user_id]
        jobs.sort(key=lambda item: item["created_at"], reverse=True)
        return jobs[offset : offset + limit]

    async def get_user_active_job_count(self, user_id: str) -> int:
        return sum(
            1
            for job in self.state.jobs.values()
            if job["user_id"] == user_id and job["status"] in {"pending", "queued", "processing"}
        )

    async def create_sheet_file(
        self,
        file_id: str,
        user_id: str,
        job_id: str,
        storage_path: str,
        file_size_bytes: int | None = None,
        status: str = "processing",
    ) -> dict[str, Any]:
        now = _iso_now()
        record = {
            "id": file_id,
            "user_id": user_id,
            "job_id": job_id,
            "storage_path": storage_path,
            "file_size_bytes": file_size_bytes,
            "status": status,
            "created_at": now,
            "updated_at": now,
        }
        self.state.sheet_files[file_id] = record
        return copy.deepcopy(record)

    async def get_sheet_file_by_job(self, job_id: str, user_id: str) -> dict[str, Any] | None:
        for record in self.state.sheet_files.values():
            if record["job_id"] == job_id and record["user_id"] == user_id:
                return copy.deepcopy(record)
        return None

    async def delete_sheet_file(self, file_id: str, user_id: str) -> bool:
        record = self.state.sheet_files.get(file_id)
        if not record or record["user_id"] != user_id:
            return False
        del self.state.sheet_files[file_id]
        return True

    async def get_all_sheet_files(self) -> list[dict[str, Any]]:
        return [copy.deepcopy(record) for record in self.state.sheet_files.values()]

    async def get_orphaned_db_records(self) -> list[dict[str, Any]]:
        return [
            copy.deepcopy(record)
            for record in self.state.sheet_files.values()
            if record.get("status") == "orphaned"
        ]

    async def mark_sheet_file_orphaned(self, file_id: str) -> dict[str, Any]:
        record = self.state.sheet_files[file_id]
        record["status"] = "orphaned"
        record["updated_at"] = _iso_now()
        return copy.deepcopy(record)


class FakeStorageBucket:
    def __init__(self, state: BackendState, bucket_name: str):
        self.state = state
        self.bucket_name = bucket_name
        self.custom_download: Callable[[str], bytes] | None = None
        self.custom_remove: Callable[[list[str]], Any] | None = None

    def upload(self, path: str, file: bytes, file_options: dict[str, Any] | None = None) -> dict[str, Any]:
        self.state.storage[self.bucket_name][path] = file
        return {"path": path}

    def download(self, path: str) -> bytes:
        if self.custom_download is not None:
            return self.custom_download(path)
        if path not in self.state.storage[self.bucket_name]:
            raise StorageException("not found")
        return self.state.storage[self.bucket_name][path]

    def list(self, recursive: bool = False) -> list[SimpleNamespace]:
        return [SimpleNamespace(name=path) for path in sorted(self.state.storage[self.bucket_name])]

    def remove(self, paths: list[str]) -> list[dict[str, Any]]:
        if self.custom_remove is not None:
            return self.custom_remove(paths)
        for path in paths:
            self.state.deleted_storage_paths.append(path)
            self.state.storage[self.bucket_name].pop(path, None)
        return [{"name": path} for path in paths]

    def create_signed_url(self, path: str, expires_in: int) -> dict[str, str]:
        expiry = int(self.state.current_time + expires_in)
        return {
            "signedURL": (
                f'http://signed.local/{self.bucket_name}/{path}'
                f"?exp={expiry}&token=test-token"
            )
        }


class FakeStorageAPI:
    def __init__(self, state: BackendState):
        self.state = state
        self.buckets: dict[str, FakeStorageBucket] = {}

    def from_(self, bucket_name: str) -> FakeStorageBucket:
        if bucket_name not in self.buckets:
            self.buckets[bucket_name] = FakeStorageBucket(self.state, bucket_name)
        return self.buckets[bucket_name]


class InMemorySupabaseClient:
    def __init__(self, state: BackendState):
        self.state = state
        self.storage = FakeStorageAPI(state)
        self.auth = SimpleNamespace(get_user=lambda token: None)

    def table(self, table_name: str) -> FakeQuery:
        return FakeQuery(self.state, table_name)


class InMemoryStorageManager:
    def __init__(self, state: BackendState, db: InMemoryDatabaseClient):
        self.state = state
        self.db = db
        self.bucket = "sheet_data"
        self.client = SimpleNamespace(storage=FakeStorageAPI(state))

    async def upload_pdf(self, user_id: str, job_id: str, pdf_content: bytes) -> str:
        path = f"{user_id}/{job_id}/input.pdf"
        self.client.storage.from_("pdf_uploads").upload(path, pdf_content)
        return path

    async def upload_labeled_pdf(self, user_id: str, job_id: str, pdf_content: bytes) -> dict[str, Any]:
        path = f"{user_id}/{job_id}/labeled.pdf"
        self.client.storage.from_("pdf_uploads").upload(path, pdf_content)
        return {"success": True, "storage_path": path, "file_size_bytes": len(pdf_content)}

    async def get_file_for_user(self, user_id: str, job_id: str) -> dict[str, Any]:
        record = await self.db.get_sheet_file_by_job(job_id, user_id)
        if not record:
            raise PermissionError("File not found or user unauthorized")
        payload = self.client.storage.from_(self.bucket).download(record["storage_path"])
        return {"data": __import__("json").loads(payload)}

    async def delete_file_for_user(self, user_id: str, job_id: str) -> bool:
        record = await self.db.get_sheet_file_by_job(job_id, user_id)
        if not record:
            raise PermissionError("File not found or user unauthorized")
        self.client.storage.from_(self.bucket).remove([record["storage_path"]])
        await self.db.delete_sheet_file(record["id"], user_id)
        return True

    async def get_labeled_pdf_for_user(self, user_id: str, job_id: str) -> bytes:
        job = await self.db.get_job(job_id, user_id)
        if not job:
            raise PermissionError("Job not found or user unauthorized")
        return self.client.storage.from_("pdf_uploads").download(f"{user_id}/{job_id}/labeled.pdf")

    def fetch_signed_url_status(self, signed_url: str) -> int:
        match = re.search(r'http://signed\.local/([^/]+)/(.+)\?exp=(\d+)', signed_url)
        if not match:
            return 400
        bucket_name, path, expiry = match.groups()
        if self.state.current_time > int(expiry):
            return 403
        if path not in self.state.storage.get(bucket_name, {}):
            return 404
        return 200


class ASGITestClient:
    def __init__(self, app):
        self.app = app
        self.base_url = 'http://testserver'

    def request(self, method: str, url: str, **kwargs):
        async def _send():
            transport = httpx.ASGITransport(app=self.app, raise_app_exceptions=False)
            async with httpx.AsyncClient(transport=transport, base_url=self.base_url) as client:
                return await client.request(method, url, **kwargs)

        return anyio.run(_send)

    def get(self, url: str, **kwargs):
        return self.request("GET", url, **kwargs)

    def post(self, url: str, **kwargs):
        return self.request("POST", url, **kwargs)

    def options(self, url: str, **kwargs):
        return self.request("OPTIONS", url, **kwargs)


def _make_jwt(user_id: str, email: str, secret: str, expires_delta: timedelta) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": user_id,
        "email": email,
        "role": "authenticated",
        "iat": int(now.timestamp()),
        "exp": int((now + expires_delta).timestamp()),
    }
    return jwt.encode(payload, secret, algorithm="HS256")


@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    import asyncio

    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def backend_state() -> BackendState:
    return BackendState()


@pytest.fixture
def test_supabase_client(backend_state: BackendState) -> InMemorySupabaseClient:
    return InMemorySupabaseClient(backend_state)


@pytest.fixture
def user_factory(backend_state: BackendState) -> Callable[[str | None], dict[str, Any]]:
    created_ids: list[str] = []

    def create_user(email: str | None = None) -> dict[str, Any]:
        user = backend_state.add_user(email=email)
        created_ids.append(user["id"])
        return user

    yield create_user

    for user_id in created_ids:
        backend_state.remove_user(user_id)


@pytest.fixture
def fresh_test_user(user_factory: Callable[[str | None], dict[str, Any]]) -> dict[str, Any]:
    return user_factory()


@pytest.fixture
def valid_jwt(fresh_test_user: dict[str, Any]) -> str:
    return _make_jwt(fresh_test_user["id"], fresh_test_user["email"], TEST_JWT_SECRET, timedelta(hours=1))


@pytest.fixture
def expired_jwt(fresh_test_user: dict[str, Any]) -> str:
    return _make_jwt(fresh_test_user["id"], fresh_test_user["email"], TEST_JWT_SECRET, timedelta(seconds=-60))


@pytest.fixture
def malformed_jwt() -> str:
    return "notajwt"


@pytest.fixture
def wrong_secret_jwt(fresh_test_user: dict[str, Any]) -> str:
    return _make_jwt(fresh_test_user["id"], fresh_test_user["email"], "wrong-secret", timedelta(hours=1))


@pytest.fixture
def valid_pdf_bytes() -> bytes:
    return (
        b"%PDF-1.4\n"
        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
        b"2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj\n"
        b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\n"
        b"trailer<</Root 1 0 R>>\n"
        b"%%EOF"
    )


@pytest.fixture
def valid_pdf_file(valid_pdf_bytes: bytes) -> tuple[str, bytes, str]:
    return ("score.pdf", valid_pdf_bytes, "application/pdf")


@pytest.fixture
def valid_jpeg_bytes() -> bytes:
    return (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
        b"\xff\xdb\x00C" + (b"\x08" * 64) +
        b"\xff\xc0\x00\x11\x08\x00\x01\x00\x01\x03\x01\x11\x00\x02\x11\x01\x03\x11\x01"
        b"\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xd2\xcf \xff\xd9"
    )


@pytest.fixture
def valid_jpeg_file(valid_jpeg_bytes: bytes) -> tuple[str, bytes, str]:
    return ("photo.jpg", valid_jpeg_bytes, "image/jpeg")


@pytest.fixture
def pdf_magic_with_jpg_extension(valid_pdf_bytes: bytes) -> tuple[str, bytes, str]:
    return ("fake.jpg", valid_pdf_bytes, "image/jpeg")


@pytest.fixture
def jpeg_magic_with_pdf_extension(valid_jpeg_bytes: bytes) -> tuple[str, bytes, str]:
    return ("fake.pdf", valid_jpeg_bytes, "application/pdf")


@pytest.fixture
def random_bytes_pdf() -> tuple[str, bytes, str]:
    return ("random.pdf", os.urandom(64), "application/pdf")


@pytest.fixture
def empty_pdf_file() -> tuple[str, bytes, str]:
    return ("empty.pdf", b"", "application/pdf")


@pytest.fixture
def truncated_pdf_file() -> tuple[str, bytes, str]:
    return ("truncated.pdf", b"%PDF123456", "application/pdf")


@pytest.fixture
def html_disguised_as_pdf() -> tuple[str, bytes, str]:
    return ("page.pdf", b"<html><body>nope</body></html>", "application/pdf")


@pytest.fixture
def oversized_pdf_file() -> tuple[str, bytes, str]:
    size = 4096
    body = b"%PDF" + (b"0" * (size - 9)) + b"%%EOF"
    return ("oversized.pdf", body, "application/pdf")


@pytest.fixture
def mock_redis():
    return fakeredis.FakeRedis()


@pytest.fixture
def redis_unavailable():
    class UnavailableRedis:
        def ping(self):
            raise ConnectionError("redis unavailable")

        def __getattr__(self, name: str):
            def _raise(*args, **kwargs):
                raise ConnectionError("redis unavailable")

            return _raise

    return UnavailableRedis()


@pytest.fixture
def auth_header() -> Callable[[str], dict[str, str]]:
    def build(token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    return build


@pytest.fixture
def app_client(monkeypatch, backend_state: BackendState, mock_redis):
    import supabase
    db_client = InMemoryDatabaseClient(backend_state)
    storage_manager = InMemoryStorageManager(backend_state, db_client)
    import_supabase_client = InMemorySupabaseClient(backend_state)
    monkeypatch.setattr(supabase, "create_client", lambda *args, **kwargs: import_supabase_client)
    from app import auth, main, queue
    from app.orphan_detector import OrphanDetector
    orphan_detector = OrphanDetector(db_client, storage_manager)

    async def override_get_current_user(authorization: str | None = Header(None)) -> dict[str, Any]:
        if not authorization:
            raise HTTPException(status_code=401, detail="Missing authorization header")
        parts = authorization.split()
        if len(parts) != 2 or parts[0].lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid authorization header")
        token = parts[1]
        try:
            payload = jwt.decode(token, TEST_JWT_SECRET, algorithms=["HS256"])
        except jwt.ExpiredSignatureError as exc:
            raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
        except jwt.InvalidTokenError as exc:
            raise HTTPException(status_code=401, detail="Invalid or expired token") from exc
        user_id = payload.get("sub")
        user = backend_state.users.get(user_id)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
        return user

    async def enqueue_stub(job_payload: dict[str, Any]) -> str:
        backend_state.enqueued_jobs.append(job_payload["job_id"])
        return job_payload["job_id"]

    monkeypatch.setattr(main, "db_client", db_client)
    monkeypatch.setattr(main, "storage_manager", storage_manager)
    monkeypatch.setattr(main, "orphan_detector", orphan_detector)
    monkeypatch.setattr(main, "enqueue_job", lambda payload: backend_state.enqueued_jobs.append(payload["job_id"]) or payload["job_id"])
    monkeypatch.setattr(main, "redis_conn", mock_redis)
    def _disable_rate_limit(request, *args, **kwargs):
        request.state.view_rate_limit = None
        return None

    monkeypatch.setattr(main.limiter, "_check_request_limit", _disable_rate_limit)
    monkeypatch.setattr(queue, "redis_conn", mock_redis)
    monkeypatch.setattr(queue, "_supabase", db_client.client)

    main.app.dependency_overrides[auth.get_current_user] = override_get_current_user
    original_lifespan_context = main.app.router.lifespan_context

    @asynccontextmanager
    async def test_lifespan(_app):
        yield

    main.app.router.lifespan_context = test_lifespan

    client = ASGITestClient(main.app)
    yield {
        "client": client,
        "db": db_client,
        "storage": storage_manager,
        "state": backend_state,
        "enqueue": enqueue_stub,
        "main": main,
        "auth": auth,
    }

    main.app.dependency_overrides.clear()
    main.app.router.lifespan_context = original_lifespan_context


@pytest.fixture
def create_completed_job(app_client, fresh_test_user: dict[str, Any], valid_pdf_bytes: bytes) -> Callable[..., dict[str, Any]]:
    import json

    def factory(
        *,
        user: dict[str, Any] | None = None,
        status: str = "completed",
        error_message: str | None = None,
        label_status: str | None = "success",
        label_warning: str | None = None,
        json_payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        user = user or fresh_test_user
        job_id = str(uuid4())
        now = _iso_now()
        pdf_path = f"{user['id']}/{job_id}/input.pdf"
        result_path = f"{user['id']}/{job_id}/output.json"
        app_client["state"].storage["pdf_uploads"][pdf_path] = valid_pdf_bytes
        app_client["state"].storage["pdf_uploads"][f"{user['id']}/{job_id}/labeled.pdf"] = valid_pdf_bytes
        payload = json_payload or {"title": "Test", "job_id": job_id}
        app_client["state"].storage["sheet_data"][result_path] = __import__("json").dumps(payload).encode("utf-8")
        app_client["state"].jobs[job_id] = {
            "id": job_id,
            "user_id": user["id"],
            "pdf_path": pdf_path,
            "status": status,
            "result_url": result_path,
            "error_message": error_message,
            "label_status": label_status,
            "label_warning": label_warning,
            "created_at": now,
            "updated_at": now,
        }
        file_id = str(uuid4())
        app_client["state"].sheet_files[file_id] = {
            "id": file_id,
            "user_id": user["id"],
            "job_id": job_id,
            "storage_path": result_path,
            "file_size_bytes": len(app_client["state"].storage["sheet_data"][result_path]),
            "status": "completed",
            "created_at": now,
            "updated_at": now,
        }
        return copy.deepcopy(app_client["state"].jobs[job_id])

    return factory


def pytest_configure(config):
    import calendar
    import rq.utils

    rq.utils.utcnow = lambda: datetime.now(UTC).replace(tzinfo=None)
    rq.utils.current_timestamp = lambda: calendar.timegm(datetime.now(UTC).utctimetuple())
    warnings.filterwarnings(
        "ignore",
        message=r"datetime\.datetime\.utcnow\(\) is deprecated.*",
        category=DeprecationWarning,
        module=r"rq\.utils",
    )
    config.addinivalue_line("markers", "asyncio: async test")
