# LYRR Platform

A comprehensive audiobook synchronization platform with Flutter mobile app, FastAPI backend, and Flutter Web admin portal.

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Run the setup script
./scripts/setup-local.sh
```

This will:
- Create Python virtual environment
- Install dependencies
- Start PostgreSQL, Redis, and MinIO in Docker
- Run database migrations
- Configure environment

### Option 2: Manual Setup

#### 1. Start Infrastructure Services

```bash
cd infrastructure
docker-compose -f docker-compose.local.yml up -d
```

Services started:
- PostgreSQL on port 5432
- Redis on port 6379
- MinIO (S3-compatible) on port 9000 (console: 9001)

#### 2. Setup Backend

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Configure environment
cp ../.env.example ../.env
# Edit .env with your settings

# Run migrations
alembic upgrade head

# Start server
uvicorn app.main:app --reload
```

API will be available at http://localhost:8000/docs

#### 3. Setup Flutter App

```bash
cd frontend
flutter pub get
flutter run
```

#### 4. Access Admin Portal

The admin portal is served by the backend at http://localhost:8000/admin
(login with the admin account created by `make seed`).

## Project Structure

```
lyrr_platform/
├── backend/              # FastAPI backend
│   ├── app/
│   │   ├── api/         # API endpoints
│   │   ├── core/        # Config, database, security
│   │   ├── models/      # SQLAlchemy models
│   │   ├── schemas/     # Pydantic schemas
│   │   └── templates/   # Jinja2 admin portal
│   ├── alembic/         # Database migrations
│   ├── requirements.txt # Core dependencies
│   └── requirements-dev.txt    # Dev dependencies
├── frontend/            # Flutter mobile app
├── infrastructure/      # Docker configs
│   ├── docker-compose.local.yml   # Local dev
│   └── docker-compose.prod.yml    # Production
└── scripts/             # Setup scripts
```

## Environments

### Local Development

```bash
# Start infrastructure
docker-compose -f infrastructure/docker-compose.local.yml up -d

# Run backend locally (with hot reload)
cd backend
source venv/bin/activate
uvicorn app.main:app --reload

# Run Flutter app
cd frontend
flutter run
```

### Production

```bash
# Full production stack
docker-compose -f infrastructure/docker-compose.prod.yml up -d
```

## Dependencies

### Core (Required)
- FastAPI, Uvicorn
- SQLAlchemy, asyncpg
- Pydantic, python-jose, passlib

### Development
- pytest, black, isort, flake8, mypy

### Optional (Install as needed)
- Redis (caching)
- Elasticsearch (search)
- OpenAI/Anthropic (AI narration)
- Celery (background tasks)
- boto3 (cloud storage)

Install optional dependencies:
```bash
pip install -r requirements-optional.txt
```

## API Documentation

Once running, access:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health Check: http://localhost:8000/health

## Features

- **Authentication**: JWT with refresh tokens, OAuth2
- **Book Management**: Upload, DRM encryption, metadata
- **Audio Sync**: Binary search word-level synchronization
- **Offline Mode**: Download books, local SQLite with Drift
- **Cloud Sync**: Bidirectional sync with conflict resolution
- **Bookmarks & Notes**: User annotations
- **Search**: Full-text with Elasticsearch
- **AI Narration**: Optional TTS integration
- **Admin Portal**: Dashboard, analytics, content management

## License

MIT
# lyrr_platform
