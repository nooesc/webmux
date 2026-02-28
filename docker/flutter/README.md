# WebMux Flutter Build Setup

This directory contains Dockerfiles for building a native Flutter Android app.

## Structure

```
docker/flutter/
├── Dockerfile          # Flutter app builder
├── docker-compose.yml # Docker Compose for building
└── README.md          # This file

# Base image (separate build)
docker/flutter-base/
└── Dockerfile        # Base image with Flutter SDK + Android SDK
```

## Prerequisites

1. Create a Flutter project in the `flutter/` directory at project root
2. The project should have a standard Flutter structure with:
   - `pubspec.yaml`
   - `lib/` directory with source code
   - `android/` directory for Android-specific configuration

## Quick Start

### Option 1: Build Base Image (One-time)

```bash
cd docker/flutter-base
docker build -t webmux-flutter-base:latest .
```

### Option 2: Build APK

```bash
# Using docker-compose
cd docker/flutter
docker-compose build flutter-builder

# Or directly
docker build -t webmux-flutter-builder -f Dockerfile ../..
```

### Option 3: Development Mode

For development with hot reload:

```bash
# Run Flutter base container with volume mount
docker run -it --rm \
  -v /path/to/project/flutter:/app \
  -p 5900:5900 \
  -p 5037:5037 \
  webmux-flutter-base:latest \
  bash
```

## Environment Variables

The base image sets:
- `FLUTTER_ROOT=/opt/flutter`
- `ANDROID_SDK_ROOT=/opt/android-sdk`
- `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`

## Output

The built APK will be in:
- `flutter-output/` (docker volume)
- Or `/output/webmux-flutter-debug.apk` inside the container

## Next Steps

1. Create Flutter project: `flutter create --org com.webmux --project-name webmux webmux`
2. Add required dependencies to `pubspec.yaml`
3. Implement features (see assessment plan for complexity)
4. Build with Docker or locally
