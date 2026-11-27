# LYRR — Completion Status

Server: `http://100.27.229.125:8080`
Admin: `http://100.27.229.125:8080/admin/login` — `admin@lyrr.app` / `admin123`
App: `dist/lyrr-server.apk`
Demo reader: `demo@lyrr.app` / `demo123`

---

## What the product does now

A book is sold on paper. In the app, **reading is free** and **listening is
sold one play at a time**:

- The admin uploads a narration and sets **price per listen**.
- A reader buys one listen → plays once → the listen is spent.
- When the last listen is spent, the downloaded copy is withdrawn from the
  account, as the client asked.
- A book can carry several recordings — English, French, a local dialect — and
  each is sold and counted separately.

---

## Working, end to end (verified on the server)

```
GET  /books/{id}/lectures        price, recordings, listens held
POST /books/{id}/lectures/purchase   buy one listen  (Card / Orange / MTN)
POST /books/{id}/lectures/start      spend one listen, return the clip
```

```
read-only notice      "Read-only access · a listen costs 500 XAF"
play                  buy sheet with three payment methods
buy (Orange Money)    201  500 XAF
approve               200  completed
listens held          en: 1
play                  200  left=0  withdraw_download=true
play again            402  refused, offers another purchase
```

### Reader
Paged layout, serif body text, four themes, font size and measure, on-device
narration with word highlighting, download for offline, continue-reading shelf,
bookmarks and notes.

### Admin
Dashboard with revenue and a 14-day chart, books with covers and search, EPUB
import (text, chapters, cover), narration upload with language and chapter,
price per listen, users, categories, analytics and an Excel export. Every action
reports its outcome in a banner.

### Accounts
Register, sign in, password reset endpoints, phone verification, JWT sessions,
per-device records.

---

## Deliberately not shown

**Subscriptions** are hidden from both the app and the admin. The product no
longer sells them, and a subscription screen would promise something the app
does not offer.

---

## Production configuration

The server runs with the production gates **on**:

```
ENVIRONMENT                 production
DEBUG                       false
MEDIA_AUTH_ENABLED          true          narration needs a token
BYPASS_LIBRARY_PERMISSIONS  false         entitlements enforced
DEV_EXPOSE_TOKENS           false         no tokens in responses
CORS_ORIGINS                ["http://100.27.229.125:8080"]
```

Verified against the live server: an anonymous request is refused, the admin
portal redirects to login, and narration is **401 without a token, 200 with
one** — so the app still plays while nothing is downloadable for free.

`docker-compose.yml` reads the **root** `.env`, not `backend/.env`. Changing
the backend one alone does nothing to the running container; use the root file
and `docker compose up -d --force-recreate api`.

Containers are `restart: unless-stopped`, so they come back after a reboot.
A nightly dump runs at 03:15 (`/home/ubuntu/lyrr-backup.sh`, seven kept) into
`/home/ubuntu/backups`.

Disk is at 98% — new images or large uploads will need the volume resized.

---

## Still open

| Item | State |
|---|---|
| **Google Sign-In** | Not implemented — needs a Google Cloud OAuth client and the app's SHA-1. The button was removed rather than left dead. |
| **Forgot password delivery** | The endpoint exists; reset links need SMTP. Until then the screen confirms without sending. |
| **Domain + HTTPS** | Runs on the server address over plain HTTP. No domain is registered, by request. |
| **Campay live keys** | Payments settle in sandbox — nothing is charged. Keys go in `backend/.env`; the callback URL to register is `/api/v1/payments/webhook/campay`. |
| **SMS/email OTP** | Codes are issued but not delivered; sandbox returns them. |
| **iOS** | Configured for iOS 13+ (Info.plist background audio & ATS set, Podfile created). StoreKit IAP (Guideline 3.1.1) and macOS Xcode environment required for App Store release. |
| **Word-sync for uploaded recordings** | Timings are estimated from the clip's length. Exact per-word timing needs forced alignment. |

---

## iOS Implementation & Readiness

The core application code in `frontend/lib` (Flutter/Dart) is cross-platform and architecturally compatible with iOS:

1. **Native iOS Manifests & Background Playback**:
   - [`frontend/ios/Runner/Info.plist`](file:///home/asim/scm/xconnio/lyrr_platform/frontend/ios/Runner/Info.plist): Configured with `UIBackgroundModes: ["audio"]` to keep audiobooks and TTS narration playing when the screen is locked or the app is minimized.
   - **App Transport Security (ATS)**: Configured with `NSAppTransportSecurity` to permit network calls and audio streaming over the current plain HTTP backend server address (`http://100.27.229.125:8080`).
   - [`frontend/ios/Podfile`](file:///home/asim/scm/xconnio/lyrr_platform/frontend/ios/Podfile): Standardized with iOS 13.0 deployment target and CocoaPods plugin hooks.

2. **App Store Payment Compliance (Guideline 3.1.1)**:
   - On Android and Web, Lyrr sells pay-per-listen audio tokens via Campay (Orange Money / MTN MoMo / Credit Card).
   - Under Apple App Store Guideline 3.1.1, all digital audio unlocks consumed in an iOS app must be handled through **Apple In-App Purchase (StoreKit)**.
   - For an App Store release, either:
     - Implement StoreKit consumable tokens (e.g. `1 Listen`, `5 Listens`) using Flutter's `in_app_purchase` plugin.
     - Or adopt the **Reader App** model where purchases are completed on the web portal and the iOS client unlocks them via account sync.

3. **Build Toolchain & Distribution Requirements**:
   - Generating iOS release artifacts (`.ipa`, TestFlight, or App Store submissions) requires a macOS build environment with Xcode and CocoaPods (or a macOS CI/CD runner such as GitHub Actions or Codemagic) and an active Apple Developer Program membership.


---

## Running it

```bash
./start.sh          # infrastructure + backend + migrations + seed
./start.sh app      # the mobile app

# rebuild the app against the server
cd frontend && flutter build apk --release \
  --dart-define=API_BASE_URL=http://100.27.229.125:8080/api/v1
```

Release builds default to the server address, so a build without the flag still
talks to the right place.

See `docs/DEMO.md` for the walkthrough to give a client.
