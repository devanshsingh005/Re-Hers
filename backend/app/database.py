"""Database operations for sheet_files and jobs tables."""
import datetime
from supabase import create_client, Client
from typing import Optional, List, Dict, Any
from uuid import UUID
import json


class DatabaseClient:
    """Handles all database operations with user isolation."""
    
    def __init__(self, supabase_url: str, supabase_key: str):
        """Initialize Supabase client."""
        self.client: Client = create_client(supabase_url, supabase_key)
    
    # ==================== JOBS TABLE ====================
    
    async def create_job(
        self,
        job_id: str,
        user_id: str,
        pdf_path: str,
        status: str = "pending"
    ) -> Dict[str, Any]:
        """Create a new job linked to user."""
        response = self.client.table("jobs").insert({
            "id": job_id,
            "user_id": user_id,
            "pdf_path": pdf_path,
            "status": status
        }).execute()
        
        if response.data:
            return response.data[0]
        raise Exception("Failed to create job")
    
    async def get_job(self, job_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        """Get job only if owned by user (RLS enforced)."""
        response = self.client.table("jobs").select("*").eq(
            "id", job_id
        ).eq(
            "user_id", user_id
        ).execute()
        
        return response.data[0] if response.data else None
    
    async def update_job_status(
        self,
        job_id: str,
        user_id: str,
        status: str,
        result_url: Optional[str] = None,
        error_message: Optional[str] = None,
        label_status: Optional[str] = None,
        label_warning: Optional[str] = None
    ) -> Dict[str, Any]:
        """Update job status (only if owned by user)."""
        update_data = {"status": status, "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        
        if result_url:
            update_data["result_url"] = result_url
        if error_message:
            update_data["error_message"] = error_message
        if label_status:
            update_data["label_status"] = label_status
        if label_warning:
            update_data["label_warning"] = label_warning
        
        response = self.client.table("jobs").update(
            update_data
        ).eq("id", job_id).eq("user_id", user_id).execute()
        
        if response.data:
            return response.data[0]
        raise Exception("Job not found or unauthorized")
    
    async def get_user_jobs(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get all jobs for a user with pagination."""
        response = self.client.table("jobs").select(
            "id, user_id, status, created_at, pdf_path, result_url, label_status, label_warning"
        ).eq(
            "user_id", user_id
        ).order("created_at", desc=True).range(offset, offset + limit).execute()
        
        return response.data if response.data else []

    async def get_user_active_job_count(self, user_id: str) -> int:
        """Count non-terminal jobs for a user (pending / queued / processing).

        Used by /convert to enforce MAX_CONCURRENT_JOBS_PER_USER before
        accepting a new upload.  Fetches only the 'id' column to minimise
        wire payload — no full row scan needed.
        """
        response = (
            self.client.table("jobs")
            .select("id")
            .eq("user_id", user_id)
            .in_("status", ["pending", "queued", "processing"])
            .execute()
        )
        return len(response.data) if response.data else 0

    # ==================== SHEET_FILES TABLE ====================
    
    async def create_sheet_file(
        self,
        file_id: str,
        user_id: str,
        job_id: str,
        storage_path: str,
        file_size_bytes: Optional[int] = None,
        status: str = "processing"
    ) -> Dict[str, Any]:
        """Create or update sheet_file record linking file to user.
        
        Uses upsert on (user_id, job_id) so re-processing a job overwrites the
        existing record rather than failing with a unique-constraint violation.
        """
        response = self.client.table("sheet_files").upsert({
            "id": file_id,
            "user_id": user_id,
            "job_id": job_id,
            "storage_path": storage_path,
            "file_size_bytes": file_size_bytes,
            "status": status
        }, on_conflict="user_id,job_id").execute()
        
        if response.data:
            return response.data[0]
        raise Exception("Failed to create sheet_file record")
    
    async def get_sheet_file(
        self,
        file_id: str,
        user_id: str
    ) -> Optional[Dict[str, Any]]:
        """Get sheet_file only if owned by user."""
        response = self.client.table("sheet_files").select("*").eq(
            "id", file_id
        ).eq(
            "user_id", user_id
        ).execute()
        
        return response.data[0] if response.data else None
    
    async def get_sheet_file_by_job(
        self,
        job_id: str,
        user_id: str
    ) -> Optional[Dict[str, Any]]:
        """Get sheet_file by job_id (with user validation)."""
        response = self.client.table("sheet_files").select("*").eq(
            "job_id", job_id
        ).eq(
            "user_id", user_id
        ).execute()
        
        return response.data[0] if response.data else None
    
    async def get_user_sheet_files(
        self,
        user_id: str,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """Get all sheet_files for a user."""
        query = self.client.table("sheet_files").select("*").eq("user_id", user_id)
        
        if status:
            query = query.eq("status", status)
        
        response = query.order("created_at", desc=True).range(offset, offset + limit).execute()
        
        return response.data if response.data else []
    
    async def update_sheet_file_status(
        self,
        file_id: str,
        user_id: str,
        status: str
    ) -> Dict[str, Any]:
        """Update sheet_file status (with user validation)."""
        response = self.client.table("sheet_files").update({
            "status": status,
            "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
        }).eq("id", file_id).eq("user_id", user_id).execute()
        
        if response.data:
            return response.data[0]
        raise Exception("Sheet file not found or unauthorized")
    
    async def delete_sheet_file(
        self,
        file_id: str,
        user_id: str
    ) -> bool:
        """Delete sheet_file (with user validation)."""
        response = self.client.table("sheet_files").delete().eq(
            "id", file_id
        ).eq(
            "user_id", user_id
        ).execute()
        
        # If no rows affected, file not found or unauthorized
        return len(response.data) > 0 if response.data else False
    
    # ==================== ORPHAN DETECTION ====================
    
    async def get_all_sheet_files(self) -> List[Dict[str, Any]]:
        """Get ALL sheet_files (admin only - for orphan detection)."""
        response = self.client.table("sheet_files").select("*").execute()
        return response.data if response.data else []
    
    async def get_orphaned_db_records(self) -> List[Dict[str, Any]]:
        """Get sheet_files with 'orphaned' status or missing storage files."""
        response = self.client.table("sheet_files").select("*").eq(
            "status", "orphaned"
        ).execute()
        return response.data if response.data else []
    
    async def mark_sheet_file_orphaned(self, file_id: str) -> Dict[str, Any]:
        """Mark sheet_file as orphaned (for cleanup tracking)."""
        response = self.client.table("sheet_files").update({
            "status": "orphaned",
            "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
        }).eq("id", file_id).execute()
        
        if response.data:
            return response.data[0]
        raise Exception("Failed to mark file as orphaned")
