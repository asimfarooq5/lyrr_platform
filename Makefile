# LYRR Platform - Makefile
# 
# Quick commands for development

.PHONY: help setup start stop test lint format clean

# Default target
help:
	@echo "LYRR Platform - Available Commands"
	@echo "=================================="
	@echo ""
	@echo "Setup:"
	@echo "  make setup         - Run full local setup"
	@echo "  make setup-infra   - Start infrastructure services only"
	@echo ""
	@echo "Development:"
	@echo "  make start         - Start all services (infra + backend)"
	@echo "  make stop          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo ""
	@echo "Backend:"
	@echo "  make backend       - Start backend server only (requires infra)"
	@echo "  make migrate       - Run database migrations"
	@echo "  make shell         - Open backend Python shell"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests"
	@echo "  make test-backend  - Run backend tests"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint          - Run linters"
	@echo "  make format        - Format code"
	@echo "  make typecheck     - Run type checker"
	@echo ""
	@echo "Flutter:"
	@echo "  make flutter       - Run Flutter app"
	@echo "  make admin         - Run Admin portal"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean         - Clean up containers and volumes"
	@echo "  make clean-all     - Clean everything including virtual env"

# Setup
setup:
	./scripts/setup-local.sh

setup-infra:
	@echo "🐳 Starting infrastructure..."
	cd infrastructure && docker-compose -f docker-compose.local.yml up -d
	@echo "⏳ Waiting for services..."
	@sleep 5
	@echo "✓ Infrastructure ready"

# Development
start: setup-infra
	@echo "🔧 Starting backend..."
	cd backend && source venv/bin/activate && uvicorn app.main:app --reload

stop:
	@echo "🛑 Stopping services..."
	cd infrastructure && docker-compose -f docker-compose.local.yml down
	@echo "✓ Services stopped"

restart: stop start

# Backend
backend:
	cd backend && source venv/bin/activate && uvicorn app.main:app --reload

migrate:
	cd backend && source venv/bin/activate && alembic upgrade head

shell:
	cd backend && source venv/bin/activate && ipython

# Testing
test: test-backend

test-backend:
	cd backend && source venv/bin/activate && pytest -v

# Code Quality
lint:
	cd backend && source venv/bin/activate && flake8 app
	cd backend && source venv/bin/activate && mypy app

format:
	cd backend && source venv/bin/activate && black app
	cd backend && source venv/bin/activate && isort app

typecheck:
	cd backend && source venv/bin/activate && mypy app

# Flutter
flutter:
	cd frontend && flutter run

admin:
	cd admin && flutter run -d chrome

# Cleanup
clean:
	cd infrastructure && docker-compose -f docker-compose.local.yml down -v
	@echo "✓ Containers and volumes removed"

clean-all: clean
	cd backend && rm -rf venv __pycache__ .pytest_cache
	@echo "✓ Everything cleaned"
