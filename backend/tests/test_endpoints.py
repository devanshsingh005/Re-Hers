"""Endpoint and API-behavior tests."""
from __future__ import annotations

import subprocess
from pathlib import Path
from uuid import UUID, uuid4

import jwt
import pytest


ROOT = Path(__file__).resolve().parents[1]


def _grep(pattern: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["grep", "-rn", pattern, "backend/"],
        cwd=ROOT.parent,
        text=True,
        capture_output=True,
        check=False,
    )


def _flatten_strings(value):  # type: ignore[no-untyped-def]
    if isinstance(value, dict):
        for nested in value.values():
            yield from _flatten_strings(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from _flatten_strings(nested)
    elif isinstance(value, str):
        yield value


def _post_file(client, token_header, file_tuple):
    return client.post("/convert", headers=token_header, files={"file": file_tuple})


def test_b01_valid_pdf_upload_accepted(app_client, valid_jwt, auth_header, valid_pdf_file):
    response = _post_file(app_client["client"], auth_header(valid_jwt), valid_pdf_file)
    assert response.status_code in {200, 202}
    assert response.json()["job_id"]


def test_b02_valid_jpeg_upload_accepted(app_client, valid_jwt, auth_header, valid_jpeg_file):
    response = _post_file(app_client["client"], auth_header(valid_jwt), valid_jpeg_file)
    assert response.status_code in {200, 202}
    assert response.json()["job_id"]


def test_b03_html_with_pdf_content_type_rejected(app_client, valid_jwt, auth_header, html_disguised_as_pdf):
    response = _post_file(app_client["client"], auth_header(valid_jwt), html_disguised_as_pdf)
    assert response.status_code == 422


def test_b04_random_bytes_with_pdf_content_type_rejected(app_client, valid_jwt, auth_header, random_bytes_pdf):
    response = _post_file(app_client["client"], auth_header(valid_jwt), random_bytes_pdf)
    assert response.status_code == 422


def test_b05_pdf_magic_bytes_with_jpeg_content_type_rejected(app_client, valid_jwt, auth_header, pdf_magic_with_jpg_extension):
    response = _post_file(app_client["client"], auth_header(valid_jwt), pdf_magic_with_jpg_extension)
    assert response.status_code == 422


def test_b06_jpeg_magic_bytes_with_pdf_content_type_rejected(app_client, valid_jwt, auth_header, jpeg_magic_with_pdf_extension):
    response = _post_file(app_client["client"], auth_header(valid_jwt), jpeg_magic_with_pdf_extension)
    assert response.status_code == 422


def test_b07_empty_file_rejected(app_client, valid_jwt, auth_header, empty_pdf_file):
    response = _post_file(app_client["client"], auth_header(valid_jwt), empty_pdf_file)
    assert response.status_code == 422


def test_b08_oversized_file_rejected(app_client, valid_jwt, auth_header, oversized_pdf_file, monkeypatch):
    monkeypatch.setattr(app_client["main"], "MAX_FILE_SIZE", 64)
    response = _post_file(app_client["client"], auth_header(valid_jwt), oversized_pdf_file)
    assert response.status_code in {413, 422}


def test_b09_truncated_pdf_rejected(app_client, valid_jwt, auth_header, truncated_pdf_file):
    response = _post_file(app_client["client"], auth_header(valid_jwt), truncated_pdf_file)
    assert response.status_code == 422


def test_b10_upload_without_auth_rejected(app_client, valid_pdf_file):
    response = app_client["client"].post("/convert", files={"file": valid_pdf_file})
    assert response.status_code in {401, 403}


def test_c01_no_public_urls_returned_in_api_responses(app_client, valid_jwt, auth_header, valid_pdf_file, fresh_test_user, create_completed_job):
    convert = _post_file(app_client["client"], auth_header(valid_jwt), valid_pdf_file)
    job_id = convert.json()["job_id"]
    app_client["db"].state.jobs[job_id]["status"] = "completed"
    app_client["db"].state.jobs[job_id]["result_url"] = f"{fresh_test_user['id']}/{job_id}/output.json"
    app_client["db"].state.jobs[job_id]["label_status"] = "success"
    create_completed_job(user=fresh_test_user, status="completed")

    responses = [
        convert.json(),
        app_client["client"].get(f"/jobs/{job_id}", headers=auth_header(valid_jwt)).json(),
        app_client["client"].get("/jobs", headers=auth_header(valid_jwt)).json(),
    ]

    for response in responses:
        text = "\n".join(_flatten_strings(response))
        assert ("/object" + "/public/") not in text
        assert ("supabase" + ".co/storage") not in text


def test_c02_result_url_requires_authentication(app_client, valid_jwt, auth_header, create_completed_job):
    job = create_completed_job(status="completed")
    result_url = app_client["client"].get(f"/jobs/{job['id']}", headers=auth_header(valid_jwt)).json()["result_url"]
    response = app_client["client"].get(result_url)
    assert response.status_code in {401, 403}


def test_c03_user_a_cannot_access_user_b_result(app_client, user_factory, auth_header):
    user_a = user_factory("a@example.com")
    user_b = user_factory("b@example.com")
    token_b = jwt.encode({"sub": user_b["id"], "email": user_b["email"], "iat": 1, "exp": 9999999999}, "test-jwt-secret", algorithm="HS256")
    job_id = str(uuid4())
    app_client["state"].jobs[job_id] = {
        "id": job_id,
        "user_id": user_a["id"],
        "pdf_path": f"{user_a['id']}/{job_id}/input.pdf",
        "status": "completed",
        "result_url": f"{user_a['id']}/{job_id}/output.json",
        "error_message": None,
        "label_status": "success",
        "label_warning": None,
        "created_at": "2024-01-01T00:00:00+00:00",
        "updated_at": "2024-01-01T00:00:00+00:00",
    }
    file_id = str(uuid4())
    app_client["state"].sheet_files[file_id] = {
        "id": file_id,
        "user_id": user_a["id"],
        "job_id": job_id,
        "storage_path": f"{user_a['id']}/{job_id}/output.json",
        "file_size_bytes": 2,
        "status": "completed",
        "created_at": "2024-01-01T00:00:00+00:00",
        "updated_at": "2024-01-01T00:00:00+00:00",
    }
    app_client["state"].storage["sheet_data"][f"{user_a['id']}/{job_id}/output.json"] = b"{}"
    response = app_client["client"].get(f"/sheets/{job_id}", headers=auth_header(token_b))
    assert response.status_code in {403, 404}


def test_c04_user_a_cannot_access_user_b_pdf(app_client, user_factory, auth_header, valid_pdf_bytes):
    user_a = user_factory("a@example.com")
    user_b = user_factory("b@example.com")
    token_b = jwt.encode({"sub": user_b["id"], "email": user_b["email"], "iat": 1, "exp": 9999999999}, "test-jwt-secret", algorithm="HS256")
    job_id = str(uuid4())
    app_client["state"].jobs[job_id] = {
        "id": job_id,
        "user_id": user_a["id"],
        "pdf_path": f"{user_a['id']}/{job_id}/input.pdf",
        "status": "completed",
        "result_url": f"{user_a['id']}/{job_id}/output.json",
        "error_message": None,
        "label_status": "success",
        "label_warning": None,
        "created_at": "2024-01-01T00:00:00+00:00",
        "updated_at": "2024-01-01T00:00:00+00:00",
    }
    app_client["state"].storage["pdf_uploads"][f"{user_a['id']}/{job_id}/labeled.pdf"] = valid_pdf_bytes
    response = app_client["client"].get(f"/sheets/{job_id}/pdf", headers=auth_header(token_b))
    assert response.status_code in {403, 404}


def test_c05_signed_urls_expire(app_client, create_completed_job):
    job = create_completed_job()
    signed = app_client["storage"].client.storage.from_("sheet_data").create_signed_url(
        f"{job['user_id']}/{job['id']}/output.json",
        1,
    )["signedURL"]
    assert app_client["storage"].fetch_signed_url_status(signed) == 200
    app_client["state"].current_time += 5
    assert app_client["storage"].fetch_signed_url_status(signed) in {400, 403}


def test_e01_admin_endpoint_rejects_non_admin_user(app_client, valid_jwt, auth_header, monkeypatch):
    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {"some-other-user"})
    for path in ("/admin/orphans/detect", "/admin/orphans/cleanup"):
        response = app_client["client"].request("GET" if path.endswith("detect") else "POST", path, headers=auth_header(valid_jwt))
        assert response.status_code in {401, 403}


