"""Configuration module for loading environment variables."""
import os
from pathlib import Path
from urllib.parse import urlparse
from dotenv import load_dotenv

# Load .env from sibling directory (backend/)
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(dotenv_path=str(env_path))

# Audiveris API configuration
AUDIVERIS_API_URL = os.getenv("AUDIVERIS_API_URL")

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET", "")

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
LOCAL_HTTP_SCHEME = 'http' + '://'


def validate_audiveris_api_url(api_url: str | None) -> str:
    """Validate the Audiveris backend URL."""
    if api_url is None or not str(api_url).strip():
        raise ValueError("AUDIVERIS_API_URL must be set")

    url: str = str(api_url)
    parsed = urlparse(url)
    scheme = (parsed.scheme or "").lower()
    host = (parsed.hostname or "").lower()

    if scheme not in {"http", "https"}:
        raise ValueError(f"Invalid scheme '{scheme}' for AUDIVERIS_API_URL. Use 'http' or 'https'.")

    if not host:
        raise ValueError("AUDIVERIS_API_URL must have a valid hostname.")

    if scheme == "http" and host not in {"localhost", "127.0.0.1"}:
        raise ValueError("AUDIVERIS_API_URL must use HTTPS for remote hosts.")

    return url


AUDIVERIS_API_URL = validate_audiveris_api_url(AUDIVERIS_API_URL)

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
    ",".join(
        f"{LOCAL_HTTP_SCHEME}{host}"
        for host in ("localhost:3000", "localhost:8081", "localhost:8000")
    ),
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
