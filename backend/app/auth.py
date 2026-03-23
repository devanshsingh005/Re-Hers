"""Authentication helpers for Supabase Auth."""
from fastapi import HTTPException, Depends, Header
from typing import Optional, Dict, Any
from supabase import create_client, Client
from app.config import SUPABASE_URL, SUPABASE_KEY


class AuthManager:
    """Manages Supabase authentication."""
    
    def __init__(self, supabase_url: str, supabase_key: str):
        """Initialize auth manager."""
        self.client: Client = create_client(supabase_url, supabase_key)
    
    async def verify_token(self, token: str) -> Dict[str, Any]:
        """Verify JWT token and return user data.
        
        Args:
            token: JWT token from Authorization header
        
        Returns:
            User data including user_id
        
        Raises:
            HTTPException: If token is invalid
        """
        try:
            # Verify token with Supabase
            user = self.client.auth.get_user(token)
            return {
                "id": user.user.id,
                "email": user.user.email,
                "user_metadata": user.user.user_metadata or {}
            }
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
    
    async def get_current_user(self, authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
        """Extract and verify current user from Authorization header.
        
        Args:
            authorization: Authorization header (format: "Bearer <token>")
        
        Returns:
            User data
        
        Raises:
            HTTPException: If no valid token provided
        """
        if not authorization:
            raise HTTPException(status_code=401, detail="Missing authorization header")
        
        try:
            # Extract token from "Bearer <token>"
            parts = authorization.split()
            if len(parts) != 2 or parts[0].lower() != "bearer":
                raise HTTPException(status_code=401, detail="Invalid authorization header")
            
            token = parts[1]
            return await self.verify_token(token)
        
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=401, detail="Authentication failed")


# Global auth manager instance
_auth_manager: Optional[AuthManager] = None


def get_auth_manager() -> AuthManager:
    """Get or create auth manager."""
    global _auth_manager
    if _auth_manager is None:
        _auth_manager = AuthManager(SUPABASE_URL, SUPABASE_KEY)
    return _auth_manager


async def get_current_user(authorization: Optional[str] = Header(None)) -> Dict[str, Any]:
    """Dependency for FastAPI endpoints requiring authentication.
    
    Usage:
        @app.get("/protected")
        async def protected_endpoint(user: dict = Depends(get_current_user)):
            return {"user_id": user["id"]}
    """
    auth_manager = get_auth_manager()
    return await auth_manager.get_current_user(authorization)


async def require_admin(user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    """Dependency that enforces admin privileges.

    Admin user IDs are configured via the ADMIN_USER_IDS environment variable
    (comma-separated Supabase UUIDs).  An empty ADMIN_USER_IDS intentionally
    blocks all admin access so the secure default is 'no admins configured'.

    Usage:
        @app.get("/admin/something")
        async def admin_endpoint(user: dict = Depends(require_admin)):
            ...
    """
    from app.config import ADMIN_USER_IDS  # late import avoids circular deps
    if not ADMIN_USER_IDS:
        raise HTTPException(
            status_code=403,
            detail="Admin access is not configured on this server.",
        )
    if user["id"] not in ADMIN_USER_IDS:
        raise HTTPException(status_code=403, detail="Admin privileges required.")
    return user
