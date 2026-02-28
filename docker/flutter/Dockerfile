# WebMux Flutter Builder
# Builds the Flutter Android app from source

# Build from the Flutter base image
FROM webmux-flutter-base:latest AS builder

# Set working directory
WORKDIR /app

# Copy Flutter project files
COPY flutter/ ./

# Get dependencies - use local pub cache from host
RUN flutter pub get

# Build debug APK with parallel compilation
RUN flutter build apk --debug

# Create output directory
RUN mkdir -p /output

# Copy APK to output
RUN cp build/app/outputs/flutter-apk/app-debug.apk /output/webmux-flutter-debug.apk

# Default command - APK is already copied to output
CMD ["sh", "-c", "echo 'Flutter APK built successfully'"]
