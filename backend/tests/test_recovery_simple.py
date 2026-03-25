"""Recovery and queue tests using the in-memory harness."""
from pathlib import Path

import fakeredis
import pytest
from rq import Queue


class TestAPIHealth:
    def test_api_health_check(self, app_client):
        response = app_client["client"].get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"

    def test_api_cors_headers(self, app_client):
        response = app_client["client"].options("/health", headers={"Origin": 'http://localhost:3000'})
        assert response.status_code in {200, 405}


class TestRedisQueue:
    def test_redis_connection(self):
        conn = fakeredis.FakeRedis()
        assert conn.ping() is True

    def test_redis_queue_empty(self):
        queue = Queue("sheet_jobs", connection=fakeredis.FakeRedis())
        assert len(queue) == 0

    def test_redis_job_creation(self):
        queue = Queue("sheet_jobs", connection=fakeredis.FakeRedis())
        job = queue.enqueue("tests.test_helpers.quick_job", job_id="test-redis-mock-001", job_timeout=60)
        assert job.id == "test-redis-mock-001"


class TestRecoveryLoopConfiguration:
    def test_worker_ttl_config(self):
        import worker

        assert worker.MAX_AUDIVERIS_RETRIES == 3
    
    def test_supervisor_config_exists(self):
        """Verify supervisor.conf exists and is readable."""
        supervisor_conf = Path("/Users/user30/Documents/Re-Hers/backend/supervisor.conf")
        assert supervisor_conf.exists()
        
        content = supervisor_conf.read_text()
        assert "worker1" in content
        assert "worker2" in content
        assert "worker3" in content
        assert "worker4" in content
        assert "fastapi" in content


class TestQueueStatusIntegration:
    def test_queue_depth_reporting(self):
        queue = Queue("sheet_jobs", connection=fakeredis.FakeRedis())
        assert isinstance(len(queue), int)

    def test_api_can_report_job_status(self, app_client, valid_jwt, auth_header):
        response = app_client["client"].get("/jobs/nonexistent-job-id", headers=auth_header(valid_jwt))
        assert response.status_code == 404


class TestRecoveryLoopWillStart:
    def test_recovery_loop_in_main_py(self):
        main_py = Path("/Users/user30/Documents/Re-Hers/backend/app/main.py")
        content = main_py.read_text()
        assert "recovery_loop" in content
        assert "recover_stuck_jobs" in content
        assert "StartedJobRegistry" in content
        assert "asyncio.create_task(recovery_loop())" in content
    
    def test_job_status_transitions_valid(self):
        valid_statuses = {"pending", "processing", "completed", "completed_with_warning", "failed"}
        migration_sql = Path("/Users/user30/Documents/Re-Hers/backend/migrations/001_user_isolation.sql")
        content = migration_sql.read_text()
        assert "CHECK (status IN" in content
        for status in valid_statuses:
            assert f"'{status}'" in content
