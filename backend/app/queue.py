"""FIFO queue for job processing."""
import queue
import threading
from typing import Optional


class JobQueue:
    """Thread-safe FIFO queue for jobs."""
    
    def __init__(self):
        self._queue = queue.Queue()
        self._lock = threading.Lock()
    
    def enqueue(self, job_id: str) -> None:
        """Add a job ID to the queue."""
        self._queue.put(job_id)
    
    def dequeue(self, timeout: Optional[float] = None) -> Optional[str]:
        """Remove and return a job ID from the queue.
        
        Args:
            timeout: Optional timeout in seconds. If None, blocks indefinitely.
        
        Returns:
            Job ID or None if timeout occurs.
        """
        try:
            return self._queue.get(timeout=timeout)
        except queue.Empty:
            return None
    
    def size(self) -> int:
        """Get the current queue size."""
        return self._queue.qsize()
    
    def empty(self) -> bool:
        """Check if the queue is empty."""
        return self._queue.empty()


# Global queue instance
job_queue = JobQueue()
