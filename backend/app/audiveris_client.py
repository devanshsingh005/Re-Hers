"""Client for calling Audiveris HTTP API."""
import requests
import json
import os
from typing import Dict, Any
from app.config import AUDIVERIS_API_URL


def run_audiveris(pdf_path: str) -> Dict[str, Any]:
    """Call Audiveris API with PDF file and return JSON output.
    
    Args:
        pdf_path: Path to the PDF file to process.
    
    Returns:
        Parsed JSON response from Audiveris.
    
    Raises:
        requests.HTTPError: If the API returns a non-200 status code.
        FileNotFoundError: If the PDF file doesn't exist.
    """
    # #region agent log
    import json
    with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
        f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"audiveris_client.py:23","message":"Function entry","data":{"pdf_path":pdf_path,"AUDIVERIS_API_URL":AUDIVERIS_API_URL},"timestamp":int(__import__('time').time()*1000)}) + '\n')
    # #endregion
    
    # Prepare the multipart form data
    url = f"{AUDIVERIS_API_URL}?format=json"
    
    # #region agent log
    with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
        f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"D","location":"audiveris_client.py:26","message":"Constructed URL before request","data":{"url":url,"base_url":AUDIVERIS_API_URL},"timestamp":int(__import__('time').time()*1000)}) + '\n')
    # #endregion
    
    # #region agent log
    with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
        f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"audiveris_client.py:29","message":"Before HTTP POST request","data":{"url":url,"pdf_file_exists":os.path.exists(pdf_path) if 'os' in dir() else False},"timestamp":int(__import__('time').time()*1000)}) + '\n')
    # #endregion
    
    try:
        with open(pdf_path, 'rb') as pdf_file:
            files = {'file': (pdf_path.split('/')[-1], pdf_file, 'application/pdf')}
            
            # #region agent log
            with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
                f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"audiveris_client.py:33","message":"Sending POST request","data":{"url":url},"timestamp":int(__import__('time').time()*1000)}) + '\n')
            # #endregion
            
            response = requests.post(url, files=files)
            
            # #region agent log
            with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
                f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"audiveris_client.py:36","message":"HTTP request completed","data":{"status_code":response.status_code},"timestamp":int(__import__('time').time()*1000)}) + '\n')
            # #endregion
    except Exception as e:
        # #region agent log
        with open('/Users/user30/Backend/.cursor/debug.log', 'a') as f:
            f.write(json.dumps({"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"audiveris_client.py:40","message":"HTTP request exception","data":{"error_type":type(e).__name__,"error_message":str(e),"url":url},"timestamp":int(__import__('time').time()*1000)}) + '\n')
        # #endregion
        raise
    
    # Raise exception if response is not 200
    response.raise_for_status()
    
    # Parse and return JSON
    return response.json()
