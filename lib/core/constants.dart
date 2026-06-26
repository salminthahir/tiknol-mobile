class Constants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.29:3000',
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
}
