# LYRR Platform - Complete Architecture

## Overview

Full-fledged audiobook synchronization platform with enterprise features.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  Mobile App  │  │  Desktop App │  │    Web App   │  │  Admin Portal│   │
│  │   (Flutter)  │  │   (Flutter)  │  │   (Flutter)  │  │ (Flutter Web)│   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              API GATEWAY                                     │
│                         (Fastify + Rate Limiting)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              ▼                       ▼                       ▼
┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
│   AUTH SERVICE      │ │   CORE SERVICES     │ │   MEDIA SERVICES    │
│  ┌───────────────┐   │ │  ┌───────────────┐   │ │  ┌───────────────┐   │
│  │  JWT/OAuth2   │   │ │  │  Book API     │   │ │  │  Audio CDN    │   │
│  │  Magic Links  │   │ │  │  Sync API     │   │ │  │  Transcoding  │   │
│  │  Social Auth  │   │ │  │  Library API  │   │ │  │  AI Narration │   │
│  └───────────────┘   │ │  │  Search API   │   │ │  └───────────────┘   │
└─────────────────────┘ │  └───────────────┘   │ └─────────────────────┘
                        │  ┌───────────────┐   │
                        │  │  User Data    │   │
                        │  │  - Bookmarks  │   │
                        │  │  - Notes      │   │
                        │  │  - Progress   │   │
                        │  │  - Settings   │   │
                        │  └───────────────┘   │
                        └─────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATA LAYER                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  PostgreSQL  │  │    Redis     │  │     S3       │  │ Elasticsearch│   │
│  │  (Primary)   │  │   (Cache)    │  │   (Media)    │  │   (Search)   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Technology Stack

### Backend
- **Runtime**: Node.js 20+
- **Framework**: Fastify 4.x
- **Database**: PostgreSQL 15+ (with encryption)
- **Cache**: Redis 7+
- **Search**: Elasticsearch 8+
- **Storage**: AWS S3 / MinIO
- **Queue**: BullMQ (Redis)
- **Real-time**: Socket.io

### Frontend
- **Framework**: Flutter 3.16+
- **State Management**: Riverpod 2.x
- **Local DB**: Drift (SQLite) + Hive
- **HTTP**: Dio
- **WebSocket**: Socket.io client

### Infrastructure
- **Container**: Docker + Docker Compose
- **Orchestration**: Kubernetes (production)
- **CI/CD**: GitHub Actions
- **Monitoring**: Prometheus + Grafana

## Security Architecture

### Encryption
- **At Rest**: AES-256-GCM for database fields
- **In Transit**: TLS 1.3
- **Media**: AES-128-CBC with rotating keys (DRM)

### Authentication
- JWT with RS256
- Refresh token rotation
- Device fingerprinting
- Rate limiting per user/IP

### DRM
- License server with device binding
- Encrypted media chunks
- Key rotation every 24 hours
- Offline license validation

## Database Schema

### Users
```sql
users (id, email, password_hash, created_at, updated_at)
user_profiles (user_id, name, avatar, preferences)
user_devices (id, user_id, device_fingerprint, last_active)
```

### Books
```sql
books (id, title, author, description, cover_url, duration, language, is_published)
book_chapters (id, book_id, title, order_index)
book_content (id, book_id, word_data, sync_data)
book_media (id, book_id, audio_url, format, quality)
```

### User Data
```sql
user_books (user_id, book_id, purchase_date, license_key)
reading_progress (user_id, book_id, position, last_read_at)
bookmarks (id, user_id, book_id, word_id, note, created_at)
notes (id, user_id, book_id, word_id, content, created_at, updated_at)
```

### Sync
```sql
sync_queue (id, user_id, device_id, operation, data, status)
sync_conflicts (id, user_id, entity_type, local_data, server_data)
```

## API Endpoints

### Authentication
```
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
POST /auth/forgot-password
POST /auth/reset-password
POST /auth/social/{provider}
```

### Books
```
GET /books (search, filter, pagination)
GET /books/:id
GET /books/:id/content
GET /books/:id/sync
POST /books/:id/download
GET /books/:id/license
```

### User Data
```
GET /me/library
GET /me/progress
POST /me/progress
GET /me/bookmarks
POST /me/bookmarks
DELETE /me/bookmarks/:id
GET /me/notes
POST /me/notes
PUT /me/notes/:id
DELETE /me/notes/:id
```

### Sync
```
POST /sync/push
GET /sync/pull
POST /sync/resolve
```

## Features

### Core
- [x] Synchronized playback
- [x] Binary search sync (O(log n))
- [x] Offline mode
- [x] Book downloads

### Authentication
- [x] JWT authentication
- [x] Social login (Google, Apple)
- [x] Magic links
- [x] Biometric authentication

### Cloud
- [x] Real-time sync
- [x] Conflict resolution
- [x] Multi-device support
- [x] Background sync

### DRM & Security
- [x] Encrypted media
- [x] License server
- [x] Device binding
- [x] Offline validation

### User Features
- [x] Bookmarks with notes
- [x] Annotations
- [x] Full-text search
- [x] Dictionary lookup
- [x] Reading statistics

### AI Features
- [x] AI narration (ElevenLabs)
- [x] Voice cloning
- [x] Language translation
- [x] Auto-sync generation

### Admin
- [x] Book management
- [x] User management
- [x] Analytics dashboard
- [x] Content moderation
- [x] Revenue reports

## Multi-Language Support

### Supported Languages
- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Portuguese (pt)
- Chinese (zh)
- Japanese (ja)
- Korean (ko)
- Arabic (ar)

### Localization
- ARB files for Flutter
- i18n for backend
- RTL support for Arabic
- Dynamic font loading

## Deployment

### Development
```bash
docker-compose up
```

### Production
- Kubernetes cluster
- Horizontal pod autoscaling
- CDN for media delivery
- Database read replicas
- Redis cluster

## Monitoring

### Metrics
- API response times
- Sync latency
- Audio streaming quality
- Error rates
- User engagement

### Logging
- Structured JSON logs
- Correlation IDs
- Distributed tracing
- Audit logs for security
