import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/server_config_service.dart';
import '../core/api_client.dart';
import 'widgets/outlined_text.dart';

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

  // ---------------------------------------------------------------------------
  // Shared UI atoms (reserve branding)
  // ---------------------------------------------------------------------------

  Widget _navBrand({double fontSize = 18, Color? dotColor}) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: AppColors.reserveOutline,
        ),
        children: [
          TextSpan(text: '.', style: TextStyle(color: dotColor ?? AppColors.reserve)),
          const TextSpan(text: 'NOL'),
        ],
      ),
    );
  }

  Widget _mono(String text,
      {double size = 10, double spacing = 4, Color color = AppColors.reserve, FontWeight w = FontWeight.w700}) {
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        fontSize: size,
        letterSpacing: spacing,
        color: color,
        fontWeight: w,
      ),
    );
  }

  Widget _estBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.reserve, width: 1),
      ),
      child: _mono('EST. 2020', size: 9, spacing: 3),
    );
  }

  /// Reserve heading in the "OUR / OUTLETS" style: solid first line + outlined
  /// second line. Used as the main heading on login.
  Widget _reserveHeading({
    required String solidLine,
    required String outlineLine,
    required double fontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          solidLine,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 0.85,
            color: AppColors.reserveOutline,
          ),
        ),
        OutlinedText(
          outlineLine,
          fontSize: fontSize,
          strokeWidth: 2,
          strokeColor: AppColors.reserveOutline,
        ),
      ],
    );
  }

  /// Grayscale image box ala nol.coffee gallery, with a reserve overlay on
  /// hover/press. Uses [Image.asset] with a grayscale [ColorFilter].
  Widget _galleryBox(String asset, {double height = 220}) {
    return ClipRRect(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              color: Colors.grey, // grayscale base
              colorBlendMode: BlendMode.saturation,
            ),
            Container(color: Colors.black.withValues(alpha: 0.15)),
          ],
        ),
      ),
    );
  }

  /// Yellow quote box ala "COFFEE IS NOT A BEVERAGE. TO THE LAST DROP POINT"
  Widget _quoteBox({double height = 220}) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.reserve,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Text(
        '"COFFEE IS NOT A BEVERAGE.\nTO THE LAST DROP POINT"',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: 1.15,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phone layout
  // ---------------------------------------------------------------------------

  Widget _buildPhoneLayout(AuthState auth) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top bar: brand + est badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navBrand(),
                  _estBadge(),
                ],
              ),
              const SizedBox(height: 40),
              _mono('WELCOME TO THE RESERVE', size: 10, spacing: 3),
              const SizedBox(height: 8),
              _reserveHeading(
                solidLine: 'STAFF',
                outlineLine: 'ACCESS',
                fontSize: 64,
              ),
              const SizedBox(height: 6),
              _mono('TITIK NOL COFFEE RESERVE',
                  size: 10, spacing: 3, color: AppColors.textSecondary),
              const SizedBox(height: 40),
              _buildLoginForm(auth, isTablet: false),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet layout
  // ---------------------------------------------------------------------------

  Widget _buildTabletLayout(AuthState auth) {
    return Row(
      children: [
        // Left: Branding (40%)
        Expanded(
          flex: 2,
          child: Container(
            color: AppColors.reserveSurface,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top: brand + est
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _navBrand(fontSize: 22),
                        _estBadge(),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _mono('WELCOME TO THE RESERVE', size: 11, spacing: 3),
                    const SizedBox(height: 12),
                    // Big reserve heading: TITIK NOL solid + RESERVE. outline
                    _reserveHeading(
                      solidLine: 'TITIK NOL',
                      outlineLine: 'RESERVE.',
                      fontSize: 72,
                    ),
                    const SizedBox(height: 8),
                    _mono('THE LAST DROP POINT', size: 10, spacing: 3),
                    const SizedBox(height: 24),
                    // Gallery grid (2 images + 1 quote)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _galleryBox('assets/images/img_8565.jpg', height: 220)),
                          const SizedBox(width: 8),
                          Expanded(child: _galleryBox('assets/images/img_8587.jpg', height: 220)),
                          const SizedBox(width: 8),
                          Expanded(child: _quoteBox(height: 220)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // System online badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          _mono('SYSTEM ONLINE', size: 11, spacing: 1.5, color: AppColors.success),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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

  // ---------------------------------------------------------------------------
  // Login form
  // ---------------------------------------------------------------------------

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
              // Accent bar top (reserve)
              Container(height: 4, color: AppColors.reserve),
              const SizedBox(height: 24),
              _reserveHeading(
                solidLine: 'STAFF',
                outlineLine: 'ACCESS',
                fontSize: 44,
              ),
              const SizedBox(height: 6),
              _mono('Masukkan kredensial untuk mengakses POS',
                  size: 12, spacing: 1, color: AppColors.textSecondary, w: FontWeight.w400),
              const SizedBox(height: 32),
            ],

            // Employee ID
            _label('EMPLOYEE ID'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _employeeIdController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'EMP-001',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey.shade600, size: 20),
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
                  borderSide: const BorderSide(color: AppColors.reserve, width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Masukkan Employee ID' : null,
            ),
            const SizedBox(height: 6),
            Text('Masukkan ID karyawan Anda',
                style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.grey.shade600)),
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
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 6,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade600),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0A0A0A),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 20),
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
                  borderSide: const BorderSide(color: AppColors.reserve, width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Masukkan PIN' : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 6),
            Text('PIN 4-6 digit',
                style: GoogleFonts.spaceMono(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 12),

            // Error
            if (auth.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(auth.error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    style: GoogleFonts.inter(
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
                          borderSide: const BorderSide(color: AppColors.reserve, width: 2),
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

            // Login Button (reserve, mono, tracking)
            SizedBox(
              height: isTablet ? 56 : 50,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.reserve,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                    : Text(
                        'LOGIN TO POS',
                        style: GoogleFonts.spaceMono(
                          fontWeight: FontWeight.w700,
                          fontSize: isTablet ? 14 : 12,
                          letterSpacing: 3,
                          color: Colors.black,
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
      style: GoogleFonts.spaceMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.reserve,
        letterSpacing: 3,
      ),
    );
  }
}
