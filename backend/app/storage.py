"""Supabase storage integration for storing job outputs."""
import json
from typing import Dict, Any
from supabase import create_client, Client
from app.config import SUPABASE_URL, SUPABASE_KEY, SUPABASE_BUCKET


def get_supabase_client() -> Client:
    """Create and return a Supabase client."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set")
    return create_client(SUPABASE_URL, SUPABASE_KEY)


def store_output(job_id: str, json_data: Dict[str, Any]) -> str:
    """Upload output JSON to Supabase Storage and return public URL.
    
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
    
    # Get public URL
    public_url = client.storage.from_(SUPABASE_BUCKET).get_public_url(file_path)
    
    return public_url
