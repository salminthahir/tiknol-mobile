import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/auth_provider.dart';
import '../services/server_config_service.dart';
import 'constants.dart';

final apiClientProvider = Provider((ref) => ApiClient(
  onUnauthorized: () => ref.read(authProvider.notifier).sessionExpired(),
));
final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  final Future<void> Function()? onUnauthorized;

  ApiClient({this.onUnauthorized}) {
    // Synchronous init with fallback URL; refreshBaseUrl can update later
    _dio = Dio(
      BaseOptions(
        baseUrl: Constants.baseUrl,
        connectTimeout: const Duration(milliseconds: Constants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: Constants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: Constants.staffSessionKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Cookie'] = 'staff_session=$token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          final setCookie = response.headers['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            for (final raw in setCookie) {
              if (raw.contains('staff_session=')) {
                final match = RegExp(r'staff_session=([^;]+)').firstMatch(raw);
                if (match != null) {
                  final value = match.group(1)!;
                  await _storage.write(key: Constants.staffSessionKey, value: value);
                }
              }
            }
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await clearSession();
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Call once on app startup (or after changing server URL) to override baseUrl from prefs.
  Future<void> refreshBaseUrl() async {
    final baseUrl = await ServerConfigService.getBaseUrl();
    _dio.options.baseUrl = baseUrl;
  }

  Dio get client => _dio;

  Future<void> clearSession() async {
    await _storage.delete(key: Constants.staffSessionKey);
    await _storage.delete(key: Constants.userIdKey);
    await _storage.delete(key: Constants.userNameKey);
    await _storage.delete(key: Constants.userRoleKey);
    await _storage.delete(key: Constants.branchIdKey);
    await _storage.delete(key: Constants.branchNameKey);
  }
}
