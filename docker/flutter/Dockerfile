# WebMux Flutter Builder
# Stage 1: Build the APK
FROM webmux-flutter-base:latest AS builder

WORKDIR /app
COPY flutter/ ./

# Get dependencies
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

# Build debug APK
RUN --mount=type=cache,target=/root/.pub-cache \
    --mount=type=cache,target=/root/.gradle \
    --mount=type=cache,target=/app/flutter/build \
    flutter build apk --debug

# Stage 2: Minimal image just to hold the artifact
FROM alpine:latest
COPY --from=builder /app/build/app/outputs/flutter-apk/app-debug.apk /webmux-flutter-debug.apk
CMD ["sh", "-c", "echo 'APK is ready at /webmux-flutter-debug.apk'"]
