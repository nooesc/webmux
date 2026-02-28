#!/bin/bash
set -e

IMAGE_NAME="webmux-android-builder"
BASE_IMAGE_NAME="webmux-android-base"
CONTAINER_NAME="webmux-build-$$"
OUTPUT_DIR="output"

echo "=========================================="
echo "WebMux Android APK Builder"
echo "=========================================="

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

# Step 1: Build base image (only if not exists)
echo ""
echo "Step 1: Building/Loading base image..."
echo "=========================================="
if docker image inspect "$BASE_IMAGE_NAME:latest" > /dev/null 2>&1; then
    echo "Base image '$BASE_IMAGE_NAME:latest' already exists, skipping build."
    echo "To rebuild base image, run: docker rmi $BASE_IMAGE_NAME:latest"
else
    echo "Building base image (this may take a few minutes on first run)..."
    docker build -t "$BASE_IMAGE_NAME:latest" -f docker/android-base/Dockerfile docker/android-base/
    echo "Base image built successfully!"
fi

# Step 2: Build the builder image
echo ""
echo "Step 2: Building Android APK..."
echo "=========================================="
docker build -t "$IMAGE_NAME" .

# Step 3: Run container to extract APK
echo ""
echo "Step 3: Extracting APK..."
echo "=========================================="
docker run --rm --name "$CONTAINER_NAME" \
    -v "$(pwd)/$OUTPUT_DIR:/output" \
    "$IMAGE_NAME" \
    sh -c "
        cd /app && \
        npx cap sync android && \
        cp android/app/build/outputs/apk/debug/*.apk /output/ 2>/dev/null || \
        cp android/app/build/outputs/apk/*.apk /output/ 2>/dev/null || \
        echo 'ERROR: No APK found'
    "

# Step 4: Show result
echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="

if [ -f "$OUTPUT_DIR"/*.apk ]; then
    APK=$(ls -lh "$OUTPUT_DIR"/*.apk | head -1 | awk '{print $NF}')
    echo "APK Location: $(pwd)/$APK"
    echo "APK Size: $(du -h "$APK" | cut -f1)"
    echo ""
    echo "To install on Android device:"
    echo "  adb install $APK"
    echo "Or transfer the file to your phone and install manually."
else
    echo "ERROR: APK was not generated!"
    echo "Check the build logs above for errors."
    exit 1
fi
