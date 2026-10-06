# LYRR — Client Demo Script

Server: `http://100.27.229.125:8080`
Admin: `http://100.27.229.125:8080/admin/login` — `admin@lyrr.app` / `admin123`
App: `dist/lyrr-server.apk` (already points at the server above)

Everything below was walked end to end and works. Total run time ~10 minutes.

---

## Before they arrive

```bash
# server up?
curl -s -o /dev/null -w "%{http_code}\n" http://100.27.229.125:8080/health   # want 200

# phone connected?
adb devices                       # want one device
adb install -r dist/lyrr-server.apk
```

Have the app already open and signed in as `demo@lyrr.app` / `demo123`, on the
Store tab. Do not fumble with a login in front of them.

---

## 1. The reader app (5 min) — lead with this

**Store.** Open it. Eight real titles with their real cover art. Say: this is
the catalogue; the client's own titles go in here, uploaded by their team.

**Open a book.** Tap *Alice's Adventures in Wonderland* → it opens in about a
second and reads as a real book, in a serif face at a comfortable pace.
Scroll a page or two.

**Narration.** Tap play. It narrates the text and highlights the words as it
goes. Point out: *no audio file needed* — the app reads with the phone's own
voice. If a publisher sends a real recording, that plays instead.

**Reading controls.** Tap the middle of the page → the control bar. Show the
"Aa" settings: font size, page width, and light / sepia / dark / green themes.

**Offline.** In My Library, tap the download icon on a book, then turn on
airplane mode and open it. It still reads. This is the FRS §9 requirement.

**Continue reading.** Back on the Store, the book now sits in a
*Continue Reading* rail with its progress, one tap from where they stopped.

**Premium.** Profile → Subscribe. Show the three payment methods —
Card, Orange Money, MTN Mobile Money — and the Monthly / Annual plans in XAF.
(Checkout completes in sandbox; do not promise a live charge yet.)

---

## 2. The admin panel (4 min) — show they can run it themselves

**Dashboard.** Published titles, registered readers, revenue, a 14-day
revenue chart, recent payments, and covers.

**Add a book.** Books → Add Book → title, author, price → Create.
A green banner confirms, *"Book created."* — point out that every action
tells you what happened.

**Put content in it.** Open the book → Re-import EPUB (or upload an EPUB).
Chapters, text and cover are extracted automatically; the banner confirms.
This is the flow the client's team will use every day.

**Audio is optional.** On the same page: leave it empty and the app narrates
with the device voice; the admin reads "TTS only". Upload a clip per chapter
and the app plays that instead — there is a chapter picker for it.

**Analytics → Export Excel.** Downloads the FRS §13 report.

**Delete.** Books → Delete → confirm. Banner confirms.

---

## 3. What to say about production

The platform runs in production configuration: `ENVIRONMENT=production`,
`DEBUG=false`, secrets set; access control, media protection and entitlements
all enforced (verified — anonymous requests are rejected, the admin portal
requires a session, paid content is gated by licence or subscription).

Three things remain before real money and real users:

1. **Domain + HTTPS** — currently `http://100.27.229.125:8080`.
2. **Campay live keys** — payments currently run in sandbox (no real charge).
3. **SMS/email provider** — OTPs currently come back in the API response.

---

## Do not promise (still open)

- **Word-level sync with an uploaded recording.** Uploaded narration plays,
  and highlighting follows it approximately; exact word timing needs alignment
  tooling. Demo it with on-device narration, which is exact.
- **Live card/mobile-money charges** — sandbox only.
- **iOS** — Android only so far.

---

## If something goes wrong on the day

| Symptom | Fix |
|---|---|
| App shows "Could not validate credentials" | Sign out and back in as `demo@lyrr.app` / `demo123` |
| Store is empty | Check `curl http://100.27.229.125:8080/health`; if not 200, restart the API |
| Book takes seconds to open | It is the first open of that title; a downloaded book opens from disk instantly |
| Admin action seems to do nothing | The banner at the top of the page states the outcome |

Server restart, if needed:

```bash
ssh ubuntu@100.27.229.125 'cd lyrr_platform && docker compose up -d --no-build api'
```
