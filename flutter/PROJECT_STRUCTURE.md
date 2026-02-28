# WebMux Flutter Project Structure

```
flutter/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # App configuration
│   ├── core/
│   │   ├── config/
│   │   │   └── app_config.dart      # App settings
│   │   ├── constants/
│   │   │   └── app_constants.dart  # App constants
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Theme configuration
│   │   └── utils/
│   │       └── extensions.dart      # Extension methods
│   ├── data/
│   │   ├── models/                  # Data models
│   │   ├── repositories/            # Data repositories
│   │   └── services/                # API/WebSocket services
│   │       ├── supabase_service.dart
│   │       ├── websocket_service.dart
│   │       └── terminal_service.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   └── providers/
│   │   ├── terminal/
│   │   │   ├── screens/
│   │   │   │   └── terminal_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── terminal_view │   │  .dart
│   │   └── mobile_keyboard.dart
│   │   │   └── providers/
│   │   ├── sessions/
│   │   ├── chat/
│   │   ├── cron/
│   │   ├── dotfiles/
│   │   └── system/
│   └── shared/
│       ├── widgets/                 # Shared widgets
│       └── providers/               # Shared providers
├── android/                        # Android config (auto-generated)
├── ios/                            # iOS config (optional)
├── test/                           # Tests
├── pubspec.yaml                    # Dependencies
└── analysis_options.yaml           # Linter config
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `supabase_flutter` | Auth & realtime |
| `xterm` | Terminal emulation UI |
| `flutter_pty` | Native PTY access |
| `web_socket_channel` | WebSocket communication |
| `flutter_webrtc` | Audio streaming |
| `re_editor` | Code editor |
| `shared_preferences` | Local settings |
| `hive` | Local database |

## Running Locally

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## Docker Build

```bash
# Build with Docker
docker build -t webmux-flutter -f docker/flutter/Dockerfile .
```
