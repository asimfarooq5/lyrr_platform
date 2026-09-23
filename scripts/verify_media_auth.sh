#!/usr/bin/env bash
# Verifies the P0 fix: audio plays with a URL-borne media token, is refused
# without one, and covers remain public.
set -u
API=http://localhost:8000/api/v1
BOOK=989a435b-f73f-4213-8ffa-e1683b1c2e06
EMAIL="mediatest_$(date +%s)@example.com"

echo "== 1. register =="
REG=$(curl -s -X POST "$API/auth/register" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"TestPass123!\",\"first_name\":\"Media\",\"last_name\":\"Test\"}")
echo "$REG" | head -c 200; echo
TOKEN=$(echo "$REG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "register gave no token; trying login"
  TOKEN=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
    -d "{\"username\":\"$EMAIL\",\"password\":\"TestPass123!\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
fi
[ -z "$TOKEN" ] && { echo "FAIL: no access token"; exit 1; }
echo "token acquired: ${TOKEN:0:24}..."
AUTH="Authorization: Bearer $TOKEN"

echo; echo "== 2. purchase book (grants access) =="
curl -s -X POST "$API/books/$BOOK/purchase" -H "$AUTH" | head -c 200; echo

echo; echo "== 3. get license =="
LIC=$(curl -s -X POST "$API/books/$BOOK/license" -H "$AUTH" \
  -H 'Content-Type: application/json' -d '{"device_id":"test-device"}')
echo "$LIC" | head -c 300; echo
DL=$(echo "$LIC" | python3 -c "import sys,json; print(json.load(sys.stdin).get('download_url') or '')" 2>/dev/null)
if [ -z "$DL" ]; then echo "FAIL: no download_url"; exit 1; fi

echo; echo "== 4. download_url carries a media token? =="
case "$DL" in
  *"token="*) echo "PASS: token present";;
  *) echo "FAIL: download_url has no token"; exit 1;;
esac

echo; echo "== 5. GET audio WITH token (expect 200/206) =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' -H 'Range: bytes=0-1023' "$DL")
echo "status: $CODE"
[ "$CODE" = "200" ] || [ "$CODE" = "206" ] && echo "PASS" || echo "FAIL"

echo; echo "== 6. GET audio WITHOUT token (expect 401) =="
BARE=$(echo "$DL" | sed 's/?token=.*$//')
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BARE")
echo "status: $CODE"
[ "$CODE" = "401" ] && echo "PASS" || echo "FAIL (expected 401)"

echo; echo "== 7. tampered token (expect 401) =="
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BARE?token=not.a.real.token")
echo "status: $CODE"
[ "$CODE" = "401" ] && echo "PASS" || echo "FAIL (expected 401)"

echo; echo "== 8. cover image without auth (expect 200) =="
COVER=$(docker exec lyrr-db-local psql -U postgres -d lyrr -tAc \
  "SELECT cover_url FROM books WHERE cover_url IS NOT NULL LIMIT 1;" 2>/dev/null | tr -d '[:space:]')
if [ -n "$COVER" ]; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:8000$COVER")
  echo "cover: $COVER -> $CODE"
  [ "$CODE" = "200" ] && echo "PASS" || echo "FAIL"
else
  echo "no cover in db; skipping"
fi
