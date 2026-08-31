#!/bin/bash
# LYRR - Simple start & run
# Ek command mein: infra + backend + (optional) mobile app
set -e
cd "$(dirname "$0")"

echo "🚀 LYRR starting..."

# 1. Infra (PostgreSQL, Redis, MinIO)
echo "▶️ Starting infrastructure..."
cd infrastructure
docker-compose -f docker-compose.local.yml up -d 2>/dev/null || docker compose -f docker-compose.local.yml up -d
cd ..

# 2. Backend venv + deps (pehli baar mein)
cd backend
if [ ! -d "venv" ]; then
  echo "▶️ Creating Python venv..."
  python3 -m venv venv
fi
source venv/bin/activate
pip install -q -r requirements.txt

# 3. Wait for DB + migrate + seed
echo "▶️ Preparing database..."
for i in $(seq 1 30); do
  if docker exec lyrr-db-local pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
docker exec lyrr-db-local psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='lyrr'" | grep -q 1 || docker exec lyrr-db-local psql -U postgres -c "CREATE DATABASE lyrr;"
alembic upgrade head >/dev/null 2>&1 || alembic upgrade head
python seed_data.py 2>/dev/null | tail -2 || true
cd ..

echo ""
echo "✅ Backend: http://localhost:8000"
echo "   Admin:   http://localhost:8000/admin  (admin@lyrr.app / admin123)"
echo "   Docs:    http://localhost:8000/docs"
echo ""

# 4. Start backend (background)
cd backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# 5. Mobile app (agar chahiye)
if [ "$1" = "app" ] || [ "$1" = "mobile" ]; then
  echo "▶️ Starting Flutter app..."
  cd frontend
  flutter pub get >/dev/null 2>&1
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  cd ..
else
  echo "📱 Mobile app ke liye:  ./start.sh app"
  echo "   (Ctrl+C se backend band hoga)"
  wait $BACKEND_PID
fi
