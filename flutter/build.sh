#!/bin/bash
set -e

# WebMux Flutter Build Script
# Features:
# - Uses all available CPU cores for parallel compilation
# - Docker layer caching for faster subsequent builds
# - Auto-upload to S3 after successful build

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLUTTER_DIR="$PROJECT_ROOT/flutter"
DOCKER_DIR="$PROJECT_ROOT/docker/flutter"

# S3 configuration
S3_BUCKET="s3://images.bitslovers.com/temp"
S3_KEY="webmux-flutter-debug.apk"

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

# Build the Flutter APK using Docker
echo "Building Flutter APK with Docker..."
echo "  CPU cores: $CPU_CORES"

# Set pipefail to catch docker build failure
set -o pipefail

# Build the image
DOCKER_BUILDKIT=1 docker build \
    -t webmux-flutter-builder:latest \
    -f "$DOCKER_DIR/Dockerfile" \
    "$PROJECT_ROOT" \
    --progress=plain \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    2>&1 | tee /tmp/flutter-build.log

# Check if build was successful
if [ $? -eq 0 ]; then
    # Remove old APK to be sure we get the new one
    rm -f "$PROJECT_ROOT/webmux-flutter-debug.apk"

    # Copy APK to project root
    echo "Copying APK to project root..."
    CONTAINER_ID=$(docker create webmux-flutter-builder:latest)
    docker cp "$CONTAINER_ID:/webmux-flutter-debug.apk" "$PROJECT_ROOT/webmux-flutter-debug.apk"
    docker rm "$CONTAINER_ID"

    if [ -f "$PROJECT_ROOT/webmux-flutter-debug.apk" ]; then
        echo ""
        echo "APK built successfully!"
        ls -lh "$PROJECT_ROOT/webmux-flutter-debug.apk"

        # Cleanup dangling images to save space
        echo "Cleaning up dangling Docker images..."
        docker image prune -f

        # Upload to S3
        echo ""
        echo "Uploading APK to S3..."
        if command -v aws >/dev/null 2>&1; then
            aws s3 cp "$PROJECT_ROOT/webmux-flutter-debug.apk" "$S3_BUCKET/$S3_KEY"
            echo "APK uploaded to $S3_BUCKET/$S3_KEY"
        else
            echo "AWS CLI not found, skipping upload."
        fi
    else
        echo "ERROR: APK was not generated or could not be copied!"
        exit 1
    fi
else
    echo "Build failed! Check /tmp/flutter-build.log for details"
    exit 1
fi
