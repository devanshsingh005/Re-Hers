"""Configuration module for loading environment variables."""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env from sibling directory (backend/)
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=str(env_path))

# Audiveris API configuration
AUDIVERIS_API_URL = os.getenv("AUDIVERIS_API_URL", "http://localhost:8080")

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")

# Storage bucket names
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "sheet_data")
PDF_BUCKET = os.getenv("PDF_BUCKET", "pdf_uploads")

# Request timeout (in seconds)
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", "300"))

# Max file size (in bytes)
MAX_FILE_SIZE = int(os.getenv("MAX_FILE_SIZE", "104857600"))  # 100MB

# CORS — comma-separated list of allowed origins; leave empty to disallow all cross-origin requests
_allowed_origins_env = os.getenv("ALLOWED_ORIGINS", "")
ALLOWED_ORIGINS = [o.strip() for o in _allowed_origins_env.split(",") if o.strip()]

# Admin access — comma-separated list of user IDs that may call admin endpoints
_admin_ids_env = os.getenv("ADMIN_USER_IDS", "")
ADMIN_USER_IDS = {uid.strip() for uid in _admin_ids_env.split(",") if uid.strip()}
