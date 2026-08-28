# LYRR Platform — Run, Build & Deploy Guide

Complete instructions to run the platform locally, deploy it to production, and
ship the mobile app. This covers every deliverable in the FRS (§15): source
code, documentation, database schema, admin guide, and end-user flow.

---

## 1. System Requirements

| Component  | Requirement                                              |
|------------|----------------------------------------------------------|
| OS         | Linux (Ubuntu 20.04+ recommended), macOS, or Windows WSL2 |
| Docker     | 24+ with docker-compose (v2 or v1.29+)                    |
| Python     | 3.11+                                                    |
| Flutter    | 3.24+ (stable channel) with Android SDK / Xcode           |
| PostgreSQL | 15 (provided by Docker)                                   |
| Redis      | 7 (provided by Docker)                                    |

Optional for search/monitoring: Elasticsearch 8.11, MinIO, Prometheus,
Grafana (all provided by `infrastructure/docker-compose.yml`).

---

## 2. Project Layout

```
lyrr_platform/
├── backend/                # FastAPI backend (API + admin portal)
│   ├── app/
│   │   ├── api/v1/endpoints/   # auth, books, payments, sync, admin, media
│   │   ├── core/               # config, security, database, rate_limit, csrf
│   │   ├── models/             # SQLAlchemy models (books, users, payments…)
│   │   ├── schemas/            # Pydantic schemas
│   │   ├── services/           # payments, verification (OTP)
│   │   └── templates/          # Jinja2 admin portal
│   ├── alembic/versions/       # DB migrations
│   └── seed_data.py            # Demo users, books, subscription plans
├── frontend/               # Flutter mobile app (Android/iOS/Web)
├── infrastructure/         # docker-compose, nginx, monitoring configs
├── scripts/                # setup-local.sh, start-local.sh, build.sh
└── Makefile                # make setup / start / migrate / seed / build-apk…
```

---

## 3. Local Development (Fastest Path)

### 3.1 One-command setup

```bash
./scripts/setup-local.sh
```

This creates the Python venv, installs dependencies, starts PostgreSQL/Redis/
MinIO in Docker, creates `.env`, runs migrations, and prints next steps.

Or use the Makefile:

```bash
make setup-infra     # start infra containers only
make migrate         # alembic upgrade head
make seed            # load demo users + books + subscription plans
make backend         # start FastAPI with hot reload on :8000
```

### 3.2 Manual steps (if you prefer)

```bash
# 1. Infrastructure
cd infrastructure && docker-compose -f docker-compose.local.yml up -d

# 2. Backend
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
cp ../.env.example ../.env      # then edit secrets (see §5)
alembic upgrade head
python seed_data.py
uvicorn app.main:app --reload   # http://localhost:8000

# 3. Flutter mobile app
cd frontend
flutter pub get
flutter run                      # device/emulator

# 4. Admin portal (served by the backend)
#    http://localhost:8000/admin  →  admin@lyrr.app / admin123
```

### 3.3 What you get after seeding

| Item                    | Value                                   |
|-------------------------|-----------------------------------------|
| Admin portal            | `http://localhost:8000/admin`           |
| Admin login             | `admin@lyrr.app` / `admin123`           |
| Demo user               | `demo@lyrr.app` / `demo123`             |
| API docs (Swagger)      | `http://localhost:8000/docs`            |
| Health check            | `http://localhost:8000/health`          |
| Subscription plans      | Monthly 2,000 XAF · Annual 20,000 XAF   |
| Sample books            | 5 seeded books with chapters + sync data|

> **Security note:** the seed script refuses to run with default credentials
> when `ENVIRONMENT=production`. Always set real `SEED_ADMIN_PASSWORD` and
> `SEED_DEMO_PASSWORD` for deployed environments.

---

## 4. Production Deployment (Docker)

### 4.1 Prepare the environment file

```bash
cp .env.example .env
```

Set the **mandatory** values (see §5 for the full list):

```bash
SECRET_KEY=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 16)
DEBUG=false
ENVIRONMENT=production
CORS_ORIGINS=["https://lyrr.app","https://admin.lyrr.app"]
```

### 4.2 Build and start the full stack

```bash
cd infrastructure
docker-compose -f docker-compose.prod.yml up -d --build
```

