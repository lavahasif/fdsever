class AppConstants {
  static const String appName = 'FDServer';
  static const String appVersion = '5.0.0';

  // Default network configuration
  static const String defaultPort = '8081';
  static const String defaultFavPort = '8069';
  static const String defaultFavIp = '127.0.0.1';
  static const String defaultTimeoutMs = '5000';
  static const String defaultTimeout2Ms = '5000';

  // SharedPreferences keys
  static const String prefFavPort = 'fav_port';
  static const String prefFavIp = 'fav_ip';
  static const String prefTimeout = 'fav_timeout';
  static const String prefTimeout2 = 'fav2_timeout';
  static const String prefDeleteAfterUpload = 'delete_after_upload';
  static const String prefThemeMode = 'app_theme_mode';
  static const String prefWhatsAppMessage = 'whatsapp_message';
  static const String prefNotes = 'saved_notes';
  static const String prefTutorials = 'saved_tutorials';
  static const String prefRecentNumbers = 'recent_whatsapp_numbers';
  static const String prefKeepScreenOn = 'keep_screen_on';
  static const String prefKeepCpuAwake = 'keep_cpu_awake';

  // Common scanned ports
  static const List<int> defaultScanPorts = [80, 443, 8069, 8080, 8081, 1433, 3000, 5000];
}
