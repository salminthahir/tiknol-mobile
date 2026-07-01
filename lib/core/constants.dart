class Constants {
  // Build-time environment. For local development run with:
  //   --dart-define=ENV=development
  // Production builds (default) MUST talk to an HTTPS endpoint.
  static const String env =
      String.fromEnvironment('ENV', defaultValue: 'production');
  static bool get isProduction => env == 'production';
  static bool get isDevelopment => env == 'development';

  // Per-environment default base URL.
  // PV-4: production default is HTTPS; only development may default to a LAN
  // cleartext (HTTP) address. Override at build time with:
  //   --dart-define=API_BASE_URL=https://api.nol.coffee
  static const String _prodDefaultBaseUrl = 'https://api.nol.coffee';
  static const String _devDefaultBaseUrl = 'http://192.168.100.95:3000';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        env == 'production' ? _prodDefaultBaseUrl : _devDefaultBaseUrl,
  );

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  /// PV-4: true if [url] uses a secure (HTTPS) scheme.
  static bool isSecureUrl(String url) =>
      url.toLowerCase().startsWith('https://');

  // Storage Keys
  static const String staffSessionKey = 'staff_session';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String userRoleKey = 'user_role';
  static const String branchIdKey = 'branch_id';
  static const String branchNameKey = 'branch_name';
}