The production compose starts: **api**, **db** (PostgreSQL 15), **redis**,
**elasticsearch**, **minio**, **nginx** (reverse proxy on 80/443), and the
**web** container (Flutter Web build). The API container runs `alembic upgrade
head` on boot.

Verify:

```bash
curl http://localhost/health          # {"status":"healthy",...}
docker-compose -f docker-compose.prod.yml ps
```

### 4.3 Seed data (first deploy only)

```bash
docker exec lyrr-api python seed_data.py
```

### 4.4 TLS / domain (recommended)

Point `lyrr.app` and `admin.lyrr.app` A-records at the server, then either:

- Put a TLS-terminating reverse proxy (Caddy/Traefik/Cloudflare) in front of
  nginx, **or**
- Mount certificates into `infrastructure/nginx/` and uncomment the `443`
  server block in `infrastructure/nginx/nginx.conf`.

Update `CORS_ORIGINS` and the Flutter `API_BASE_URL` accordingly (§6.3).

---

## 5. Environment Configuration Reference

| Variable                  | Required | Default            | Purpose                                   |
|---------------------------|----------|--------------------|-------------------------------------------|
| `SECRET_KEY`              | ✅       | —                  | JWT signing. ≥32 chars: `openssl rand -hex 32` |
| `ENCRYPTION_KEY`          | ✅       | —                  | Fernet/DRM key. ≥16 chars                 |
| `DATABASE_URL`            | ✅       | postgresql+asyncpg://postgres:postgres@localhost:5432/lyrr | Async SQLAlchemy DSN |
| `REDIS_URL`               | dev      | redis://localhost:6379/0 | OTP store, rate-limit, cache        |
| `DEBUG`                   | —        | false              | `true` enables `create_all`, SQL echo, /docs |
| `ENVIRONMENT`             | —        | production         | `production` blocks default seed creds    |
| `CORS_ORIGINS`            | ✅ prod  | localhost origins  | JSON array of allowed web origins         |
| `PAYMENT_MODE`            | —        | sandbox            | `sandbox` (local checkout) or `live`      |
| `PAYMENT_CURRENCY`        | —        | XAF                | Currency for payments                     |
| `DEFAULT_BOOK_PRICE`      | —        | 500.0              | Fallback book price if unset              |
| `VERIFICATION_MODE`       | —        | sandbox            | `sandbox` returns OTP in response; `live` sends email/SMS |
| `BYPASS_LIBRARY_PERMISSIONS` | —     | true               | `true` = demo open access; `false` = enforce purchases/subscriptions |
| `MEDIA_AUTH_ENABLED`      | —        | false              | `true` + bypass false = hard audio protection |
| `RATE_LIMIT_ENABLED`      | —        | true               | slowapi rate limiting                     |
| `AWS_*`, `S3_*`           | optional | —                  | Object storage (MinIO/S3)                 |
| `OPENAI/ANTHROPIC/ELEVENLABS_API_KEY` | optional | —      | AI narration                              |

---

## 6. Mobile App (Flutter)

### 6.1 Point the app at your backend

`frontend/lib/core/config.dart` reads `API_BASE_URL` at build time:

```bash
# Local emulator (Android)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical device on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000/api/v1

# Production
flutter run --dart-define=API_BASE_URL=https://api.lyrr.app/api/v1
```

### 6.2 Build a release APK (Android)

```bash
cd frontend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.lyrr.app/api/v1
# Output: build/app/outputs/flutter-apk/app-release.apk

# Or via Makefile (copies to dist/lyrr.apk)
make build-apk
```

### 6.3 Build for iOS

```bash
cd frontend
flutter build ios --release --dart-define=API_BASE_URL=https://api.lyrr.app/api/v1
# Then open ios/Runner.xcworkspace in Xcode, set the bundle ID, signing team,
# and archive → App Store Connect.
```