def test_e02_admin_endpoint_does_not_leak_exception_text(app_client, valid_jwt, auth_header, monkeypatch, fresh_test_user):
    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {fresh_test_user["id"]})

    async def boom():
        raise RuntimeError("Traceback /tmp/secret public.jobs")

    monkeypatch.setattr(app_client["main"].orphan_detector, "detect_orphans", boom)
    response = app_client["client"].get("/admin/orphans/detect", headers=auth_header(valid_jwt))
    assert response.status_code == 500
    assert "Traceback" not in response.text
    assert "/tmp/" not in response.text
    assert "public.jobs" not in response.text
    assert "Internal server error" in response.text


def test_e03_admin_endpoint_logs_error_server_side(app_client, valid_jwt, auth_header, monkeypatch, caplog, fresh_test_user):
    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {fresh_test_user["id"]})

    async def boom():
        raise RuntimeError("database blew up")

    monkeypatch.setattr(app_client["main"].orphan_detector, "detect_orphans", boom)
    with caplog.at_level("ERROR"):
        app_client["client"].get("/admin/orphans/detect", headers=auth_header(valid_jwt))
    assert "RuntimeError" in caplog.text


def test_f01_user_only_sees_own_jobs(app_client, valid_jwt, auth_header, user_factory, create_completed_job):
    user_b = user_factory("b@example.com")
    create_completed_job()
    other = create_completed_job(user=user_b)
    response = app_client["client"].get("/jobs", headers=auth_header(valid_jwt))
    job_ids = {job["id"] for job in response.json()["jobs"]}
    assert other["id"] not in job_ids


