#!/bin/bash
# LYRR Platform - Build Script
#
# Builds all platform targets
# Usage: ./scripts/build.sh [android|ios|windows|admin|all]
set -e

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "${1:-all}" in
  android|all)
    echo -e "${GREEN}Building Android APK...${NC}"
    cd frontend
    flutter build apk --release 2>&1 | tail -1
    cp build/app/outputs/flutter-apk/app-release.apk ../dist/lyrr-android.apk 2>/dev/null || true
    cd "$DIR"
    echo -e "${GREEN}✓ Android APK: dist/lyrr-android.apk${NC}"
    ;;
esac

case "${1:-all}" in
  ios|all)
    echo -e "${YELLOW}⚠ iOS build requires macOS with Xcode${NC}"
    echo "  Run: cd frontend && flutter build ios --release"
    echo "  Then open build/ios/archive/LYRR.xcarchive in Xcode for TestFlight"
    ;;
esac

case "${1:-all}" in
  windows|all)
    echo -e "${YELLOW}⚠ Windows build requires Windows with Visual Studio${NC}"
    echo "  Run: cd frontend && flutter build windows --release"
    echo "  Output: build/windows/runner/Release/"
    ;;
esac

case "${1:-all}" in
  admin|all)
    echo -e "${GREEN}Building Admin Portal (Web)...${NC}"
    cd admin
    flutter build web --release 2>&1 | tail -1
    cp -r build/web ../dist/admin-portal 2>/dev/null || true
    cd "$DIR"
    echo -e "${GREEN}✓ Admin Portal: dist/admin-portal/${NC}"
    ;;
esac

case "${1:-all}" in
  backend|all)
    echo -e "${GREEN}Building Docker image...${NC}"
    cd backend
    docker build -t lyrr-api:latest -f Dockerfile.simple . 2>&1 | tail -1
    cd "$DIR"
    echo -e "${GREEN}✓ Docker image: lyrr-api:latest${NC}"
    ;;
esac

echo ""
echo -e "${GREEN}Build complete. Outputs in dist/${NC}"
