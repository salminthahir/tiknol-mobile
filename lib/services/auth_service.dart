import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final Ref ref;
  final _storage = const FlutterSecureStorage();

  AuthService(this.ref);

  Future<Map<String, dynamic>> login(String employeeId, String pin) async {
    final api = ref.read(apiClientProvider);

    final response = await api.client.post(
      '/api/auth/staff/login',
      data: {
        'employeeId': employeeId.toUpperCase(),
        'pin': pin,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final user = response.data['user'] as Map<String, dynamic>;

      // Save user info locally
      await _storage.write(key: Constants.userIdKey, value: user['userId'] ?? '');
      await _storage.write(key: Constants.userNameKey, value: user['name'] ?? '');
      await _storage.write(key: Constants.userRoleKey, value: user['role'] ?? '');
      await _storage.write(key: Constants.branchIdKey, value: user['branchId'] ?? '');
      await _storage.write(key: Constants.branchNameKey, value: user['branchName'] ?? '');
      await _storage.write(key: Constants.branchCodeKey, value: user['branchCode'] ?? '');

      return user;
    }

    throw Exception(response.data['message'] ?? 'Login gagal');
  }

  Future<void> logout() async {
    final api = ref.read(apiClientProvider);
    try {
      await api.client.post('/api/auth/staff/logout');
    } catch (_) {}
    await api.clearSession();
  }

  Future<Map<String, String?>> getSavedSession() async {
    return {
      'userId': await _storage.read(key: Constants.userIdKey),
      'name': await _storage.read(key: Constants.userNameKey),
      'role': await _storage.read(key: Constants.userRoleKey),
      'branchId': await _storage.read(key: Constants.branchIdKey),
      'branchName': await _storage.read(key: Constants.branchNameKey),
      'branchCode': await _storage.read(key: Constants.branchCodeKey),
    };
  }

  Future<bool> hasSession() async {
    final token = await _storage.read(key: Constants.staffSessionKey);
    return token != null && token.isNotEmpty;
  }
}