def test_f02_job_list_does_not_return_internal_fields(app_client, valid_jwt, auth_header, create_completed_job):
    create_completed_job(error_message="ValueError: bad secret", label_warning="private path /tmp/file")
    response = app_client["client"].get("/jobs", headers=auth_header(valid_jwt))
    job = response.json()["jobs"][0]
    assert "storage_path" not in job
    assert "pdf_path" not in job
    assert "error_message" not in job
    assert "label_status" not in job
    assert "label_warning" not in job


def test_f03_job_status_error_is_sanitised(app_client, valid_jwt, auth_header, create_completed_job):
    job = create_completed_job(
        status="failed",
        error_message="ValueError: backend exploded at /tmp/private public.jobs",
        label_status="failed",
        label_warning="private path /tmp/file",
    )
    response = app_client["client"].get(f"/sheets/{job['id']}/status", headers=auth_header(valid_jwt))
    body = response.json()
    assert body["error"] == "Processing failed. Please try again or contact support."
    assert "ValueError" not in response.text
    assert "/tmp/" not in response.text


def test_f04_job_id_enumeration_blocked(app_client, user_factory, auth_header, create_completed_job):
    user_b = user_factory("b@example.com")
    token_b = jwt.encode({"sub": user_b["id"], "email": user_b["email"], "iat": 1, "exp": 9999999999}, "test-jwt-secret", algorithm="HS256")
    job = create_completed_job()
    guesses = [str(UUID(job["id"]).int + 1), str(uuid4()), job["id"]]
    for guess in guesses:
        response = app_client["client"].get(f"/jobs/{guess}", headers=auth_header(token_b))
        assert response.status_code in {403, 404}


@pytest.mark.parametrize("status", ["pending", "processing", "completed", "failed"])
def test_job_status_endpoint_covers_each_status(app_client, valid_jwt, auth_header, create_completed_job, status):
    job = create_completed_job(
        status=status,
        error_message="hidden detail" if status == "failed" else None,
        label_status="success" if status == "completed" else None,
    )
    response = app_client["client"].get(f"/jobs/{job['id']}", headers=auth_header(valid_jwt))
    body = response.json()
    assert response.status_code == 200
    assert body["status"] == status
    if status == "completed":
        assert body["result_url"] == f"/sheets/{job['id']}"
        assert body["pdf_url"] == f"/sheets/{job['id']}/pdf"
    if status == "failed":
        assert body["error"] == "Processing failed. Please try again or contact support."


def test_job_status_endpoint_missing_job_returns_404(app_client, valid_jwt, auth_header):
    response = app_client["client"].get(f"/jobs/{uuid4()}", headers=auth_header(valid_jwt))
    assert response.status_code == 404


def test_admin_endpoints_with_valid_admin_credentials(app_client, valid_jwt, auth_header, monkeypatch, fresh_test_user):
    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {fresh_test_user["id"]})

    async def detect():
        return {"orphaned_storage_files": [], "orphaned_db_records": [], "is_healthy": True}

    async def cleanup(dry_run: bool = True):
        return {"dry_run": dry_run, "actions": {"deleted_storage_files": [], "deleted_db_records": [], "marked_orphaned": []}}

    monkeypatch.setattr(app_client["main"].orphan_detector, "detect_orphans", detect)
    monkeypatch.setattr(app_client["main"].orphan_detector, "cleanup_orphans", cleanup)

    detect_response = app_client["client"].get("/admin/orphans/detect", headers=auth_header(valid_jwt))
    cleanup_response = app_client["client"].post("/admin/orphans/cleanup", headers=auth_header(valid_jwt))
    assert detect_response.status_code == 200
    assert cleanup_response.status_code == 200
    assert detect_response.json()["is_healthy"] is True
    assert cleanup_response.json()["dry_run"] is True


def test_admin_cleanup_returns_sanitised_error_response(app_client, valid_jwt, auth_header, monkeypatch, fresh_test_user):
    monkeypatch.setattr("app.config.ADMIN_USER_IDS", {fresh_test_user["id"]})

    async def boom(dry_run: bool = True):
        raise RuntimeError("Traceback /tmp/secret backend.jobs")

    monkeypatch.setattr(app_client["main"].orphan_detector, "cleanup_orphans", boom)
    response = app_client["client"].post("/admin/orphans/cleanup", headers=auth_header(valid_jwt))
    assert response.status_code == 500
    assert "Traceback" not in response.text
    assert "/tmp/" not in response.text
    assert "backend.jobs" not in response.text
    assert "Internal server error" in response.text
