# Re-Hearse Project Overview

**Last Updated:** February 19, 2026  
**Status:** Active Development

---

## 📋 Table of Contents

1. [Project Summary](#project-summary)
2. [Architecture Overview](#architecture-overview)
3. [Frontend (iOS/Swift)](#frontend-iosswift)
4. [Backend (Python/FastAPI)](#backend-pythonfastapi)
5. [Database & Storage](#database--storage)
6. [Key Features](#key-features)
7. [Project Structure](#project-structure)
8. [Development Setup](#development-setup)
9. [API Endpoints](#api-endpoints)
10. [Important Files & Locations](#important-files--locations)

---

## 📱 Project Summary

**Re-Hearse** is a music learning and practice application designed to help musicians improve their skills through chord recognition, sheet music playback with animation, and interactive practice sessions.

### Core Purpose
- Enable musicians to upload sheet music (PDFs or images)
- Convert sheet music to playable formats using OCR
- Provide real-time chord recognition
- Display animated piano visualization during playback
- Track practice progress with daily goals
- Support chord learning and skill development

### Technology Stack
- **Frontend:** iOS (Swift, UIKit, iOS 14+)
- **Backend:** Python (FastAPI, Redis, PostgreSQL)
- **Storage:** Supabase (PostgreSQL + Object Storage)
- **OCR Service:** Audiveris (HTTP API)
- **Authentication:** Supabase Auth (JWT)
- **Audio:** AVFoundation, Core Audio

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS APPLICATION                          │
│              (Swift, UIKit Components)                       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
        ┌─────────────────────────────────────┐
        │     Network Layer (REST API)        │
        │  with JWT Authentication            │
        └─────────────────────────────────────┘
                          │
        ┌─────────────────┴──────────────────┐
        ▼                                    ▼
┌───────────────────┐            ┌──────────────────────┐
│  Supabase Auth    │            │   FastAPI Backend    │
│  (User Session)   │            │   (API Layer)        │
└───────────────────┘            └──────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
            ┌───────────────┐    ┌──────────────┐    ┌──────────────┐
            │  PostgreSQL   │    │  Redis Queue │    │Audiveris OCR │
            │  (via RLS)    │    │  (Jobs)      │    │  (HTTP)      │
            └───────────────┘    └──────────────┘    └──────────────┘
                    │
            ┌───────▼───────┐
            │ Supabase      │
            │ Object Store  │
            │ (PDFs, JSON)  │
            └───────────────┘
```

### Data Flow
1. **Upload**: User selects sheet music (PDF/Image) → Uploaded to Supabase Storage
2. **Queue**: Upload triggers background job in Redis queue
3. **Processing**: Audiveris converts PDF to MusicXML/JSON format
4. **Storage**: Converted data stored back to Supabase with user isolation
5. **Display**: iOS app fetches and displays sheet music with animations

---

## 📲 Frontend (iOS/Swift)

### Project Structure

```
Re-Hearse_v1/
├── AppDelegate.swift              # App lifecycle
├── SceneDelegate.swift            # Scene management
├── Info.plist                     # Configuration
└── Assets.xcassets/              # Images, colors, icons

Common/
├── BottomNavbar.swift            # Bottom navigation component
└── Music_Components/
    ├── AnimatedKeyboardView.swift # Piano keyboard with animations
    ├── PianoKeyView.swift         # Individual piano key
    ├── waveframe.swift            # Audio waveform visualization
    └── WaveView.swift             # Waveform display

Features/
└── ChordRecognition/
    └── ChordRecognition.swift     # Chord recognition logic

Screens/
├── ExploreViewController.swift    # Music exploration/discovery
├── SearchPageViewController.swift # Search functionality
├── SongDetailsPage.swift          # Song details view
├── ProfileScreen/
│   └── UserProfileViewController.swift # User profile
├── MainHomeScreen/               # Home screen with multiple sections
│   ├── HomeViewController.swift
│   ├── HomeViewControllerButtons.swift
│   ├── HomeViewControllerContinueCard.swift      # Resume practice card
│   ├── HomeViewControllerContinueLearning.swift  # Learning section
│   ├── HomeViewControllerDailyGoal.swift         # Daily practice goal
│   ├── HomeViewControllerFooter.swift
│   ├── HomeViewControllerLayout.swift
│   └── HomeViewControllerUploadSection.swift
├── MainAnimationScreen/          # Piano playback with animations
│   ├── PianoAnimationViewController.swift
│   ├── PianoDemoManager.swift
│   ├── PianoLogic.swift
│   ├── PianoView.swift
│   ├── AudioEngineManager.swift   # AVAudioEngine setup
│   ├── MusicJSONLoader.swift      # JSON parsing
│   └── SongChord.swift
├── MainChordRecognitionScreen/   # Real-time chord detection
│   ├── ChordRecognitionViewController.swift
│   ├── MainChordRecognitionScreen.swift
│   ├── ChordAudioManager.swift
│   └── ChordRecognitionScreen.swift
├── MainUplaodScreen/             # PDF/image upload
│   ├── uploadScreen.swift
│   ├── UploadPageNextViewController.swift
│   ├── MaximizeUploadPageViewController.swift
│   └── ChordRecognitionViewController.swift
├── MainLoginSignupScreen/        # Authentication
│   └── AuthViewController.swift
├── OnBoardingQuestionsScreen/    # Onboarding flow
│   ├── OnboardingFlowRoot.swift
│   ├── OnboardingQuestion1View.swift
│   ├── OnboardingQuestion2View.swift
│   ├── OnboardingQuestion3View.swift
│   ├── OnboardingViewModel.swift
│   └── ProgressIndicator.swift
└── Splash/
    └── SplashViewController.swift # Splash screen

SupabaseBackend/
└── SupabaseManager.swift         # Singleton for Supabase client
```

### Key View Controllers

#### HomeViewController
- **Purpose**: Main dashboard after login
- **Components**:
  - Daily practice goal tracker with progress
  - Continue learning card (resume last session)
  - Recent upload section
  - Daily goal notification
- **Features**:
  - Practice timer updates
  - Real-time progress tracking
  - Link to other screens

#### PianoAnimationViewController
- **Purpose**: Display sheet music playback with animated piano
- **Features**:
  - Animated piano keyboard synchronized to music
  - Chord display in real-time
  - Play/pause controls
  - Tempo adjustment slider
  - JSON-based music data loading

#### ChordRecognitionViewController(s)
- **Purpose**: Real-time chord recognition from microphone input
- **Features**:
  - Audio input capture
  - FFT analysis for pitch detection
  - Chord identification and display
  - User feedback and scoring

#### UploadScreen
- **Purpose**: Upload sheet music (PDFs or images)
- **Features**:
  - PDF/image selection from device
  - Document scanning via Vision Kit
  - Image enhancement with Core Image
  - Metadata entry (title, cover image)
  - Integration with backend API
  - Recent uploads display

### UI Components (Common)

#### AnimatedKeyboardView
- Displays piano keyboard with visual feedback
- Highlights pressed keys
- Supports note animation

#### WaveView
- Visualizes audio waveforms
- Real-time update capability

#### TopNavbar
- Consistent navigation header across screens
- Customizable title

#### BottomNavbar
- Tab navigation between main sections
- Active tab indication

---

## 🐍 Backend (Python/FastAPI)

### Project Structure

```
backend/
├── requirements.txt              # Python dependencies
├── .env                         # Environment configuration (DO NOT COMMIT)
├── .env.example                 # Template for .env
├── README.md                    # Backend documentation
├── PROJECT_STRUCTURE.md         # Backend structure details
│
├── app/
│   ├── __init__.py
│   ├── main.py                 # FastAPI app & endpoints
│   ├── config.py               # Environment configuration
│   ├── models.py               # Pydantic models
│   │
│   ├── auth.py                 # JWT authentication
│   ├── database.py             # PostgreSQL operations + RLS
│   ├── storage.py              # Supabase Storage integration
│   ├── queue.py                # Redis job queue
│   │
│   ├── audiveris_client.py     # OCR service client
│   ├── dispatcher.py           # Background job processor
│   └── orphan_detector.py      # Data integrity monitoring
│
└── migrations/
    └── 001_user_isolation.sql  # Database schema with RLS
```

### Core Modules

#### auth.py
- **Purpose**: JWT authentication and user verification
- **Key Functions**:
  - `verify_token()`: Validates Supabase JWT tokens
  - User extraction from Authorization header
  - FastAPI dependency for protected routes

#### database.py
- **Purpose**: PostgreSQL operations with Row-Level Security (RLS)
- **Key Tables**:
  - `users`: User profiles with authentication
  - `jobs`: Conversion jobs (user_id FK, status tracking)
  - `sheet_files`: Converted sheet music files (user_id FK)
- **Features**:
  - User-scoped CRUD operations
  - RLS policy enforcement
  - Connection pooling

#### storage.py
- **Purpose**: Supabase Object Storage integration
- **Buckets**:
  - `pdf_uploads`: Original PDF uploads
  - `sheet_data`: Converted JSON/MusicXML output
- **Features**:
  - User-isolated paths: `{user_id}/{job_id}/filename`
  - Automatic database linkage
  - File validation (MIME type, size)

#### queue.py
- **Purpose**: Redis job queue management
- **Features**:
  - Enqueue/dequeue operations
  - Job serialization
  - Status tracking

#### audiveris_client.py
- **Purpose**: HTTP client for Audiveris OCR service
- **Integration Points**:
  - PDF to MusicXML conversion
  - Error handling and retries
  - Response parsing

#### dispatcher.py
- **Purpose**: Background worker for processing queued jobs
- **Behavior**:
  - Infinite loop polling Redis queue
  - Single-threaded job execution
  - Status updates to database
  - File storage integration

#### orphan_detector.py
- **Purpose**: Data integrity monitoring
- **Functions**:
  - Detects orphaned files in storage
  - Identifies DB records without corresponding files
  - Cleanup utilities

### API Endpoints

#### Health Check
```
GET /health
Response: {"status": "ok"}
```

#### Protected Endpoints (Require Bearer Token)

**Upload PDF for Conversion**
```
POST /convert
Headers: Authorization: Bearer {jwt_token}
Body: 
{
  "file": <binary>,
  "metadata": {
    "title": "Song Name",
    "artist": "Artist Name"
  }
}
Response:
{
  "job_id": "uuid",
  "status": "queued",
  "created_at": "2026-02-19T10:30:00Z"
}
```

**List User's Jobs**
```
GET /jobs
Headers: Authorization: Bearer {jwt_token}
Response:
{
  "jobs": [
    {
      "job_id": "uuid",
      "title": "Song Name",
      "status": "completed",
      "created_at": "2026-02-19T10:30:00Z",
      "output_url": "https://..."
    }
  ]
}
```

**Get Job Status**
```
GET /jobs/{job_id}
Headers: Authorization: Bearer {jwt_token}
Response:
{
  "job_id": "uuid",
  "status": "completed|running|failed",
  "output_url": "https://..." (if completed),
  "error": "error message" (if failed)
}
```

**Download Converted JSON**
```
GET /sheets/{job_id}
Headers: Authorization: Bearer {jwt_token}
Response: JSON sheet music data
```

**Delete Job and Files**
```
DELETE /sheets/{job_id}
Headers: Authorization: Bearer {jwt_token}
Response: {"success": true}
```

#### Admin Endpoints

**Detect Orphaned Files**
```
GET /admin/orphans/detect
Response:
{
  "orphaned_files": [...],
  "orphaned_db_records": [...]
}
```

**Cleanup Orphaned Files**
```
POST /admin/orphans/cleanup
Response: {"cleaned": 5, "errors": 0}
```

### Dependencies
```
fastapi==0.104.1          # Web framework
uvicorn==0.24.0           # ASGI server
requests==2.31.0          # HTTP client
python-dotenv==1.0.0      # Environment variables
python-multipart==0.0.9   # File upload handling
supabase==2.0.0           # Supabase client
redis==5.0.1              # Redis client
pydantic==2.5.0           # Data validation
pyjwt==2.8.0              # JWT handling
```

---

## 🗄️ Database & Storage

### Database Schema

#### users Table
```sql
id (UUID, PK)
email (TEXT, UNIQUE)
name (TEXT)
created_at (TIMESTAMP)
-- RLS: Users can only read/write own records
```

#### jobs Table
```sql
id (UUID, PK)
user_id (UUID, FK→users.id)
title (TEXT)
status (TEXT: queued|running|completed|failed)
input_url (TEXT: path to original PDF)
output_url (TEXT: path to converted JSON)
error_message (TEXT)
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
-- RLS: Users can only access their own jobs
```

#### sheet_files Table
```sql
id (UUID, PK)
user_id (UUID, FK→users.id)
job_id (UUID, FK→jobs.id)
file_name (TEXT)
file_type (TEXT: pdf|json|musicxml)
file_size (INTEGER)
storage_path (TEXT)
created_at (TIMESTAMP)
-- RLS: Users can only access their own files
```

### Storage Buckets

#### pdf_uploads
- **Path Pattern**: `{user_id}/{job_id}/input.pdf`
- **Contents**: Original PDF files
- **Retention**: Configurable (could be deleted after OCR)

#### sheet_data
- **Path Pattern**: `{user_id}/{job_id}/output.json`
- **Contents**: Converted music notation (MusicXML/JSON)
- **Retention**: Long-term storage

### Security Features

#### Row-Level Security (RLS)
- All tables enforce user isolation via `user_id`
- Users cannot query other users' data at database level
- Enforced on PostgreSQL before data leaves server

#### Storage Security
- Files organized under `{user_id}/` paths
- RLS policies prevent unauthorized access
- Signed URLs with expiration for downloads

---

## 🎵 Key Features

### 1. Sheet Music Upload & Conversion
- **Input**: PDF or scanned images
- **Process**: 
  1. User uploads via iOS app
  2. Backend queues job to Redis
  3. Dispatcher sends to Audiveris OCR
  4. Result stored in Supabase
- **Output**: MusicXML or JSON notation data

### 2. Animated Piano Playback
- **Display**: Visual piano keyboard animation
- **Sync**: Matches MIDI note timing from sheet music
- **Interaction**: Play/pause controls, tempo adjustment
- **Visualization**: Highlights keys as they're played

### 3. Real-Time Chord Recognition
- **Input**: Microphone audio feed
- **Analysis**: FFT-based pitch detection
- **Identification**: Chord matching algorithm
- **Display**: Visual chord name and notes

### 4. Practice Progress Tracking
- **Daily Goal**: Set practice time targets
- **Timer**: Tracks actual practice time
- **Progress**: Visual progress indicator (% complete)
- **Notifications**: Reminders for daily goals

### 5. Continue Learning
- **Resume**: Quick access to last practice session
- **History**: Recent uploads and sessions
- **Quick Actions**: Buttons to common features

### 6. User Authentication
- **System**: Supabase Auth (JWT tokens)
- **Methods**: Email/password, social login (optional)
- **Session**: Persistent authentication with token refresh
- **Isolation**: All data tied to authenticated user

---

## 📁 Project Structure

### Root Directory
```
/Users/user30/Desktop/Re-Hers/
├── README.md                     # Quick project info
├── PROJECT_OVERVIEW.md          # This file
├── ColorViewController.swift     # Color theme controller
├── Wurlitzer210.sf2             # SoundFont for piano
├── backend/                     # Python FastAPI backend
├── Re-Hearse_v1/                # Xcode project root
├── Re-Hearse_v1.xcodeproj/      # Xcode project file
├── Common/                      # Shared UI components
├── Features/                    # Feature-specific logic
├── Screens/                     # Screen/ViewController files
└── SupabaseBackend/             # Backend integration
```

### Important Xcode Project Files
- **Info.plist**: App configuration, capabilities
- **project.pbxproj**: Xcode project configuration
- **project.xcworkspace/**: Workspace settings
- **Assets.xcassets**: Images, colors, app icons, datasets

### Backend Files
- **app/main.py**: FastAPI application definition
- **app/config.py**: Environment and settings
- **requirements.txt**: Python dependencies
- **migrations/001_user_isolation.sql**: Database setup

---

## 🚀 Development Setup

### iOS Development

#### Prerequisites
- macOS with Xcode 14+
- iOS SDK 14.0+
- CocoaPods or Swift Package Manager

#### Setup Steps
1. Open `Re-Hearse_v1.xcodeproj` in Xcode
2. Configure Supabase credentials in `SupabaseManager.swift`
3. Build and run on simulator or device

#### Key Configuration
- **Supabase URL**: `https://djqgmowfjxsnjdffdohw.supabase.co`
- **Backend API**: Configure in environment setup

### Backend Development

#### Prerequisites
- Python 3.9+
- Redis (local or remote)
- PostgreSQL via Supabase

#### Setup Steps
```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with Supabase credentials and Audiveris URL

# Run database migrations
# Execute: migrations/001_user_isolation.sql in Supabase

# Start server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

#### Environment Variables (.env)
```
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_supabase_api_key

# Audiveris OCR Service
AUDIVERIS_API_URL=http://localhost:8080
AUDIVERIS_API_KEY=your_api_key

# Redis
REDIS_URL=redis://localhost:6379

# Security
JWT_SECRET=your_jwt_secret
```

---

## 📊 API Endpoints Summary

### Authentication Flow
1. User logs in via Supabase Auth (handles JWT generation)
2. iOS app receives JWT token
3. All subsequent API calls include `Authorization: Bearer {token}`
4. Backend verifies token and extracts `user_id`

### Data Flow Examples

#### Upload Sheet Music
```
iOS → POST /convert (with PDF)
   ↓
Backend → Validate JWT, save to Supabase Storage
   ↓
Backend → Create job record in PostgreSQL
   ↓
Backend → Enqueue to Redis
   ↓
iOS ← Return job_id
   ↓
iOS → GET /jobs/{job_id} (poll status)
```

#### Retrieve Sheet Music
```
iOS → GET /sheets/{job_id}
   ↓
Backend → Verify user_id matches job ownership (RLS)
   ↓
Backend → Fetch from Supabase Storage
   ↓
iOS ← Receive JSON/MusicXML data
```

---

## ⚠️ Important Files & Locations

### Core Backend Files
- [app/main.py](backend/app/main.py) - FastAPI application & routes
- [app/auth.py](backend/app/auth.py) - JWT authentication
- [app/database.py](backend/app/database.py) - Database operations
- [app/storage.py](backend/app/storage.py) - File storage integration
- [app/dispatcher.py](backend/app/dispatcher.py) - Background job processing
- [migrations/001_user_isolation.sql](backend/migrations/001_user_isolation.sql) - Database schema

### Core iOS Files
- [SupabaseBackend/SupabaseManager.swift](SupabaseBackend/SupabaseManager.swift) - Supabase singleton
- [Screens/MainUplaodScreen/uploadScreen.swift](Screens/MainUplaodScreen/uploadScreen.swift) - Upload functionality
- [Screens/MainAnimationScreen/PianoAnimationViewController.swift](Screens/MainAnimationScreen/PianoAnimationViewController.swift) - Piano animation
- [Screens/MainChordRecognitionScreen/ChordRecognitionViewController.swift](Screens/MainChordRecognitionScreen/ChordRecognitionViewController.swift) - Chord recognition
- [Screens/MainHomeScreen/HomeViewController.swift](Screens/MainHomeScreen/HomeViewController.swift) - Home screen

### Configuration Files
- [Re-Hearse_v1/Info.plist](Re-Hearse_v1/Info.plist) - iOS app configuration
- [backend/requirements.txt](backend/requirements.txt) - Python dependencies
- [backend/.env.example](backend/.env.example) - Backend environment template

### Documentation
- [backend/README.md](backend/README.md) - Backend documentation
- [backend/PROJECT_STRUCTURE.md](backend/PROJECT_STRUCTURE.md) - Backend structure details
- [README.md](README.md) - Root project README

---

## 🔒 Security & Privacy

### User Data Protection
- ✅ All data isolated by `user_id`
- ✅ JWT authentication required for all protected endpoints
- ✅ RLS policies prevent unauthorized database access
- ✅ Files stored in user-scoped storage paths
- ✅ No cross-user data leakage possible

### File Handling
- ✅ MIME type validation on upload
- ✅ File size limits enforced
- ✅ Automatic cleanup of orphaned files
- ✅ Audit logging for all operations

### API Security
- ✅ HTTPS enforced
- ✅ Token expiration and refresh
- ✅ CORS policies configured
- ✅ Input validation with Pydantic

---

## 🐛 Common Issues & Troubleshooting

### Backend Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid JWT token | Verify token not expired, re-login user |
| 404 Not Found | Job doesn't exist or user mismatch | Check job_id and user_id match |
| Redis connection error | Redis service not running | Start Redis: `redis-server` |
| Database connection error | .env not configured | Set SUPABASE_URL and SUPABASE_KEY |

### iOS Issues
| Issue | Cause | Solution |
|-------|-------|----------|
| Upload fails | Network error or invalid credentials | Check internet connection, re-verify JWT |
| Piano animation stutters | Audio engine timing issue | Check CPU usage, reduce quality settings |
| Chord recognition inaccurate | Poor audio input or FFT params | Test microphone, adjust threshold |

---

## 📈 Performance Considerations

### Backend Optimization
- **Job Processing**: Async with Redis queue prevents blocking
- **Database**: Connection pooling reduces overhead
- **Storage**: CDN delivery through Supabase
- **Scaling**: Horizontal scaling possible with load balancer

### iOS Optimization
- **Memory**: Audio buffers managed efficiently
- **UI**: Smooth animations with CADisplayLink
- **Battery**: Background tasks properly suspended
- **Network**: Efficient API calls with caching

---

## 📝 Development Notes

### Naming Convention
- **Swift**: camelCase for variables/functions, PascalCase for classes
- **Python**: snake_case for functions/variables, PascalCase for classes
- **Database**: snake_case for tables and columns

### Code Organization
- UI components grouped by feature in `Screens/`
- Shared components in `Common/`
- Backend logic modularized in `app/`
- Database schemas in `migrations/`

### Version Control
- Frontend: Swift/iOS Xcode project
- Backend: Python FastAPI application
- Configuration: Environment files (not committed)
- Database: SQL migrations in `migrations/`

---

## 🔄 Future Enhancements

### Planned Features
- [ ] Offline mode with local caching
- [ ] Multi-instrument support (violin, guitar, etc.)
- [ ] Social features (sharing, collaboration)
- [ ] Advanced analytics dashboard
- [ ] ML-based practice recommendations
- [ ] Video tutorial integration
- [ ] MIDI export capability

### Technical Debt
- [ ] Comprehensive unit tests
- [ ] Integration tests for API
- [ ] E2E tests for iOS
- [ ] Performance benchmarking
- [ ] Documentation for API clients
- [ ] Error handling improvements

---

## 📞 Contact & Support

- **Project Location**: `/Users/user30/Desktop/Re-Hers`
- **Last Updated**: February 19, 2026
- **Version**: Active Development

---

**End of Project Overview**
