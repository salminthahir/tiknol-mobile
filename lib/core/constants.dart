class Constants {
  // Production: https://api.nol.coffee
  // Development: http://192.168.1.29:3000 (or local IP)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nol.coffee',
  );
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  // Storage Keys
  static const String staffSessionKey = 'staff_session';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userRoleKey = 'user_role';
  static const String branchIdKey = 'branch_id';
  static const String branchNameKey = 'branch_name';

  // Environment flag (set via --dart-define=ENV=production)
  static const String env = String.fromEnvironment('ENV', defaultValue: 'production');
  static bool get isProduction => env == 'production';
  static bool get isDevelopment => env == 'development';
}