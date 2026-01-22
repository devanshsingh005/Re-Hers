# Audiveris PDF Conversion Backend

A FastAPI backend service that accepts PDF uploads, queues them for processing, and uses Audiveris HTTP API to convert PDFs to JSON format. The output is stored in Supabase Storage.

## System Overview

This backend acts as a **Manager** that coordinates between:
- **Users**: Upload PDFs and poll for results
- **Audiveris API**: External HTTP service that processes PDFs (treated as black-box)
- **Supabase**: Storage for job outputs
- **Dispatcher**: Background scheduler that processes jobs one at a time

## Architecture

```
┌─────────┐      POST /convert      ┌──────────┐
│  User   │ ──────────────────────> │ FastAPI  │
└─────────┘                          │  Backend │
     │                                └──────────┘
     │ GET /status/{job_id}                │
     │ <───────────────────────────────────┘
     │                                      │
     │                                ┌─────▼─────┐
     │                                │   Queue   │
     │                                └─────┬─────┘
     │                                      │
     │                                ┌─────▼────────┐
     │                                │  Dispatcher  │
     │                                │  (Background)│
     │                                └─────┬────────┘
     │                                      │
     │                                ┌─────▼──────────┐
     │                                │ Audiveris API  │
     │                                │  (HTTP Service)│
     │                                └─────┬──────────┘
     │                                      │
     │                                ┌─────▼────────┐
     │                                │  Supabase    │
     │                                │   Storage    │
     │                                └──────────────┘
```

## Job Lifecycle

1. **Upload**: User uploads PDF via `POST /convert`
   - Backend generates unique `job_id`
   - PDF saved to `jobs/{job_id}/input.pdf`
   - Job record created with status `queued`
   - Job ID added to queue
   - API returns immediately with `job_id`

2. **Processing**: Dispatcher picks up job from queue
   - Job status changes to `running`
   - Dispatcher calls Audiveris API with PDF file
   - Audiveris processes PDF and returns JSON
   - JSON output stored in Supabase Storage
   - Job status changes to `completed` with output URL

3. **Polling**: User checks status via `GET /status/{job_id}`
   - Returns current status, output URL (if completed), or error message

## Dispatcher Behavior

The dispatcher runs in a **background thread** and implements the following logic:

- **Infinite Loop**: Continuously checks for jobs in queue
- **Single Execution**: Only one job runs at a time (enforced by lock)
- **Non-blocking**: API requests return immediately, processing happens asynchronously
- **Error Handling**: Failed jobs are marked with error messages
- **Queue-based**: Uses FIFO (First-In-First-Out) queue

### Dispatcher Flow

```
while True:
    acquire execution lock
    dequeue job (with timeout)
    if job exists:
        mark job as "running"
        call Audiveris API
        store result in Supabase
        mark job as "completed" or "failed"
    release lock
    sleep briefly
```

## How Audiveris API is Integrated

The backend treats Audiveris as a **black-box HTTP service**:

- **Endpoint**: `POST {AUDIVERIS_API_URL}?format=json`
- **Method**: HTTP POST with multipart/form-data
- **Input**: PDF file uploaded as form field `file`
- **Output**: JSON response
- **Error Handling**: Raises exception if status code is not 200

The backend **never** runs Audiveris CLI directly - it only makes HTTP requests.

## Setup

### 1. Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file in the `backend/` directory:

```env
AUDIVERIS_API_URL=http://localhost:8080
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
SUPABASE_BUCKET=audiveris-outputs
```

### 3. Create Supabase Storage Bucket

Ensure you have a Supabase Storage bucket named `audiveris-outputs` (or update `SUPABASE_BUCKET` in `.env`).

### 4. Run the Backend

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Or use Python directly:

```bash
cd backend
python -m app.main
```

## API Endpoints

### POST /convert

Upload a PDF file for conversion.

**Request:**
- Method: `POST`
- Content-Type: `multipart/form-data`
- Body: PDF file

**Response:**
```json
{
  "job_id": "uuid-string",
  "status": "queued"
}
```

### GET /status/{job_id}

Get the status of a job.

**Response (queued/running):**
```json
{
  "job_id": "uuid-string",
  "status": "running",
  "input_pdf_path": "jobs/uuid-string/input.pdf"
}
```

**Response (completed):**
```json
{
  "job_id": "uuid-string",
  "status": "completed",
  "input_pdf_path": "jobs/uuid-string/input.pdf",
  "output_url": "https://supabase-storage-url/..."
}
```

**Response (failed):**
```json
{
  "job_id": "uuid-string",
  "status": "failed",
  "input_pdf_path": "jobs/uuid-string/input.pdf",
  "error": "Error message"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy"
}
```

## Project Structure

```
backend/
├── app/
│   ├── main.py              # FastAPI app and endpoints
│   ├── config.py            # Environment configuration
│   ├── models.py            # Job data models and store
│   ├── queue.py             # FIFO job queue
│   ├── dispatcher.py        # Background job processor
│   ├── audiveris_client.py  # Audiveris API client
│   └── storage.py           # Supabase storage integration
├── jobs/                    # Local storage for uploaded PDFs
├── requirements.txt         # Python dependencies
└── README.md               # This file
```

## Constraints & Design Decisions

- ✅ **Non-blocking**: API requests return immediately after upload
- ✅ **Single Worker**: Only one Audiveris job runs at a time
- ✅ **HTTP-only**: Backend never runs Audiveris CLI directly
- ✅ **Queue-based**: Jobs processed in FIFO order
- ✅ **In-memory Store**: Job status stored in memory (no database required)
- ❌ **No Celery/Kafka**: Simple threading-based solution
- ❌ **No Authentication**: Not implemented (optional feature)

## Testing

1. Start the backend server
2. Upload a PDF:
   ```bash
   curl -X POST "http://localhost:8000/convert" \
        -F "file=@example.pdf"
   ```
3. Poll for status:
   ```bash
   curl "http://localhost:8000/status/{job_id}"
   ```

## Notes

- The dispatcher starts automatically when the FastAPI app starts
- Jobs are stored in memory - restarting the server will lose job history
- Ensure Audiveris API is running and accessible at `AUDIVERIS_API_URL`
- Supabase Storage bucket must exist and be accessible with provided credentials
