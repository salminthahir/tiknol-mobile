import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/server_config_service.dart';
import '../core/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showServerConfig = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadServerUrl();
  }

  Future<void> _loadServerUrl() async {
    final url = await ServerConfigService.getBaseUrl();
    if (mounted) {
      setState(() {
        _serverUrlController.text = url;
      });
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _pinController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      _employeeIdController.text,
      _pinController.text,
    );

    if (success && mounted) {
      context.go('/pos');
    }
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      // Try to reach the health endpoint or root
      final response = await dio.get('/api/health').timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        setState(() => _connectionStatus = 'Terhubung ke server!');
      } else {
        setState(() => _connectionStatus = 'Server merespons tapi status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        setState(() => _connectionStatus = 'Tidak dapat terhubung. Periksa IP dan jaringan.');
      } else {
        setState(() => _connectionStatus = 'Error: ${e.message}');
      }
    } catch (e) {
      setState(() => _connectionStatus = 'Error: $e');
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;
    await ServerConfigService.setBaseUrl(url);
    // Refresh API client base URL
    final apiClient = ref.read(apiClientProvider);
    await apiClient.refreshBaseUrl();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL disimpan'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      resizeToAvoidBottomInset: true,
      body: isTablet ? _buildTabletLayout(auth) : _buildPhoneLayout(auth),
    );
  }

  Widget _buildTabletLayout(AuthState auth) {
    return Row(
      children: [
        // Left: Branding (40%)
        Expanded(
          flex: 2,
          child: Container(
            color: AppColors.darkBg,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'O',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'NOL POS',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TITIK NOL\nCOFFEE RESERVE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 3,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SYSTEM ONLINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ), // Close SingleChildScrollView
        ), // Close Center
        // Right: Form (60%)
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                bottomLeft: Radius.circular(32),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildLoginForm(auth, isTablet: true),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(AuthState auth) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('O',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Staff Access',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('TITIK NOL COFFEE RESERVE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 2)),
              const SizedBox(height: 40),
              _buildLoginForm(auth, isTablet: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthState auth, {required bool isTablet}) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 48 : 0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTablet) ...[
              const Text(
                'Staff Access',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Masukkan kredensial untuk mengakses POS',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 36),
            ],

            // Employee ID
            _label('EMPLOYEE ID'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _employeeIdController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'EMP-001',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                prefixIcon: Icon(Icons.badge_outlined,
                    color: Colors.grey.shade600, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Masukkan Employee ID' : null,
            ),
            const SizedBox(height: 6),
            Text('Masukkan ID karyawan Anda',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            // PIN
            _label('PIN'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 6),
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                prefixIcon: Icon(Icons.lock_outline,
                    color: Colors.grey.shade600, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Masukkan PIN' : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 6),
            Text('PIN 4-6 digit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 12),

            // Error
            if (auth.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(auth.error!,
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Server Config Toggle
            GestureDetector(
              onTap: () => setState(() => _showServerConfig = !_showServerConfig),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showServerConfig ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showServerConfig ? 'Sembunyikan Pengaturan Server' : 'Pengaturan Server',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            if (_showServerConfig) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SERVER URL'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serverUrlController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.100:3000',
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        prefixIcon: Icon(Icons.dns, color: Colors.grey.shade600, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Contoh: http://192.168.1.100:3000 atau https://api.example.com',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isTestingConnection ? null : _testConnection,
                            icon: _isTestingConnection
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Icon(Icons.wifi_tethering, size: 14),
                            label: Text(_isTestingConnection ? 'Testing...' : 'Test Koneksi',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveServerUrl,
                            icon: const Icon(Icons.save, size: 14),
                            label: const Text('Simpan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _connectionStatus!.contains('Terhubung')
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _connectionStatus!.contains('Terhubung')
                                ? AppColors.success.withValues(alpha: 0.4)
                                : AppColors.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _connectionStatus!.contains('Terhubung') ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Login Button
            SizedBox(
              height: isTablet ? 56 : 50,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black))
                    : Text(
                        'LOGIN TO POS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: isTablet ? 15 : 13,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }
}