### 6.4 Build Flutter Web

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.lyrr.app/api/v1
# Output: build/web/  (served by the `web` Docker container on :8080)
```

### 6.5 App feature flags

Set in `frontend/lib/core/config.dart`:

```dart
enableDRM        // AES-encrypted offline content
enableOfflineMode// local Drift DB + download for offline reading/listening
enableCloudSync  // bidirectional bookmark/note/progress sync every 5 min
enableAINarration// TTS/ElevenLabs narration
```

---

## 7. Payment Module (FRS §10)

### 7.1 Sandbox mode (default — works offline)

```bash
PAYMENT_MODE=sandbox
```

- **Card** checkouts settle immediately.
- **Orange Money / MTN MoMo** create an `awaiting_confirmation` payment; the
  mobile app calls `POST /api/v1/payments/{id}/confirm` after the user approves
  on their handset (sandbox simulates this).
- OTP codes for verification are returned in API responses (`sandbox_otp`) so
  the whole flow works locally.

### 7.2 Going live

1. Set `PAYMENT_MODE=live`.
2. Implement the provider adapter in `backend/app/services/payments.py`
   (CardGateway / MobileMoneyGateway `create_charge`/`verify_charge` stubs).
   Orange Money and MTN MoMo each expose an HTTP API; wire your merchant
   credentials there.
3. Point the gateway webhook at `POST /api/v1/payments/{payment_id}/confirm`
   so real approvals settle orders automatically.

### 7.3 API surface

| Endpoint                                | Purpose                          |
|-----------------------------------------|----------------------------------|
| `GET  /api/v1/payments/subscriptions`   | List active plans                |
| `GET  /api/v1/payments/methods`         | Supported methods                |
| `POST /api/v1/payments/checkout`        | Initiate book/subscription order |
| `POST /api/v1/payments/{id}/confirm`    | Confirm payment (webhook/client) |
| `GET  /api/v1/payments/history`         | Full payment history (FRS §10)   |
| `GET  /api/v1/payments/{id}`            | Payment status                   |
| `POST /api/v1/books/{id}/purchase`      | Legacy one-click purchase        |

Access rights are enforced on **content** (§7.4) and **audio streaming** (§8).

### 7.4 Access rules (FRS §11)

| Mode            | Free preview            | Paid content                          |
|-----------------|-------------------------|---------------------------------------|
| `BYPASS_LIBRARY_PERMISSIONS=true` | everything readable (demo) | —                          |
| `=false`        | book listing + metadata | requires purchase (UserBook) or active subscription |

Flip `BYPASS_LIBRARY_PERMISSIONS=false` once the purchase/licensing loop is
live in production.

---

## 8. Content Protection & Streaming (FRS §14)

- Audio files live in `backend/storage/audio/` and are **never** directly
  downloadable — they are only served through `/media/audio/{filename}`.
- The stream endpoint enforces:
  - a valid **Bearer token** (mobile app) or **admin cookie** (admin portal);
  - entitlement: purchase (`user_books`) or active subscription, unless
    `MEDIA_AUTH_ENABLED=false` **and** `BYPASS_LIBRARY_PERMISSIONS=true`
    (demo mode).
- Range requests are supported (seeking); path traversal is blocked.
- Offline content is AES-encrypted on-device (`DRMService` + `encrypt`), with
  per-device license keys issued by `POST /api/v1/books/{id}/license`.

To harden production:

```bash
MEDIA_AUTH_ENABLED=true
BYPASS_LIBRARY_PERMISSIONS=false
```

---

## 9. Verification & Phone Registration (FRS §4)

| Endpoint                          | Purpose                             |
|-----------------------------------|-------------------------------------|
| `POST /api/v1/auth/register`      | Email **+ optional phone** registration |
| `POST /api/v1/auth/verify/request`| Send OTP to email or phone          |
| `POST /api/v1/auth/verify/confirm`| Confirm OTP → marks verified        |
| `POST /api/v1/auth/login`         | Password login (JWT + refresh)      |
| `POST /api/v1/auth/forgot-password`| Password reset request             |

- Sandbox: OTP is returned as `sandbox_otp` (local testing).
- Live: set `VERIFICATION_MODE=live` and wire an SMTP/SMS provider into
  `backend/app/services/verification.py`; OTPs are then delivered out-of-band
  and never returned in responses.
- OTPs are 6 digits, expire in 10 minutes, stored in Redis (in-memory
  fallback), max 5 attempts.

---

## 10. Analytics & Excel Export (FRS §13)

`GET /api/v1/admin/analytics?days=30` (admin only) returns:

- total/new users
- reading + listening sessions, reading minutes
- revenue total, by day, by method (card / Orange Money / MTN MoMo)
- most popular books (by session volume)
- active subscriptions by plan

`GET /api/v1/admin/analytics/export` produces a real `.xlsx` workbook
(Summary, Revenue by Day, Popular Books sheets) — the FRS-mandated Excel
export. CSV export also remains at `/admin/analytics/export` in the portal UI.

---

## 11. Admin Portal

Served by the backend at **`/admin`** (Jinja2 templates, no separate build):

| Section          | Capabilities (FRS §12)                    |
|------------------|-------------------------------------------|
| Dashboard        | User/book/sync counts                     |
| Books            | Add, edit, delete; upload covers, audio, EPUB |
| Categories       | Manage categories                         |
| Subscriptions    | Create/modify/suspend plans               |
| Users            | Create, edit, suspend, delete users       |
| Analytics        | Metrics + CSV/Excel export                |

Admin auth is cookie-based (`admin_token`, 1h), CSRF-protected, and rate-limited.

---

## 12. Database Migrations

```bash
# Generate a migration after model changes
cd backend && source venv/bin/activate
alembic revision --autogenerate -m "describe change"
alembic upgrade head

