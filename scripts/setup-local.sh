#!/bin/bash
# LYRR Platform - Local Development Setup Script
# 
# This script sets up the local development environment
# Usage: ./scripts/setup-local.sh

set -e

echo "🚀 LYRR Platform - Local Development Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed. Please install Python 3.11+ first.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo -e "${GREEN}✓ Python version: $PYTHON_VERSION${NC}"

# Create virtual environment if it doesn't exist
echo ""
echo "📦 Setting up Python virtual environment..."
cd backend

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${YELLOW}⚠ Virtual environment already exists${NC}"
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
echo ""
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# Install core dependencies
echo ""
echo "📥 Installing core dependencies..."
pip install -r requirements.txt

# Install development dependencies
echo ""
echo "📥 Installing development dependencies..."
pip install -r requirements-dev.txt

echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Go back to root
cd ..

# Start local infrastructure
echo ""
echo "🐳 Starting local infrastructure (PostgreSQL, Redis, MinIO)..."
cd infrastructure
docker-compose -f docker-compose.local.yml up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if PostgreSQL is ready
echo ""
echo "🔍 Checking PostgreSQL..."
until docker exec lyrr-db-local pg_isready -U postgres > /dev/null 2>&1; do
    echo "  Waiting for PostgreSQL..."
    sleep 2
done
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

# Check if Redis is ready
echo ""
echo "🔍 Checking Redis..."
until docker exec lyrr-redis-local redis-cli ping > /dev/null 2>&1; do
    echo "  Waiting for Redis..."
    sleep 2
done
echo -e "${GREEN}✓ Redis is ready${NC}"

# Check if MinIO is ready
echo ""
echo "🔍 Checking MinIO..."
until curl -f http://localhost:9000/minio/health/live > /dev/null 2>&1; do
    echo "  Waiting for MinIO..."
    sleep 2
done
echo -e "${GREEN}✓ MinIO is ready${NC}"

cd ..

# Create .env file if it doesn't exist
echo ""
echo "📝 Setting up environment configuration..."

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo -e "${GREEN}✓ .env file created from .env.example${NC}"
    echo -e "${YELLOW}⚠ Please edit .env file with your configuration${NC}"
else
    echo -e "${YELLOW}⚠ .env file already exists${NC}"
fi

# Update .env for local development
echo ""
echo "🔧 Configuring local environment..."
sed -i 's|DATABASE_URL=.*|DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/lyrr|' .env
sed -i 's|REDIS_URL=.*|REDIS_URL=redis://localhost:6379/0|' .env
sed -i 's|S3_ENDPOINT=.*|S3_ENDPOINT=http://localhost:9000|' .env

echo -e "${GREEN}✓ Environment configured for local development${NC}"

# Run database migrations
echo ""
echo "🗄️ Running database migrations..."
cd backend
source venv/bin/activate

# Wait a bit more for database to be fully ready
sleep 5

# Create database if it doesn't exist
docker exec lyrr-db-local psql -U postgres -c "CREATE DATABASE lyrr;" 2>/dev/null || true

# Run migrations
alembic upgrade head || echo -e "${YELLOW}⚠ Migration failed. You may need to run 'alembic upgrade head' manually${NC}"

cd ..

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Local development setup complete!${NC}"
echo ""
echo "📋 Next steps:"
echo "   1. Edit .env file with your configuration"
echo "   2. Start the backend: cd backend && source venv/bin/activate && uvicorn app.main:app --reload"
echo "   3. Access API docs: http://localhost:8000/docs"
echo "   4. Access MinIO console: http://localhost:9001 (minioadmin/minioadmin)"
echo ""
echo "🐳 Infrastructure services:"
echo "   PostgreSQL: localhost:5432"
echo "   Redis: localhost:6379"
echo "   MinIO: localhost:9000 (console: 9001)"
echo ""
echo "📱 To run the Flutter app:"
echo "   cd frontend && flutter pub get && flutter run"
echo ""
echo "🌐 To run the Admin portal:"
echo "   cd admin && flutter pub get && flutter run -d chrome"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
