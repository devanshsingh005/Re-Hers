"""Orphan detection and cleanup for sheet_files."""
import logging
from app.database import DatabaseClient
from app.storage import StorageManager
from typing import Dict, List, Any
from storage3.utils import StorageException

logger = logging.getLogger(__name__)


class OrphanDetector:
    """Detects and cleans up orphaned files in storage and database."""
    
    def __init__(self, db_client: DatabaseClient, storage_manager: StorageManager):
        """Initialize orphan detector.
        
        Args:
            db_client: Database client
            storage_manager: Storage manager
        """
        self.db = db_client
        self.storage = storage_manager
    
    async def detect_orphans(self) -> Dict[str, Any]:
        """
        Find files with no DB reference and DB records with missing files.
        
        Returns:
            Dictionary with orphaned_storage_files, orphaned_db_records, and is_healthy
        """
        orphaned_storage_files = []
        orphaned_db_records = []
        
        try:
            # Get all files from database
            db_files = await self.db.get_all_sheet_files()
            db_paths = {f["storage_path"]: f for f in db_files}
            
            # Get all files from storage
            storage_files = self.storage.client.storage.from_(
                self.storage.bucket
            ).list(recursive=True)
            
            # Check each storage file has a DB record
            for storage_file in storage_files:
                storage_path = storage_file.name
                if storage_path not in db_paths:
                    orphaned_storage_files.append(storage_path)
            
            # Check each DB record has a storage file
            for db_file in db_files:
                storage_path = db_file["storage_path"]
                try:
                    self.storage.client.storage.from_(
                        self.storage.bucket
                    ).download(storage_path)
                except Exception as e:
                    if not isinstance(e, StorageException) or "not found" not in str(e).lower():
                        logger.error("Storage check error: %s", type(e).__name__)
                        continue
                    orphaned_db_records.append({
                        "file_id": db_file["id"],
                        "user_id": db_file["user_id"],
                        "job_id": db_file["job_id"],
                        "storage_path": storage_path
                    })
            
            return {
                "orphaned_storage_files": orphaned_storage_files,
                "orphaned_db_records": orphaned_db_records,
                "is_healthy": len(orphaned_storage_files) == 0 and len(orphaned_db_records) == 0,
                "total_storage_files": len(storage_files),
                "total_db_records": len(db_files)
            }
        
        except Exception as e:
            logger.error("Orphan detection failed: %s", type(e).__name__)
            return {
                "error": "Orphan detection failed",
                "is_healthy": False
            }
    
    async def cleanup_orphans(self, dry_run: bool = True) -> Dict[str, Any]:
        """
        Clean up orphaned files.
        
        Args:
            dry_run: If True, only report what would be deleted without actually deleting
        
        Returns:
            Report of actions taken
        """
        report = await self.detect_orphans()
        
        if "error" in report:
            return {"error": report["error"]}
        
        actions = {
            "deleted_storage_files": [],
            "deleted_db_records": [],
            "marked_orphaned": []
        }
        
        try:
            if not dry_run:
                # Delete orphaned storage files (no DB record)
                for storage_path in report["orphaned_storage_files"]:
                    try:
                        self.storage.client.storage.from_(
                            self.storage.bucket
                        ).remove([storage_path])
                        actions["deleted_storage_files"].append(storage_path)
                    except Exception as e:
                        logger.error("Storage deletion error during orphan cleanup: %s", type(e).__name__)
                
                # Delete or mark orphaned DB records (missing storage files)
                for db_record in report["orphaned_db_records"]:
                    try:
                        # Mark as orphaned instead of deleting (for audit trail)
                        await self.db.mark_sheet_file_orphaned(db_record["file_id"])
                        actions["marked_orphaned"].append({
                            "file_id": db_record["file_id"],
                            "reason": "Storage file missing"
                        })
                    except Exception as e:
                        logger.error("Failed to update orphan status in database: %s", type(e).__name__)
        
        except Exception as e:
            logger.error("Orphan cleanup failed: %s", type(e).__name__)
            return {"error": "Orphan cleanup failed", "dry_run": dry_run}
        
        return {
            "dry_run": dry_run,
            "report": report,
            "actions": actions
        }
    
    async def get_orphan_summary(self) -> Dict[str, Any]:
        """Get summary of orphaned files for dashboard/alerts."""
        report = await self.detect_orphans()
        
        if "error" in report:
            return {"status": "error", "message": "Orphan detection failed"}
        
        orphaned_storage_count = len(report["orphaned_storage_files"])
        orphaned_db_count = len(report["orphaned_db_records"])
        total_orphaned = orphaned_storage_count + orphaned_db_count
        
        return {
            "status": "healthy" if report["is_healthy"] else "unhealthy",
            "total_orphaned_items": total_orphaned,
            "orphaned_storage_files": orphaned_storage_count,
            "orphaned_db_records": orphaned_db_count,
            "total_files": report["total_storage_files"],
            "total_records": report["total_db_records"],
            "health_percentage": (
                ((report["total_db_records"] - orphaned_db_count) / report["total_db_records"] * 100)
                if report["total_db_records"] > 0
                else 100
            )
        }
