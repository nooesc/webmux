# WebMux Android Builder
# Uses the base image with Android SDK and Node.js

# Build from the base image (build this once and cache it)
FROM webmux-android-base:latest AS builder

# Set working directory
WORKDIR /app

# Copy package files first for caching
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the project
COPY . .

# Build the Vue app
RUN npm run build:client

# Sync with Capacitor and build APK
RUN npx cap add android

# Apply network security config for HTTP (cleartext) support
RUN mkdir -p android/app/src/main/res/xml
RUN echo '<?xml version="1.0" encoding="utf-8"?>' > android/app/src/main/res/xml/networksecurity.xml
RUN echo '<network-security-config>' >> android/app/src/main/res/xml/networksecurity.xml
RUN echo '    <base-config cleartextTrafficPermitted="true" />' >> android/app/src/main/res/xml/networksecurity.xml
RUN echo '</network-security-config>' >> android/app/src/main/res/xml/networksecurity.xml

# Update AndroidManifest to use network security config
RUN sed -i 's/android:theme="@style\/AppTheme">/android:theme="@style\/AppTheme" android:usesCleartextTraffic="true" android:networkSecurityConfig="@xml\/networksecurity">/g' android/app/src/main/AndroidManifest.xml

RUN npx cap sync android

# Build the APK using Gradle
RUN cd android && ./gradlew assembleDebug

# Create output directory
RUN mkdir -p /output

# Default command - copy APK to output volume
CMD ["sh", "-c", "cp android/app/build/outputs/apk/debug/*.apk /output/ 2>/dev/null || echo 'APK not found'"]
