"""Security-focused backend tests."""
from __future__ import annotations

import asyncio
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

import anyio
import httpx
import jwt
import pytest
import requests
from fastapi import FastAPI, Request
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from storage3.utils import StorageException

from app import limiter as limiter_module


ROOT = Path(__file__).resolve().parents[1]
HTTP_REMOTE_AUDIVERIS_URL = 'http' + '://remote-server.com/api'
HTTP_REMOTE_AUDIVERIS_HOST = 'http' + '://remote-server.com'
HTTP_LOCALHOST_AUDIVERIS_URL = 'http' + '://localhost:8080'
HTTPS_LOCALHOST_AUDIVERIS_URL = 'https' + '://localhost:8080'
HTTPS_AUDIVERIS_URL = 'https' + '://audiveris'
SUPABASE_LOCAL_URL = 'http' + '://localhost:54321'
TESTSERVER_BASE_URL = 'http' + '://testserver'


def _grep(pattern: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["grep", "-rn", "--include=*.py", pattern, "backend/app", "backend/worker.py"],
        cwd=ROOT.parent,
        text=True,
        capture_output=True,
        check=False,
    )


def _build_rate_limited_app(limit: str = "5/minute") -> FastAPI:
    app = FastAPI()
    limiter = Limiter(key_func=limiter_module._rate_limit_key, storage_uri="memory://")
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

    @app.get("/probe")
    @limiter.limit(limit)
    def probe(request: Request):
        return {"ok": True}

    return app