# Rollback one step
alembic downgrade -1
```

Current migration chain:

```
39978fb9436c  initial schema
6b5cb45ffefd  payment fields + book pricing
1ca47ac25443  phone registration fields
```

---

## 13. Testing & CI Checklist

```bash
make test-backend      # pytest
make lint              # flake8 + mypy
make format            # black + isort
cd frontend && flutter analyze   # 0 errors expected
```

Smoke-test the full loop after any change:

1. `POST /api/v1/auth/register` (with phone)
2. request + confirm OTP (`/verify/request` → `/verify/confirm`)
3. `POST /api/v1/payments/checkout` (card → completed immediately)
4. `POST /api/v1/payments/{id}/confirm` (mobile money)
5. `GET /api/v1/payments/history`
6. `GET /media/audio/{file}` with Bearer token
7. `GET /api/v1/admin/analytics` + `/export` (xlsx)

---

## 14. Troubleshooting

| Symptom                                    | Fix                                          |
|--------------------------------------------|----------------------------------------------|
| `SECRET_KEY must be changed` on startup    | set a real key in `.env` (`openssl rand -hex 32`) |
| Checkout returns 500                        | check `payments.status` column width (needs ≥21 chars) — migration 6b5cb45ffefd widens it |
| OTP request returns no `sandbox_otp`        | confirm `VERIFICATION_MODE` is unset or `sandbox` |
| Audio 403 in prod                           | purchase the book or start a subscription; or set `MEDIA_AUTH_ENABLED=false` + `BYPASS_LIBRARY_PERMISSIONS=true` for demo |
| `flutter analyze` warnings                  | only lints (deprecations), no functional errors |
| Seed refuses to run                         | `ENVIRONMENT=production` + default creds — set `SEED_ADMIN_PASSWORD`/`SEED_DEMO_PASSWORD` |
| Migrations out of sync                      | `alembic upgrade head`; never edit applied migrations |

---

## 15. FRS Deliverables Checklist (§15)

| Deliverable                    | Location                                             |
|--------------------------------|------------------------------------------------------|
| Complete source code           | `backend/`, `frontend/`, `infrastructure/`           |
| Technical documentation        | `docs/ARCHITECTURE.md`, `docs/DEPLOYMENT.md`         |
| Installation documentation     | this file (§3–§4)                                    |
| Database schema + scripts      | `backend/alembic/versions/`, `backend/seed_data.py`  |
| Administrator user guide       | §11 of this document                                 |
| End-user guide                 | in-app onboarding + FRS §3–§9 features               |

Deployment order for a new environment:

1. `scripts/setup-local.sh` (or compose) → 2. `.env` secrets → 3. `alembic
   upgrade head` → 4. `python seed_data.py` → 5. start API → 6. configure
   `API_BASE_URL` and build the Flutter app → 7. flip `PAYMENT_MODE` /
   `VERIFICATION_MODE` / library bypass flags when going live.
