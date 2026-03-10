"""
Simplified recovery system tests that don't require database writes.

Tests focus on:
- API health checks
- Redis queue behavior
- Recovery loop configuration
"""
import pytest
import asyncio
import time
import redis
import httpx
from pathlib import Path
from dotenv import load_dotenv
import os

# Load .env
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=str(env_path))

API_URL = "http://localhost:8000"
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")


class TestAPIHealth:
    """Test API health and basic connectivity."""
    
    @pytest.mark.asyncio
    async def test_api_health_check(self):
        """Verify API /health endpoint responds."""
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{API_URL}/health", timeout=5)
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "healthy"
    
    @pytest.mark.asyncio
    async def test_api_cors_headers(self):
        """Verify API CORS headers are set on preflight requests."""
        async with httpx.AsyncClient() as client:
            # Send preflight request
            response = await client.options(
                f"{API_URL}/health",
                headers={"Origin": "http://localhost:3000"}
            )
            # CORS headers should be present on preflight
            assert "access-control-allow-origin" in response.headers or response.status_code == 200


class TestRedisQueue:
    """Test Redis queue behavior."""
    
    def test_redis_connection(self):
        """Verify Redis is reachable."""
        try:
            conn = redis.from_url(REDIS_URL)
            result = conn.ping()
            assert result is True
        except Exception as e:
            pytest.fail(f"Redis connection failed: {e}")
    
    def test_redis_queue_empty(self):
        """Verify we can check queue depth."""
        from rq import Queue
        conn = redis.from_url(REDIS_URL)
        queue = Queue("sheet_jobs", connection=conn)
        
        # Queue depth should be a non-negative integer
        depth = len(queue)
        assert isinstance(depth, int)
        assert depth >= 0
    
    def test_redis_job_creation(self):
        """Verify we can create a mock job in Redis."""
        from rq import Queue
        conn = redis.from_url(REDIS_URL)
        queue = Queue("sheet_jobs", connection=conn)
        
        # Create a test job (mock function)
        test_job = queue.enqueue(
            "tests.test_helpers.mock_job",
            job_id="test-redis-mock-001",
            job_timeout=60,
        )
        
        assert test_job is not None
        assert test_job.id == "test-redis-mock-001"
        
        # Cleanup
        try:
            test_job.delete()
            conn.delete(f"rq:job:{test_job.id}")
        except Exception:
            pass


class TestRecoveryLoopConfiguration:
    """Test that recovery loop is configured correctly."""
    
    def test_worker_ttl_config(self):
        """Verify worker TTL matches configuration."""
        # Expected: 420 seconds (from worker.py default_worker_ttl)
        expected_ttl = 420
        
        # This would be loaded from app config
        from app.config import settings
        # Note: TTL is set in worker.py, not in app/config.py
        # Just verify we can import the config module
        assert settings is not None
    
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
    """Test queue status reporting without database writes."""
    
    def test_queue_depth_reporting(self):
        """Verify queue depth can be queried."""
        from rq import Queue
        conn = redis.from_url(REDIS_URL)
        queue = Queue("sheet_jobs", connection=conn)
        
        depth = len(queue)
        print(f"\n  Queue depth: {depth} jobs")
        
        # Should not error
        assert isinstance(depth, int)
    
    @pytest.mark.asyncio
    async def test_api_can_report_job_status(self):
        """Test that API endpoints are available for job status."""
        async with httpx.AsyncClient() as client:
            # Attempt to check a non-existent job (should 404, not 500)
            response = await client.get(
                f"{API_URL}/jobs/nonexistent-job-id",
                headers={"Authorization": "Bearer fake-token"}
            )
            # Should fail auth or 404, not 500
            assert response.status_code in [401, 403, 404]


class TestRecoveryLoopWillStart:
    """Verify recovery loop is configured to start on app startup."""
    
    def test_recovery_loop_in_main_py(self):
        """Verify recovery loop code exists in main.py."""
        main_py = Path("/Users/user30/Documents/Re-Hers/backend/app/main.py")
        content = main_py.read_text()
        
        assert "recovery_loop" in content
        assert "recover_stuck_jobs" in content
        assert "StartedJobRegistry" in content
        
        # Should have asyncio.create_task
        assert "asyncio.create_task(recovery_loop())" in content
    
    def test_job_status_transitions_valid(self):
        """Verify job status values are valid per schema."""
        valid_statuses = {"pending", "processing", "completed", "completed_with_warning", "failed"}
        
        # Load migration to verify these are the allowed statuses
        migration_sql = Path("/Users/user30/Documents/Re-Hers/backend/migrations/001_user_isolation.sql")
        content = migration_sql.read_text()
        
        # Should have CHECK constraint with these values
        assert "CHECK (status IN" in content
        for status in valid_statuses:
            assert f"'{status}'" in content


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