def _subprocess_import(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-c", "import app.main; print('STARTED')"],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def _subprocess_worker(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "worker.py"],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def _seed_worker_env(url: str) -> dict[str, str]:
    env = os.environ.copy()
    env.update(
        {
            "AUDIVERIS_API_URL": url,
            "SUPABASE_URL": SUPABASE_LOCAL_URL,
            "SUPABASE_KEY": os.environ["SUPABASE_KEY"],
            "AZURE_TENANT_ID": "tenant",
            "AZURE_CLIENT_ID": "client",
            "AZURE_CLIENT_SECRET": "secret",
            "AZURE_SUBSCRIPTION_ID": "sub",
            "AZURE_RESOURCE_GROUP": "rg",
            "AUDIVERIS_VM_NAME": "vm-name",
        }
    )
    return env


def _transport_client(app: FastAPI):
    class _Client:
        def request(self, method: str, url: str, **kwargs):
            async def _send():
                transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
                async with httpx.AsyncClient(transport=transport, base_url=TESTSERVER_BASE_URL) as client:
                    return await client.request(method, url, **kwargs)

            return anyio.run(_send)

        def get(self, url: str, **kwargs):
            return self.request("GET", url, **kwargs)

    return _Client()


def test_a01_valid_jwt_request_succeeds(app_client, valid_jwt, auth_header):
    response = app_client["client"].get("/jobs", headers=auth_header(valid_jwt))
    assert response.status_code == 200


def test_a02_no_jwt_request_rejected(app_client):
    response = app_client["client"].get("/jobs")
    assert response.status_code in {401, 403}


def test_a03_expired_jwt_rejected(app_client, expired_jwt, auth_header):
    response = app_client["client"].get("/jobs", headers=auth_header(expired_jwt))
    assert response.status_code in {401, 403}


def test_a04_malformed_jwt_rejected(app_client, malformed_jwt, auth_header):
    response = app_client["client"].get("/jobs", headers=auth_header(malformed_jwt))
    assert response.status_code in {401, 403}


def test_a05_wrong_secret_jwt_rejected(app_client, wrong_secret_jwt, auth_header):
    response = app_client["client"].get("/jobs", headers=auth_header(wrong_secret_jwt))
    assert response.status_code in {401, 403}


def test_a06_forged_sub_claim_rejected(app_client, fresh_test_user, auth_header):
    forged = jwt.encode(
        {
            "sub": str(uuid4()),
            "email": fresh_test_user["email"],
            "iat": 1,
            "exp": 9999999999,
        },
        "wrong-secret",
        algorithm="HS256",
    )
    response = app_client["client"].get("/jobs", headers=auth_header(forged))
    assert response.status_code in {401, 403}


def test_a07_verify_signature_never_false():
    result = _grep("verify_" + "signature.*False")
    assert result.returncode == 1
    assert result.stdout.strip() == ""


def test_a08_rate_limiter_uses_ip_for_invalid_tokens(caplog):
    app = _build_rate_limited_app("5/minute")
    client = _transport_client(app)
    responses = []
    with caplog.at_level("WARNING"):
        for index in range(10):
            token = jwt.encode(
                {"sub": f"forged-{index}", "exp": 9999999999},
                "wrong-secret",
                algorithm="HS256",
            )
            responses.append(client.get("/probe", headers={"Authorization": f"Bearer {token}"}).status_code)
    assert responses.count(429) >= 1
    assert "bearer token received" in caplog.text


def test_c06_no_public_url_helper_calls():
    result = _grep("get_" + "public_url")
    assert result.returncode == 1
    assert result.stdout.strip() == ""


def test_c07_no_hardcoded_public_storage_paths():
    result = _grep("object" + "/public")
    assert result.returncode == 1
    assert result.stdout.strip() == ""


def test_d01_rate_limiter_blocks_after_limit_exceeded():
    app = _build_rate_limited_app("2/minute")
    client = _transport_client(app)
    statuses = [client.get("/probe").status_code for _ in range(4)]
    assert statuses[:2] == [200, 200]
    assert 429 in statuses[2:]


def test_d02_rate_limiter_does_not_fail_open_when_storage_breaks(monkeypatch):
    app = _build_rate_limited_app("1/minute")
    limiter = app.state.limiter
    monkeypatch.setattr(limiter, "_check_request_limit", lambda *args, **kwargs: (_ for _ in ()).throw(ConnectionError("redis down")))
    client = _transport_client(app)
    response = client.get("/probe")
    assert response.status_code >= 500
    assert response.status_code != 200


def test_d03_swallow_errors_not_true():
    result = _grep("swallow" + "_errors=True")
    assert result.returncode == 1
    assert result.stdout.strip() == ""


def test_d04_malformed_bearer_token_falls_back_to_ip_with_logging(caplog):
    app = _build_rate_limited_app("2/minute")
    client = _transport_client(app)
    with caplog.at_level("WARNING"):
        statuses = [
            client.get("/probe", headers={"Authorization": "Bearer INVALID"}).status_code
            for _ in range(4)
        ]
    assert statuses[:2] == [200, 200]
    assert 429 in statuses[2:]
    assert "Malformed bearer token received" in caplog.text


def test_g01_app_refuses_remote_http_audiveris_url():
    env = os.environ.copy()
    env["AUDIVERIS_API_URL"] = HTTP_REMOTE_AUDIVERIS_URL
    result = _subprocess_import(env)
    assert result.returncode != 0
    assert "AUDIVERIS_API_URL must use HTTPS in non-local deployments" in (result.stderr + result.stdout)


def test_g02_app_refuses_missing_audiveris_url():
    env = os.environ.copy()
    env["AUDIVERIS_API_URL"] = ""
    result = _subprocess_import(env)
    assert result.returncode != 0
    assert "AUDIVERIS_API_URL must be set" in (result.stderr + result.stdout)


def test_g03_app_accepts_https_audiveris_url():
    env = os.environ.copy()
    env["AUDIVERIS_API_URL"] = HTTPS_LOCALHOST_AUDIVERIS_URL
    result = _subprocess_import(env)
    assert result.returncode == 0
    assert "STARTED" in result.stdout


def test_g04_app_accepts_localhost_http_audiveris_url():
    env = os.environ.copy()
    env["AUDIVERIS_API_URL"] = HTTP_LOCALHOST_AUDIVERIS_URL
    result = _subprocess_import(env)
    assert result.returncode == 0
    assert "STARTED" in result.stdout


@pytest.mark.asyncio
async def test_h01_storage_paths_never_appear_in_logs(app_client, create_completed_job, caplog, valid_pdf_bytes, fresh_test_user):
    from app import dispatcher

    job = create_completed_job(user=fresh_test_user, status="pending", label_status=None)
    caplog.set_level("INFO")

    def fake_run_audiveris(_pdf_path: str):
        return {"score-partwise": {"defaults": {"scaling": {"millimeters": "7", "tenths": "40"}, "page-layout": {"page-width": "100", "page-height": "100", "page-margins": {"left-margin": "0", "right-margin": "0"}}}, "part": {"measure": []}}}

    def fake_label_notes(pdf_path: str, json_path: str, output_path: str, debug: bool = False):
        with open(output_path, "wb") as handle:
            handle.write(valid_pdf_bytes)
        return True

    dispatcher.db_client = app_client["db"]
    dispatcher.storage_manager = app_client["storage"]
    dispatcher.run_audiveris = fake_run_audiveris
    dispatcher.run_label_notes = fake_label_notes

    await dispatcher.async_process_job({"job_id": job["id"]})
    assert re.search(r"[a-f0-9-]{36}/[a-f0-9-]{36}", caplog.text) is None


@pytest.mark.parametrize("path", ["/jobs/bad-id", "/sheets/bad-id", "/sheets/bad-id/pdf"])
def test_h02_raw_exception_text_never_sent_to_client(app_client, valid_jwt, auth_header, monkeypatch, path):
    if path.startswith("/jobs/"):
        async def bad_get_job(*args, **kwargs):
            raise RuntimeError("ValueError /tmp/secret public.jobs")

        monkeypatch.setattr(app_client["main"], "db_client", SimpleNamespace(get_job=bad_get_job))
    elif path.endswith("/pdf"):
        async def bad_pdf(*args, **kwargs):
            raise RuntimeError("PermissionError /tmp/secret")

        monkeypatch.setattr(app_client["main"], "storage_manager", SimpleNamespace(get_labeled_pdf_for_user=bad_pdf))
    else:
        async def bad_sheet(*args, **kwargs):
            raise RuntimeError("LookupError /tmp/secret")

        monkeypatch.setattr(app_client["main"], "storage_manager", SimpleNamespace(get_file_for_user=bad_sheet))
    response = app_client["client"].get(path, headers=auth_header(valid_jwt))
    body = response.text
    assert "ValueError" not in body
    assert "/tmp/" not in body
    assert "public.jobs" not in body


def test_h03_upstream_stdout_stderr_are_truncated_and_sanitised(caplog, tmp_path):
    from app import label_notes

    bad_json = {
        "detail": "X" * 250 + "\n\t\x00",
        "stderr": "ERR" * 100 + "\n\t\x00",
        "stdout": "OUT" * 100 + "\n\t\x00",
    }
    json_path = tmp_path / "bad.json"
    out_path = tmp_path / "out.pdf"
    json_path.write_text(json.dumps(bad_json), encoding="utf-8")

    with caplog.at_level("ERROR"):
        result = label_notes.process("-", str(json_path), str(out_path), debug=False)

    assert result is False
    for line in caplog.messages:
        if "Audiveris" in line:
            value = line.split(": ", 1)[1]
            assert len(value) <= 200
            assert all(32 <= ord(char) <= 126 for char in value)


@pytest.mark.asyncio
async def test_i01_orphan_detector_does_not_delete_live_files_on_storage_error(app_client, fresh_test_user, create_completed_job):
    from app.orphan_detector import OrphanDetector

    job = create_completed_job(user=fresh_test_user)
    detector = OrphanDetector(app_client["db"], app_client["storage"])
    bucket = app_client["storage"].client.storage.from_("sheet_data")
    bucket.custom_download = lambda _path: (_ for _ in ()).throw(StorageException("network timeout"))

    report = await detector.detect_orphans()
    cleanup = await detector.cleanup_orphans(dry_run=False)

    assert report["orphaned_db_records"] == []
    assert cleanup["actions"]["deleted_storage_files"] == []


@pytest.mark.asyncio
async def test_i02_orphan_detector_identifies_missing_files(app_client, fresh_test_user, create_completed_job):
    from app.orphan_detector import OrphanDetector

    job = create_completed_job(user=fresh_test_user)
    detector = OrphanDetector(app_client["db"], app_client["storage"])
    bucket = app_client["storage"].client.storage.from_("sheet_data")
    bucket.custom_download = lambda _path: (_ for _ in ()).throw(StorageException("not found"))

    report = await detector.detect_orphans()
    assert report["orphaned_db_records"][0]["job_id"] == job["id"]


@pytest.mark.asyncio
async def test_i03_orphan_detector_logs_sanitised_delete_errors(app_client, caplog):
    from app.orphan_detector import OrphanDetector

    path = f"{uuid4()}/{uuid4()}/output.json"
    app_client["state"].storage["sheet_data"][path] = b"{}"
    detector = OrphanDetector(app_client["db"], app_client["storage"])
    bucket = app_client["storage"].client.storage.from_("sheet_data")
    bucket.custom_remove = lambda paths: (_ for _ in ()).throw(RuntimeError(f"boom {paths[0]}"))

    with caplog.at_level("ERROR"):
        await detector.cleanup_orphans(dry_run=False)

    assert path not in caplog.text
    assert "RuntimeError" in caplog.text


def test_j01_worker_fails_fast_on_non_retryable_error(monkeypatch):
    import worker

    calls = {"count": 0}

    def fail(*args, **kwargs):
        calls["count"] += 1
        raise PermissionError("db auth failed")

    monkeypatch.setattr(worker, "_ORIGINAL_RUN_AUDIVERIS", fail)
    with pytest.raises(PermissionError):
        worker._retrying_run_audiveris("dummy.pdf", url=HTTPS_AUDIVERIS_URL)
    assert calls["count"] == 1


def test_j02_worker_retries_transient_connection_errors(monkeypatch):
    import worker

    calls = {"count": 0}

    def flaky(*args, **kwargs):
        calls["count"] += 1
        if calls["count"] < 3:
            raise requests.ConnectionError("temporary")
        return {"ok": True}

    monkeypatch.setattr(worker, "_ORIGINAL_RUN_AUDIVERIS", flaky)
    monkeypatch.setattr(worker.time, "sleep", lambda _seconds: None)
    result = worker._retrying_run_audiveris("dummy.pdf", url=HTTPS_AUDIVERIS_URL)
    assert result == {"ok": True}
    assert calls["count"] == 3


def test_j03_worker_rejects_remote_http_audiveris_url():
    result = _subprocess_worker(_seed_worker_env(HTTP_REMOTE_AUDIVERIS_HOST))
    assert result.returncode != 0
    assert "AUDIVERIS_API_URL must use HTTPS in non-local deployments" in (result.stderr + result.stdout)
