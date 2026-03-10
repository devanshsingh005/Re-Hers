"""Pytest configuration and shared fixtures."""
import pytest
import os
import asyncio
from typing import Generator
from pathlib import Path
from dotenv import load_dotenv

# Load .env file before any tests run
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=str(env_path))

# Ensure asyncio event loop is available
@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


# pytest markers for test categories
def pytest_configure(config):
    """Register custom pytest markers."""
    config.addinivalue_line(
        "markers", "asyncio: mark test as async (deselect with '-m \"not asyncio\"')"
    )
    config.addinivalue_line(
        "markers", "crash: mark test as worker crash test"
    )
    config.addinivalue_line(
        "markers", "timeout: mark test as timeout test"
    )
    config.addinivalue_line(
        "markers", "offline: mark test as offline workers test"
    )
    config.addinivalue_line(
        "markers", "overflow: mark test as queue overflow test"
    )
    config.addinivalue_line(
        "markers", "chaos: mark test as chaos/stress test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow (takes >30s)"
    )
