class AppConstants {
  AppConstants._();

  // Session Types
  static const String sessionTypeTmux = 'tmux';
  static const String sessionTypeScreen = 'screen';

  // Message Types
  static const String msgTypeSessionList = 'session_list';
  static const String msgTypeWindowList = 'window_list';
  static const String msgTypeTerminalData = 'terminal_data';
  static const String msgTypeTerminalResize = 'terminal_resize';
  static const String msgTypeCronList = 'cron_list';
  static const String msgTypeDotfilesList = 'dotfiles_list';
  static const String msgTypeSystemStats = 'system_stats';
  static const String msgTypeChatMessage = 'chat_message';

  // WebSocket Events
  static const String eventConnect = 'connect';
  static const String eventDisconnect = 'disconnect';
  static const String eventError = 'error';

  // Storage
  static const String boxSettings = 'settings';
  static const String boxHosts = 'hosts';
  static const String boxSessions = 'sessions';

  // Limits
  static const int maxSessionNameLength = 50;
  static const int maxWindowNameLength = 50;
  static const int maxCronJobs = 100;
  static const int maxDotfiles = 1000;
}
