"""Supabase storage integration for storing job outputs with user isolation."""
import json
import logging
import uuid
from typing import Dict, Any, Optional
from supabase import create_client, Client
from storage3.utils import StorageException
from app.config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_BUCKET
from app.database import DatabaseClient

logger = logging.getLogger(__name__)
HTTP_PREFIX = 'http' + '://'
HTTPS_PREFIX = 'https' + '://'


class StorageManager:
    """Manages file uploads/downloads with user isolation and DB linkage."""
    
    def __init__(self, supabase_url: str, supabase_key: str, db_client: DatabaseClient):
        """Initialize storage manager."""
        self.client: Client = create_client(supabase_url, supabase_key)
        self.db = db_client
        self.bucket = SUPABASE_BUCKET
    
    def _is_valid_uuid(self, value: str) -> bool:
        """Validate UUID format.
        
        Args:
            value: String to validate as UUID
        
        Returns:
            True if valid UUID, False otherwise
        """
        try:
            uuid.UUID(str(value))
            return True
        except (ValueError, AttributeError):
            return False

    def _extract_signed_url(self, signed_result: Any) -> str:
        """Normalize signed URL responses from the storage client."""
        if isinstance(signed_result, str):
            return signed_result
        if isinstance(signed_result, dict):
            signed_url = signed_result.get("signedURL") or signed_result.get("signedUrl")
            if signed_url:
                if signed_url.startswith(HTTP_PREFIX) or signed_url.startswith(HTTPS_PREFIX):
                    return signed_url
                return f"{SUPABASE_URL.rstrip('/')}/storage/v1{signed_url}"
        raise ValueError("Signed URL was not returned by storage client")
    
    async def upload_json(
        self,
        user_id: str,
        job_id: str,
        json_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Upload JSON and create DB record with user linkage.
        
        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
            json_data: The JSON data to store
        
        Returns:
            Dictionary with file_id, storage_path, and public_url
        
        Raises:
            ValueError: If user_id is invalid
            Exception: If upload fails
        """
        try:
            # Validate user_id format
            if not self._is_valid_uuid(user_id):
                raise ValueError(f"Invalid user_id: {user_id}")
            
            # Create user-scoped storage path
            file_id = str(uuid.uuid4())
            storage_path = f"{user_id}/{job_id}/output.json"
            
            # Convert JSON to string
            json_str = json.dumps(json_data, indent=2)
            json_bytes = json_str.encode('utf-8')
            
            # Upload to Supabase Storage
            self.client.storage.from_(self.bucket).upload(
                path=storage_path,
                file=json_bytes,
                file_options={"content-type": "application/json", "x-upsert": "true"}
            )
            
            # Get signed URL
            public_url = self._extract_signed_url(
                self.client.storage.from_(self.bucket).create_signed_url(storage_path, 3600)
            )
            
            # Create DB record linking file to user
            db_record = await self.db.create_sheet_file(
                file_id=file_id,
                user_id=user_id,
                job_id=job_id,
                storage_path=storage_path,
                file_size_bytes=len(json_bytes),
                status="completed"
            )
            
            return {
                "success": True,
                "file_id": file_id,
                "storage_path": storage_path,
                "public_url": public_url,
                "user_id": user_id
            }
        
        except Exception as e:
            raise Exception(f"Upload failed for user {user_id}: {str(e)}")
    
    async def get_file_for_user(
        self,
        user_id: str,
        job_id: str
    ) -> Dict[str, Any]:
        """Fetch JSON with user validation.
        
        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
        
        Returns:
            Dictionary with file data and metadata
        
        Raises:
            PermissionError: If file not found or user unauthorized
        """
        # Query DB - only user's own files (RLS enforced)
        file_record = await self.db.get_sheet_file_by_job(job_id, user_id)
        
        if not file_record:
            raise PermissionError("File not found or user unauthorized")
        
        # Download from storage
        storage_path = file_record["storage_path"]
        file_content = self.client.storage.from_(self.bucket).download(storage_path)
        
        return {
            "file_id": file_record["id"],
            "job_id": job_id,
            "user_id": user_id,
            "data": json.loads(file_content),
            "created_at": file_record["created_at"]
        }
    
    async def delete_file_for_user(
        self,
        user_id: str,
        job_id: str
    ) -> bool:
        """Delete file with user validation (both DB + storage).
        
        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
        
        Returns:
            True if successful
        
        Raises:
            PermissionError: If file not found or user unauthorized
        """
        # Get file record (validates ownership via RLS)
        file_record = await self.db.get_sheet_file_by_job(job_id, user_id)
        
        if not file_record:
            raise PermissionError("File not found or user unauthorized")
        
        # Delete from storage
        try:
            self.client.storage.from_(self.bucket).remove([file_record["storage_path"]])
        except StorageException as e:
            logger.error("Storage deletion failed for user artifact: %s", type(e).__name__)
            raise
        
        # Delete from DB
        await self.db.delete_sheet_file(file_record["id"], user_id)
        
        return True
    
    async def upload_pdf(
        self,
        user_id: str,
        job_id: str,
        pdf_content: bytes
    ) -> str:
        """Upload PDF to user-scoped path.
        
        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
            pdf_content: Raw PDF bytes
        
        Returns:
            Storage path for the PDF
        """
        if not self._is_valid_uuid(user_id):
            raise ValueError(f"Invalid user_id: {user_id}")
        
        # Create user-scoped path for PDFs
        storage_path = f"{user_id}/{job_id}/input.pdf"
        
        self.client.storage.from_("pdf_uploads").upload(
            path=storage_path,
            file=pdf_content,
            file_options={"x-upsert": "true"}
        )
        
        return storage_path
    
    async def download_pdf(self, pdf_path: str) -> bytes:
        """Download PDF from storage."""
        return self.client.storage.from_("pdf_uploads").download(pdf_path)
    
    async def upload_labeled_pdf(
        self,
        user_id: str,
        job_id: str,
        pdf_content: bytes
    ) -> Dict[str, Any]:
        """Upload labeled PDF to user-scoped path in sheet_data bucket.

        Stored alongside output.json so it shares the same public-bucket
        policies and can be fetched via a plain public URL on iOS.

        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
            pdf_content: Raw PDF bytes

        Returns:
            Dictionary with storage_path and file info

        Raises:
            ValueError: If user_id is invalid
            Exception: If upload fails
        """
        if not self._is_valid_uuid(user_id):
            raise ValueError(f"Invalid user_id: {user_id}")

        # Store beside input.pdf in the pdf_uploads bucket
        storage_path = f"{user_id}/{job_id}/labeled.pdf"

        self.client.storage.from_("pdf_uploads").upload(
            path=storage_path,
            file=pdf_content,
            file_options={"content-type": "application/pdf", "x-upsert": "true"}
        )

        return {
            "success": True,
            "storage_path": storage_path,
            "file_size_bytes": len(pdf_content)
        }
    
    async def get_labeled_pdf_for_user(
        self,
        user_id: str,
        job_id: str
    ) -> bytes:
        """Download labeled PDF with user validation.
        
        Args:
            user_id: The authenticated user's ID
            job_id: The job ID
        
        Returns:
            Raw PDF bytes
        
        Raises:
            PermissionError: If file not found or user unauthorized
        """
        # Verify job belongs to user (RLS)
        job = await self.db.get_job(job_id, user_id)
        
        if not job:
            raise PermissionError("Job not found or user unauthorized")
        
        # Download from pdf_uploads bucket (beside input.pdf)
        storage_path = f"{user_id}/{job_id}/labeled.pdf"

        try:
            pdf_content = self.client.storage.from_("pdf_uploads").download(storage_path)
            return pdf_content
        except Exception as e:
            raise FileNotFoundError(f"Labeled PDF not found: {str(e)}")


# Legacy function for backward compatibility
def get_supabase_client() -> Client:
    """Create and return a Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set")
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def store_output(job_id: str, json_data: Dict[str, Any]) -> str:
    """Upload output JSON to Supabase Storage and return public URL.
    
    DEPRECATED: Use StorageManager.upload_json() instead.
    
    Args:
        job_id: The job ID.
        json_data: The JSON data to store.
    
    Returns:
        Public URL of the stored file.
    
    Raises:
        ValueError: If Supabase credentials are not configured.
        Exception: If upload fails.
    """
    client = get_supabase_client()
    
    # Convert JSON data to string
    json_str = json.dumps(json_data, indent=2)
    
    # Create file path in storage
    file_path = f"{job_id}/output.json"
    
    # Upload to Supabase Storage
    client.storage.from_(SUPABASE_BUCKET).upload(
        file_path,
        json_str.encode('utf-8'),
        file_options={"content-type": "application/json"}
    )
    
    # Get signed URL
    signed_result = client.storage.from_(SUPABASE_BUCKET).create_signed_url(file_path, 3600)
    if isinstance(signed_result, str):
        return signed_result
    signed_url = signed_result.get("signedURL") or signed_result.get("signedUrl")
    if signed_url and not signed_url.startswith((HTTP_PREFIX, HTTPS_PREFIX)):
        return f"{SUPABASE_URL.rstrip('/')}/storage/v1{signed_url}"
    public_url = signed_url

    return public_url
