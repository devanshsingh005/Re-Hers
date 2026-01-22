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

# Storage bucket name
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "audiveris-outputs")
