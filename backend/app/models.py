"""In-memory job store for tracking job status."""
from dataclasses import dataclass, field
from typing import Optional, Dict
from enum import Enum
import threading


class JobStatus(str, Enum):
    """Job status enumeration."""
    QUEUED = "queued"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class Job:
    """Job model for tracking conversion tasks."""
    job_id: str
    status: JobStatus = JobStatus.QUEUED
    input_pdf_path: str = ""
    output_url: Optional[str] = None
    error: Optional[str] = None


class JobStore:
    """Thread-safe in-memory job store."""
    
    def __init__(self):
        self._jobs: Dict[str, Job] = {}
        self._lock = threading.Lock()
    
    def create_job(self, job_id: str, input_pdf_path: str) -> Job:
        """Create a new job record."""
        with self._lock:
            job = Job(job_id=job_id, input_pdf_path=input_pdf_path)
            self._jobs[job_id] = job
            return job
    
    def get_job(self, job_id: str) -> Optional[Job]:
        """Get a job by ID."""
        with self._lock:
            return self._jobs.get(job_id)
    
    def update_job(self, job_id: str, **kwargs) -> Optional[Job]:
        """Update job fields."""
        with self._lock:
            job = self._jobs.get(job_id)
            if job:
                for key, value in kwargs.items():
                    if hasattr(job, key):
                        setattr(job, key, value)
            return job
    
    def get_all_jobs(self) -> Dict[str, Job]:
        """Get all jobs (for debugging)."""
        with self._lock:
            return self._jobs.copy()


# Global job store instance
job_store = JobStore()
