# WebMux Flutter Base Image
# Includes Flutter SDK, Android SDK, and required build tools
FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    wget \
    unzip \
    curl \
    git \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV TAR_OPTIONS=--no-same-owner
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$JAVA_HOME/bin:$FLUTTER_ROOT/bin

# Download and setup Android SDK command-line tools
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools && \
    mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest && \
    rm /tmp/cmdline-tools.zip

# Accept licenses and install required SDK components
RUN yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses || true
RUN $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0"

# Clone and setup Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FLUTTER_ROOT

# Pre-cache Flutter dependencies
RUN flutter precache --android --no-tree-shake-icons || true

# Verify installations
RUN flutter --version
RUN java -version

# Set Flutter to use the installed Android SDK
RUN flutter config --android-sdk=$ANDROID_SDK_ROOT

# Label the image
LABEL maintainer="webmux"
LABEL description="Base image for WebMux Flutter builds with Android SDK 34"
