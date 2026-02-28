class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'WebMux';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrl = 'http://192.168.0.76:4010';
  static const String wsBaseUrl = 'ws://192.168.0.76:4010/ws';

  // Terminal
  static const int terminalCols = 80;
  static const int terminalRows = 24;
  static const double terminalFontSize = 14.0;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Storage Keys
  static const String keyHosts = 'hosts';
  static const String keySelectedHost = 'selected_host';
  static const String keyThemeMode = 'theme_mode';
  static const String keyTerminalFontSize = 'terminal_font_size';
}
