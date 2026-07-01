// test/unit/auth/auth_provider_test.dart
// Unit tests untuk AuthNotifier (AUTH-03, AUTH-04, AUTH-05)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/services/auth_service.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:dio/dio.dart';
import '../../helpers/mock_services.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late ProviderContainer container;
  late _MockAuthService mockAuthService;
  late MockApiClient mockApiClient;

  setUp(() {
    mockAuthService = _MockAuthService();
    mockApiClient = MockApiClient();

    // Stub hasSession & getSavedSession karena AuthNotifier.build memanggilnya via microtask
    when(() => mockAuthService.hasSession()).thenAnswer((_) async => false);
    when(() => mockAuthService.getSavedSession()).thenAnswer((_) async => {});

    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuthService),
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthState', () {
    test('default state: not logged in, not loading', () {
      const state = AuthState();
      expect(state.isLoggedIn, false);
      expect(state.isLoading, false);
      expect(state.userId, isNull);
      expect(state.error, isNull);
    });

    test('copyWith preserves values when null', () {
      const state = AuthState(isLoggedIn: true, userId: 'U1');
      final updated = state.copyWith(error: 'some error');
      expect(updated.isLoggedIn, true);
      expect(updated.userId, 'U1');
      expect(updated.error, 'some error');
    });

    test('copyWith can override values', () {
      const state = AuthState(isLoggedIn: true);
      final updated = state.copyWith(isLoggedIn: false);
      expect(updated.isLoggedIn, false);
    });
  });

  group('AuthNotifier.login', () {
    test('AUTH-01: login sukses → state isLoggedIn = true', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => {
                'userId': 'U123',
                'name': 'Budi',
                'role': 'STAFF',
                'branchId': 'B1',
                'branchName': 'HQ',
              });

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.login('EMP001', '1234');

      expect(result, true);
      final state = container.read(authProvider);
      expect(state.isLoggedIn, true);
      expect(state.userId, 'U123');
      expect(state.userName, 'Budi');
      expect(state.role, 'STAFF');
      expect(state.branchId, 'B1');
      expect(state.branchName, 'HQ');
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('AUTH-02: login 401 → error message sesuai', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: ''),
            ),
          ));

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.login('EMP001', 'wrongpin');

      expect(result, false);
      final state = container.read(authProvider);
      expect(state.isLoading, false);
      expect(state.error, contains('Employee ID atau PIN salah'));
    });

    test('AUTH-02: login 403 → akun tidak aktif', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 403,
              requestOptions: RequestOptions(path: ''),
            ),
          ));

      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');

      final state = container.read(authProvider);
      expect(state.error, contains('Akun tidak aktif'));
    });

    test('AUTH-02: connection timeout → timeout message', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ));

      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');

      final state = container.read(authProvider);
      expect(state.error, contains('timeout'));
      expect(state.error, contains('Server tidak merespons'));
    });

    test('AUTH-02: connection error → periksa koneksi', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionError,
          ));

      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');

      final state = container.read(authProvider);
      expect(state.error, contains('Tidak dapat terhubung ke server'));
    });

    test('AUTH-02: 429 rate limit → terlalu banyak percobaan', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 429,
              requestOptions: RequestOptions(path: ''),
            ),
          ));

      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');

      final state = container.read(authProvider);
      expect(state.error, contains('Terlalu banyak percobaan'));
    });

    test('AUTH-02: generic exception → catch-all error', () async {
      when(() => mockAuthService.login(any(), any()))
          .thenThrow(Exception('random error'));

      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');

      final state = container.read(authProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('Login gagal'));
    });
  });

  group('AuthNotifier.logout', () {
    test('AUTH-05: logout → state reset ke default', () async {
      // Setup: login dulu
      when(() => mockAuthService.login(any(), any()))
          .thenAnswer((_) async => {'userId': 'U1', 'name': 'A', 'role': 'S', 'branchId': 'B1', 'branchName': 'HQ'});
      final notifier = container.read(authProvider.notifier);
      await notifier.login('EMP001', '1234');
      expect(container.read(authProvider).isLoggedIn, true);

      // Logout
      when(() => mockAuthService.logout()).thenAnswer((_) async {});
      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.isLoggedIn, false);
      expect(state.userId, isNull);
      expect(state.error, isNull);
    });
  });

  group('AuthNotifier.sessionExpired', () {
    test('AUTH-04: sessionExpired → state cleared with error message', () async {
      when(() => mockAuthService.logout()).thenAnswer((_) async {});

      final notifier = container.read(authProvider.notifier);
      await notifier.sessionExpired();

      final state = container.read(authProvider);
      expect(state.isLoggedIn, false);
      expect(state.error, contains('Sesi habis'));
    });
  });
}
