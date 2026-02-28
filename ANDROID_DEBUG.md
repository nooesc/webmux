# WebMux Android App - Build & Debug Notes

## Problem
Android WebView couldn't connect to the backend server at `192.168.0.76:4010`. The error was:
- WebSocket error code 1006 (connection failed)
- HTTP connectivity test failed ("Failed to fetch")

While the browser worked fine on the same device.

## Root Cause
Android 9+ (API 28+) blocks cleartext (HTTP) traffic by default for security reasons. Even though:
- `android:usesCleartextTraffic="true"` was set in the manifest
- The `networksecurity.xml` file existed

The critical piece was **missing**: the `android:networkSecurityConfig` attribute in the `<application>` tag that references the config file.

## Solution
Modified the Dockerfile to programmatically add the network security config after `cap add android`:

```dockerfile
# Apply network security config for HTTP (cleartext) support
RUN mkdir -p android/app/src/main/res/xml
RUN echo '<?xml version="1.0" encoding="utf-8"?>' > android/app/src/main/res/xml/networksecurity.xml
RUN echo '<network-security-config>' >> android/app/src/main/res/xml/networksecurity.xml
RUN echo '    <base-config cleartextTrafficPermitted="true" />' >> android/app/src/main/res/xml/networksecurity.xml
RUN echo '</network-security-config>' >> android/app/src/main/res/xml/networksecurity.xml

# Update AndroidManifest to use network security config
RUN sed -i 's/android:theme="@style\/AppTheme">/android:theme="@style\/AppTheme" android:usesCleartextTraffic="true" android:networkSecurityConfig="@xml\/networksecurity">/g' android/app/src/main/AndroidManifest.xml
```

## Files Modified
- `Dockerfile` - Added network security config setup after `cap add android`

## APK Verification
To verify the network config is in the APK:
```bash
unzip -l output/app-debug.apk | grep networksecurity
```

Should show: `res/xml/networksecurity.xml`

## Build & Upload
```bash
# Build APK
docker build --no-cache -t webmux-android-builder -f Dockerfile .
docker cp $(docker create webmux-android-builder:latest):/app/android/app/build/outputs/apk/debug/app-debug.apk output/app-debug.apk

# Upload to S3
aws s3 cp output/app-debug.apk s3://images.bitslovers.com/temp/app-debug.apk
```

## Debug Screen
The app includes a debug screen (tap lock icon) with:
- WebSocket URL display
- Test HTTP Connection button
- Server info (connected clients)
- Device & network info
- Connection log with timestamps

This helps diagnose connectivity issues.
