# LYRR Platform - Architecture

## Overview

Audiobook + e-book reading platform with word-level audio synchronization.
Flutter mobile app, FastAPI backend, server-rendered Jinja2 admin portal,
and Flutter Web frontend.

## System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                            CLIENT LAYER                              │
├──────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────────────┐  │
│  │ Mobile App  │  │ Flutter Web App │  │ Admin Portal (Jinja2)   │  │
│  │  (Flutter)  │  │  (frontend/)    │  │ (backend /admin routes) │  │
│  └─────────────┘  └─────────────────┘  └─────────────────────────┘  │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Nginx Reverse Proxy (infrastructure/)            │
│                     TLS-ready, rate limiting, media streaming       │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     FastAPI Backend (backend/)                       │
│  /api/v1  REST API (JWT auth, books, user data, sync, media)        │
│  /admin   Server-rendered admin portal (Jinja2)                     │
│  /media   Audio streaming (Range requests) + cover images           │
└───────┬──────────────┬──────────────┬───────────────────────────────┘
        ▼              ▼              ▼
┌──────────────┐ ┌────────────┐ ┌──────────────┐
│  PostgreSQL  │ │   Redis    │ │   MinIO/S3   │
│  (primary)   │ │  (cache,   │ │   (media)    │
│              │ │  CSRF store│ │              │
└──────────────┘ └────────────┘ └──────────────┘
```

## Technology Stack

### Backend (backend/)
- **Runtime**: Python 3.11, FastAPI + Uvicorn
- **Database**: PostgreSQL 15 (SQLAlchemy 2 async + asyncpg)
- **Migrations**: Alembic
- **Auth**: JWT (access + refresh tokens), bcrypt password hashing
- **Security**: CSRF tokens (Redis-backed store), rate limiting (slowapi),
  upload validation (extension + size caps), zip-slip-safe EPUB extraction
- **Cache/Queue**: Redis (async client)
- **Search**: Elasticsearch (optional)
- **Admin Portal**: Jinja2 server-rendered templates (`app/templates/admin/`)

### Frontend (frontend/)
- **Framework**: Flutter (mobile + web)
- **State management**: Riverpod 2.x
- **Local storage**: Drift (SQLite) for offline content + sync queue
- **Audio**: just_audio with word-level sync highlighting
- **TTS**: flutter_tts for read-aloud

### Deployment (infrastructure/)
- **Docker Compose** (`docker-compose.prod.yml`): api, db, redis,
  elasticsearch, web, nginx
- **Nginx**: reverse proxy, TLS-ready (cert paths commented until provisioned),
  rate limits, media streaming pass-through
- **Monitoring**: Prometheus + Grafana (full-stack compose only)

## Key Flows

### Authentication
1. Client POSTs `/api/v1/auth/register` (rate-limited 5/min)
2. Login (`/api/v1/auth/login`, 10/min) returns access (30 min) + refresh (7 day) tokens
3. Access token sent as `Authorization: Bearer` header
4. Refresh via `/api/v1/auth/refresh` (30/min)
5. Admin portal uses a separate `admin`-typed JWT cookie + CSRF tokens

### Audio Sync
1. Chapters store per-word timestamps (`sync_data`)
2. Client binary-searches word position for audio position
3. Tapping a highlighted word seeks the audio
4. Audio streamed with HTTP Range requests for seeking

### Offline Sync
1. Bookmarks/notes/progress written to local Drift DB with `isSynced: false`
2. `SyncService` pushes changes to `/api/v1/sync/push` (batch)
3. Pulls server changes via `/api/v1/sync/pull?since=...`
4. Conflicts stored for resolution

## Database Schema

### Users
```sql
users (id, email, hashed_password, is_active, is_verified, is_admin)
user_profiles (user_id, name, avatar_url, preferences)
user_devices (id, user_id, device_fingerprint, device_name, last_ip)
```

### Books
```sql
books (id, title, author, description, cover_url, book_type, language,
       duration, word_count, isbn, status, is_featured, drm_enabled)
chapters (id, book_id, title, order_index, content, sync_data)
book_media (id, book_id, audio_url, format, quality, is_ai_narrated)
user_books (id, user_id, book_id, license_key, license_type, expires_at)
```

### User Data
```sql
reading_progress (id, user_id, book_id, chapter_id, word_id,
                  position_seconds, progress_percent, last_read_at)
bookmarks (id, user_id, book_id, word_id, note, created_at)
notes (id, user_id, book_id, word_id, content, created_at, updated_at)
reading_sessions (id, user_id, book_id, date, duration_seconds)  -- streaks
```

### Sync
```sql
sync_queue (id, user_id, device_id, operation, entity_type, data, status)
sync_conflicts (id, user_id, entity_type, local_data, server_data)
sync_checkpoints (id, user_id, device_id, last_sync_at)
```

## API Endpoints

### Authentication (`/api/v1/auth`)
```
POST /register, /login, /login/form, /refresh, /logout, /forgot-password
GET  /me
```

### Books (`/api/v1/books`)
```
GET  /                    (search, filter, pagination)
GET  /{id}, /{id}/content, /{id}/sync
POST /{id}/license, /{id}/purchase, /{id}/download
PUT  /{id}, DELETE /{id}  (admin only)
```

### User Data (`/api/v1/me`)
```
GET  /library, /bookmarks, /notes, /progress, /progress/{book_id}
GET  /stats, /stats/streaks
POST /bookmarks, /notes, /progress
PUT  /bookmarks/{id}, /notes/{id}
DELETE /bookmarks/{id}, /notes/{id}
```

### Sync (`/api/v1/sync`)
```
POST /push, /resolve/{conflict_id}
GET  /pull, /conflicts, /checkpoint
```

### Admin (`/api/v1/admin`, admin-only)
```
GET /dashboard, /users, /analytics
```

### Admin Portal (`/admin`, Jinja2 + CSRF)
```
Login/logout, dashboard, books (CRUD, cover/audio/EPUB upload),
users (CRUD), subscriptions, categories, analytics + CSV export
```

## Deployment

### Development
```bash
./scripts/setup-local.sh          # venv + infra + env
make start                        # infra + backend with reload
```

### Production
```bash
cd infrastructure
export SECRET_KEY=... ENCRYPTION_KEY=... DB_PASSWORD=...
docker-compose -f docker-compose.prod.yml up -d --build
```
The API container runs `alembic upgrade head` before starting.

## Security Notes

- Secrets are injected via environment variables; `.env` files are gitignored
- Rate limits: register 5/min, login 10/min, refresh 30/min, admin login 10/min
- CSRF tokens are one-time-use, stored in Redis (multi-worker safe)
- Media streaming validates paths and Range headers
- EPUB upload is zip-slip-safe and size-capped

## Known Gaps (not production-ready features)

- Social login (Google/Apple) is a stub returning 501
- Forgot-password does not send email yet
- Client-side DRM is cosmetic (audio plays via plain URL)
- Search (Elasticsearch) is not wired into book queries yet
