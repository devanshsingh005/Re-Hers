
"""Client for calling Audiveris HTTP API."""
import requests
import logging
from typing import Dict, Any
from app.config import AUDIVERIS_API_URL

logger = logging.getLogger(__name__)

# Module-level session reuses TCP/TLS connections across jobs in the same worker
# process. Each of the 4 worker processes has its own session — no sharing.
_session = requests.Session()


def run_audiveris(pdf_path: str, override_url: str = None) -> Dict[str, Any]:
    """Call Audiveris API with PDF file and return JSON output.
    
    Args:
        pdf_path: Path to the PDF file to process.
    
    Returns:
        Parsed JSON response from Audiveris.
    
    Raises:
        requests.HTTPError: If the API returns a non-200 status code.
        FileNotFoundError: If the PDF file doesn't exist.
    """
    # Prepare the API endpoint
    url = f"{override_url or AUDIVERIS_API_URL}?format=json"
    logger.info(f"Calling Audiveris API at {url}")
    
    try:
        with open(pdf_path, 'rb') as pdf_file:
            files = {'file': (pdf_path.split('/')[-1], pdf_file, 'application/pdf')}
            
            logger.debug(f"Sending PDF to Audiveris: {pdf_path}")
            response = _session.post(url, files=files, timeout=120)
            
            logger.info(f"Audiveris response status: {response.status_code}")
    except FileNotFoundError as e:
        logger.error(f"PDF file not found: {pdf_path}")
        raise
    except requests.RequestException as e:
        logger.error(f"Audiveris API request failed: {e}")
        raise
    
    # Raise exception if response is not 200
    response.raise_for_status()
    
    # Parse and return JSON
    json_output = response.json()
    logger.info(f"Successfully received JSON output from Audiveris (keys: {list(json_output.keys())})")
    return json_output
