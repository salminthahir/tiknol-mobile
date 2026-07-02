import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? userId;
  final String? userName;
  final String? role;
  final String? branchId;
  final String? branchName;
  final String? branchCode;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.userId,
    this.userName,
    this.role,
    this.branchId,
    this.branchName,
    this.branchCode,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? userId,
    String? userName,
    String? role,
    String? branchId,
    String? branchName,
    String? branchCode,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      branchCode: branchCode ?? this.branchCode,
      error: error,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _restoreSession());
    return const AuthState(isLoading: true);
  }

  Future<void> _restoreSession() async {
    final authService = ref.read(authServiceProvider);
    final hasToken = await authService.hasSession();
    if (!hasToken) {
      state = const AuthState();
      return;
    }
    final saved = await authService.getSavedSession();
    state = AuthState(
      isLoggedIn: true,
      userId: saved['userId'],
      userName: saved['name'],
      role: saved['role'],
      branchId: saved['branchId'],
      branchName: saved['branchName'],
      branchCode: saved['branchCode'],
    );
  }

  Future<bool> login(String employeeId, String pin) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(employeeId, pin);

      state = AuthState(
        isLoggedIn: true,
        userId: user['userId'],
        userName: user['name'],
        role: user['role'],
        branchId: user['branchId'],
        branchName: user['branchName'],
        branchCode: user['branchCode'],
      );
      return true;
    } on DioException catch (e) {
      String msg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          msg = 'Server tidak merespons (timeout). Periksa koneksi jaringan dan URL server.';
          break;
        case DioExceptionType.connectionError:
          msg = 'Tidak dapat terhubung ke server. Periksa:\n• Apakah WiFi/tablet terhubung ke jaringan yang sama dengan server?\n• Apakah alamat server sudah benar?\n• Apakah server sedang berjalan?';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 401) {
            msg = 'Employee ID atau PIN salah';
          } else if (e.response?.statusCode == 403) {
            msg = 'Akun tidak aktif atau PIN belum diatur';
          } else if (e.response?.statusCode == 429) {
            msg = 'Terlalu banyak percobaan. Coba lagi nanti.';
          } else {
            msg = 'Server error (${e.response?.statusCode}). Coba lagi.';
          }
          break;
        default:
          msg = 'Gagal terhubung ke server. Periksa pengaturan koneksi.';
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      String msg = 'Login gagal';
      final err = e.toString();
      if (err.contains('429')) {
        msg = 'Terlalu banyak percobaan. Coba lagi nanti.';
      } else if (err.contains('401')) {
        msg = 'Employee ID atau PIN salah';
      } else if (err.contains('403')) {
        msg = 'Akun tidak aktif atau PIN belum diatur';
      } else if (err.contains('SocketException') || err.contains('Connection refused')) {
        msg = 'Tidak dapat terhubung ke server. Periksa alamat server dan koneksi jaringan.';
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AuthState();
  }

  Future<void> sessionExpired() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    state = const AuthState(error: 'Sesi habis, silakan login ulang');
  }
}
