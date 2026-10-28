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

## Still open

| Item | State |
|---|---|
| **Google Sign-In** | Not implemented — needs a Google Cloud OAuth client and the app's SHA-1. The button was removed rather than left dead. |
| **Forgot password delivery** | The endpoint exists; reset links need SMTP. Until then the screen confirms without sending. |
| **Domain + HTTPS** | Runs on the server address over plain HTTP. No domain is registered, by request. |
| **Campay live keys** | Payments settle in sandbox — nothing is charged. Keys go in `backend/.env`; the callback URL to register is `/api/v1/payments/webhook/campay`. |
| **SMS/email OTP** | Codes are issued but not delivered; sandbox returns them. |
| **iOS** | Android only. |
| **Word-sync for uploaded recordings** | Timings are estimated from the clip's length. Exact per-word timing needs forced alignment. |

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
