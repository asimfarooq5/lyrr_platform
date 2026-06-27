#!/bin/bash
# LYRR Platform - Start Local Development
# 
# Usage: ./scripts/start-local.sh

set -e

echo "🚀 Starting LYRR Platform (Local Development)"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Start infrastructure
echo ""
echo "🐳 Starting infrastructure services..."
cd infrastructure
docker-compose -f docker-compose.local.yml up -d

# Wait for services
echo ""
echo "⏳ Waiting for services..."
sleep 5

# Check PostgreSQL
until docker exec lyrr-db-local pg_isready -U postgres > /dev/null 2>&1; do
    echo "  Waiting for PostgreSQL..."
    sleep 2
done
echo -e "${GREEN}✓ PostgreSQL ready${NC}"

# Check Redis
until docker exec lyrr-redis-local redis-cli ping > /dev/null 2>&1; do
    echo "  Waiting for Redis..."
    sleep 2
done
echo -e "${GREEN}✓ Redis ready${NC}"

cd ..

# Start backend
echo ""
echo "🔧 Starting backend server..."
cd backend
source venv/bin/activate

# Create database if not exists
docker exec lyrr-db-local psql -U postgres -c "CREATE DATABASE lyrr;" 2>/dev/null || true

# Run migrations
echo "Running database migrations..."
alembic upgrade head || echo -e "${YELLOW}⚠ Migration may have already run${NC}"

# Start server
echo ""
echo -e "${GREEN}✓ Starting FastAPI server on http://localhost:8000${NC}"
echo "  API Docs: http://localhost:8000/docs"
echo "  Press Ctrl+C to stop"
echo ""

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
