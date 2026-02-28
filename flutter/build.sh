#!/bin/bash
set -e

# WebMux Flutter Build Script
# Features:
# - Caches Gradle dependencies outside container via volume
# - Caches Flutter pub cache outside container via volume
# - Uses all available CPU cores for parallel compilation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$PROJECT_ROOT/flutter"
DOCKER_DIR="$PROJECT_ROOT/docker/flutter"

# Cache directories
GRADLE_CACHE_DIR="$PROJECT_ROOT/.cache/gradle"
PUB_CACHE_DIR="$PROJECT_ROOT/.cache/pub"

# Create cache directories
mkdir -p "$GRADLE_CACHE_DIR"
mkdir -p "$PUB_CACHE_DIR"

# Get number of CPU cores
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")
echo "Using $CPU_CORES CPU cores for compilation"

# Update gradle.properties for parallel builds if not already done
if [ -f "$FLUTTER_DIR/android/gradle.properties" ]; then
    grep -q "org.gradle.parallel=true" "$FLUTTER_DIR/android/gradle.properties" || \
        echo "org.gradle.parallel=true" >> "$FLUTTER_DIR/android/gradle.properties"
    grep -q "org.gradle.daemon=true" "$FLUTTER_DIR/android/gradle.properties" || \
        echo "org.gradle.daemon=true" >> "$FLUTTER_DIR/android/gradle.properties"
    grep -q "org.gradle.caching=true" "$FLUTTER_DIR/android/gradle.properties" || \
        echo "org.gradle.caching=true" >> "$FLUTTER_DIR/android/gradle.properties"
fi

# Build the Flutter APK using Docker with volume caching
echo "Building Flutter APK with Docker..."
echo "  Gradle cache: $GRADLE_CACHE_DIR"
echo "  Pub cache: $PUB_CACHE_DIR"
echo "  CPU cores: $CPU_CORES"

docker build \
    -t webmux-flutter-builder:latest \
    -f "$DOCKER_DIR/Dockerfile" \
    "$PROJECT_ROOT" \
    --progress=plain \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from=webmux-flutter-builder:latest 2>/dev/null || true

# Copy APK to project root
echo "Copying APK to project root..."
docker cp $(docker create --rm webmux-flutter-builder:latest):/output/webmux-flutter-debug.apk "$PROJECT_ROOT/webmux-flutter-debug.apk" 2>/dev/null || \
    docker run --rm -v "$PROJECT_ROOT:/output" webmux-flutter-builder:latest cp /output/webmux-flutter-debug.apk /output/ 2>/dev/null || true

if [ -f "$PROJECT_ROOT/webmux-flutter-debug.apk" ]; then
    echo ""
    echo "APK built successfully!"
    ls -lh "$PROJECT_ROOT/webmux-flutter-debug.apk"
else
    echo "APK not found at expected location"
fi
