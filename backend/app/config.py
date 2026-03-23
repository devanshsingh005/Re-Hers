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


class Settings:
    """Application settings loaded from environment variables."""

    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")


settings = Settings()

# ---------------------------------------------------------------------------
# Security Configuration
# ---------------------------------------------------------------------------

# Rate limiting — configurable at runtime; format: "<count>/<period>"
# where period is: second | minute | hour | day.
RATE_LIMIT_UPLOAD: str = os.getenv("RATE_LIMIT_UPLOAD", "10/minute")
RATE_LIMIT_API:    str = os.getenv("RATE_LIMIT_API",    "100/minute")
RATE_LIMIT_HEALTH: str = os.getenv("RATE_LIMIT_HEALTH", "60/minute")
RATE_LIMIT_ADMIN:  str = os.getenv("RATE_LIMIT_ADMIN",  "20/minute")

# CORS — explicit trusted origins only.
# wildcard ("*") is INVALID with allow_credentials=True (browsers reject it)
# and allows any website to call the API on behalf of your users.
# Comma-separated list; leading/trailing whitespace is stripped.
_raw_origins = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:3000,http://localhost:8081,http://localhost:8000",
)
ALLOWED_ORIGINS: list = [o.strip() for o in _raw_origins.split(",") if o.strip()]

# Queue / upload protection
MAX_QUEUE_DEPTH:              int = int(os.getenv("MAX_QUEUE_DEPTH",              "200"))
MAX_CONCURRENT_JOBS_PER_USER: int = int(os.getenv("MAX_CONCURRENT_JOBS_PER_USER", "5"))

# Admin access — comma-separated Supabase user UUIDs granted /admin/* routes.
# Empty set = no admin access configured (fail-secure by default).
ADMIN_USER_IDS: set = {
    uid.strip()
    for uid in os.getenv("ADMIN_USER_IDS", "").split(",")
    if uid.strip()
}
