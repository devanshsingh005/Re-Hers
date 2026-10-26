# Backend Project Structure

## 📁 Directory Layout

```
backend/
├── .env                          # Environment variables (DO NOT COMMIT)
├── .env.example                  # Template for .env
├── .gitignore                    # Git ignore patterns
├── requirements.txt              # Python dependencies
├── README.md                     # Project documentation
│
├── app/                          # Main application package
│   ├── __init__.py              # Package initializer
│   ├── main.py                  # FastAPI application & endpoints
│   ├── config.py                # Configuration from environment
│   ├── models.py                # Data models
│   │
│   ├── auth.py                  # JWT authentication & user verification
│   ├── database.py              # PostgreSQL operations with user isolation
│   ├── storage.py               # Supabase Storage integration
│   ├── queue.py                 # Redis job queue
│   │
│   ├── audiveris_client.py      # OCR service integration
│   ├── dispatcher.py            # Background job processor
│   ├── orphan_detector.py       # Data integrity monitoring
│   │
│   └── __pycache__/             # Python bytecode cache
│
├── migrations/                   # Database schema migrations
│   └── 001_user_isolation.sql   # Initial schema with RLS policies
│
├── jobs/                         # Local job directories (gitignored)
│   └── [job_id]/                # Created at runtime
│
└── .venv/                        # Python virtual environment (gitignored)
```

## 🔧 Core Modules

### Authentication (`app/auth.py`)
- JWT token verification with Supabase
- User extraction from Authorization header
- FastAPI dependency injection for protected routes

### Database (`app/database.py`)
- PostgreSQL operations with RLS enforcement
- User-scoped CRUD for jobs and sheet_files
- Connection management via Supabase client

### Storage (`app/storage.py`)
- Supabase Storage integration
- User-isolated file paths: `{user_id}/{job_id}/filename`
- Automatic database linkage for uploaded files

### Dispatcher (`app/dispatcher.py`)
- Background worker for processing jobs
- Communicates with Audiveris OCR service
- Updates job status in database

### Orphan Detector (`app/orphan_detector.py`)
- Monitors data integrity
- Detects orphaned files in storage
- Identifies DB records without files

## 🔐 Security Features

- **User Isolation**: RLS policies enforce data separation per user
- **Authentication**: JWT tokens required for all protected endpoints
- **Storage**: Files stored under user_id paths
- **Database**: All tables have RLS with user_id checks

## 📚 API Endpoints

### Public
- `GET /health` - Health check

### Protected (require Authorization: Bearer token)
- `POST /convert` - Upload PDF for conversion
- `GET /jobs` - List user's jobs
- `GET /jobs/{job_id}` - Get job status
- `GET /sheets/{job_id}` - Download converted JSON
- `DELETE /sheets/{job_id}` - Delete job and files

### Admin
- `GET /admin/orphans/detect` - Detect orphaned files
- `POST /admin/orphans/cleanup` - Clean orphaned files

## 🚀 Production Deployment

1. Set up `.env` with Supabase credentials and Audiveris URL
2. Run database migrations: `001_user_isolation.sql`
3. Install dependencies: `pip install -r requirements.txt`
4. Start server: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
5. Optional: Deploy Redis for horizontal scaling

## 🧹 Cleanup Status

✅ Temporary debugging scripts removed
✅ Test job folders cleaned
✅ Test data removed from storage
✅ Test jobs removed from database
✅ macOS system files (.DS_Store) removed
✅ Production code verified and organized
