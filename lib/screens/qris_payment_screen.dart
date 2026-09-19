import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../models/payment_status.dart';
import '../services/order_service.dart';

class QrisPaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String qrString;
  final int amount;
  final int expiryMinutes;
  final String customerName;

  const QrisPaymentScreen({
    super.key,
    required this.orderId,
    required this.qrString,
    required this.amount,
    required this.expiryMinutes,
    required this.customerName,
  });

  @override
  ConsumerState<QrisPaymentScreen> createState() => _QrisPaymentScreenState();
}

class _QrisPaymentScreenState extends ConsumerState<QrisPaymentScreen> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _manualButtonTimer;
  int _remainingSeconds = 0;
  String _paymentStatus = 'PENDING'; // PENDING, PAID, EXPIRED, FAILED
  bool _isChecking = false;
  bool _manualRefreshInProgress = false;
  bool _showManualButton = false;
  bool _isSubmittingManual = false;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 120; // 10 minutes at 5s intervals
  
  // ANTI-SPAM FIELDS
  final Set<String> _recentChecks = {}; // Track recent checks per device
  static const int checkWindowMs = 3000; // Only allow new check if > 3 seconds passed
  static const int maxRecentChecks = 10; // Max 10 rapid checks window
  
  // LAST CHECK TIMESTAMPS
  DateTime? _lastCheckedAt;
  DateTime _cooldownEndTime = DateTime(1); // Never in cooldown initially
  
  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiryMinutes * 60;
    _startCountdown();
    _startPolling();

    // Munculkan tombol setelah 10 detik polling tanpa status PAID
    _manualButtonTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _paymentStatus == 'PENDING') {
        setState(() => _showManualButton = true);
      }
    });
  }

  @override
  void dispose() {
    _manualButtonTimer?.cancel();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        _paymentStatus = 'EXPIRED';
        _stopTimers();
        _cancelOrder();
        setState(() {});
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  // ✅ ANTI-SPAM CHECK: Validate before allowing manual check
  bool _canCheckPayment() {
    final now = DateTime.now();
    
    // Check 1: Is still in cooldown period from last check?
    if (now.isBefore(_cooldownEndTime)) {
      return false;
    }
    
    // Check 2: Clean up old entries (older than window)
    _recentChecks.removeWhere((timestamp) => 
      now.difference(DateTime.parse(timestamp)).inMilliseconds > checkWindowMs
    );
    
    // Check 3: Are we at max rapid checks already?
    return _recentChecks.length < maxRecentChecks;
  }

  void _recordRecentCheck() {
    // Record timestamp of this check
    _recentChecks.add(DateTime.now().toIso8601String());
  }

  void _setCooldown(int seconds) {
    _cooldownEndTime = DateTime.now().add(Duration(seconds: seconds));
  }

  // ✅ FIXED: Manual Check Handler with Anti-Spam Protection
  // FIX #1: Set cooldown BEFORE API call to prevent race condition
  // FIX #2: Remove dialog showing after result received (causes loop)
  Future<void> _manualCheck() async {
    // ANTI-SPAM: Reject if spam detection triggered
    if (!_canCheckPayment()) {
      _showSpamWarning();
      return;
    }
    
    if (_paymentStatus != 'PENDING' || _manualRefreshInProgress) {
      return;
    }

    // Set cooldown IMMEDIATELY to prevent rapid taps
    _recordRecentCheck();
    _setCooldown(2); // Increased to 2 seconds for safety
    
    setState(() => _manualRefreshInProgress = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      final status = await orderService.checkPaymentStatus(widget.orderId);

      if (!mounted) return;

      // Clear previous snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      setState(() => _lastCheckedAt = DateTime.now());

      if (status == PaymentStatus.paid) {
        _handlePaymentSuccess();
      } else {
        // Just show status, NO additional loading indicator (avoid recursion)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status: ${status.name.toUpperCase()}'),
            backgroundColor: Colors.blue.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } on PaymentCheckException catch (e) {
      // Keep polling - fail-closed pattern
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memeriksa: ${e.message}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _manualRefreshInProgress = false);
      }
    }
  }

  // ANTI-SPAM WARNING DIALOG
  void _showSpamWarning() {
    final remaining = _cooldownEndTime.difference(DateTime.now()).inSeconds;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Mohon Tunggu...',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Silakan tunggu $remaining s sebelum memeriksa ulang.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Memeriksa terlalu sering dapat membebani sistem.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _paymentStatus != 'PENDING' || _isChecking) return;
      if (_pollAttempts >= _maxPollAttempts) {
        _paymentStatus = 'EXPIRED';
        _stopTimers();
        _cancelOrder();
        setState(() {});
        return;
      }

      _isChecking = true;
      _pollAttempts++;

      try {
        final orderService = ref.read(orderServiceProvider);
        final status = await orderService.checkPaymentStatus(widget.orderId);

        if (!mounted) return;

        if (status == PaymentStatus.paid) {
          _handlePaymentSuccess();
        } else if (status == PaymentStatus.cancelled ||
            status == PaymentStatus.failed ||
            status == PaymentStatus.expired) {
          _handleFailure(status);
        }
        // On exception: continue polling (fail-closed)
      } catch (e) {
        // Silently retry next tick
      } finally {
        if (mounted) {
          setState(() => _isChecking = false);
        }
      }
    });
  }

  void _handlePaymentSuccess() {
    _paymentStatus = 'PAID';
    _stopTimers();
    _playSuccessSound();
    _showSuccessFeedback();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context, 'paid');
    });
  }

  void _handleFailure(PaymentStatus status) {
    _paymentStatus = status == PaymentStatus.expired ? 'EXPIRED' : 'FAILED';
    _stopTimers();
    setState(() {});
  }

  void _showSuccessFeedback() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Pembayaran Berhasil!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Total: Rp ${NumberFormat('#,###', 'id').format(widget.amount)}',
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _manualButtonTimer?.cancel();
  }

  Future<void> _playSuccessSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Ignore sound errors
    }
  }

  Future<void> _showManualConfirmDialog() async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Konfirmasi Manual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan Anda telah melihat bukti pembayaran dari e-wallet/m-banking pelanggan.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text('Order ID: ${widget.orderId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Total: Rp ${NumberFormat('#,###', 'id').format(widget.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Contoh: Terlihat berhasil di DANA pelanggan',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Konfirmasi Pembayaran'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeManualConfirm(noteController.text);
    }
  }

  Future<void> _executeManualConfirm(String note) async {
    setState(() => _isSubmittingManual = true);
    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.manuallyConfirmPayment(
        orderId: widget.orderId,
        note: note,
      );

      if (!mounted) return;

      _stopTimers();
      _paymentStatus = 'PAID';

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pembayaran dikonfirmasi manual'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      // Pop kembali dengan status 'paid', cart_panel akan otomatis menangani cetak struk & clear cart
      Navigator.pop(context, 'paid');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal konfirmasi: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingManual = false);
    }
  }

  Future<void> _cancelOrder() async {
    try {
      final orderService = ref.read(orderServiceProvider);
      await orderService.cancelOrder(widget.orderId);
    } catch (_) {
      // Best effort
    }
  }

  Future<void> _onPendingExit() async {
    _stopTimers();
    Navigator.pop(context, 'pending');
  }

  Future<void> _onCancelExit() async {
    _stopTimers();
    await _cancelOrder();
    if (!mounted) return;
    Navigator.pop(context, 'cancelled');
  }

  Future<bool> _showExitDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tutup Pembayaran QRIS?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Pilih tindakan untuk order ini. Order yang ditunda tetap bisa dibayar nanti.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pending'),
            child: Text(
              'Tunda',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelled'),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == 'pending') {
      await _onPendingExit();
      return false;
    } else if (choice == 'cancelled') {
      await _onCancelExit();
      return false;
    }
    return true; // User dismissed dialog — stay on screen
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'id');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            await _showExitDialog();
          },
        ),
        title: Text(
          'QRIS Payment',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () async {
              await _showExitDialog();
            },
          ),
        ],
      ),
      body: _paymentStatus == 'PENDING'
          ? _buildPendingState(formatter)
          : _buildResultState(formatter),
    );
  }

  Widget _buildPendingState(NumberFormat formatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Order info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${widget.orderId.length > 8 ? widget.orderId.substring(widget.orderId.length - 8) : widget.orderId}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.customerName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rp ${formatter.format(widget.amount)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: widget.qrString,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) {
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'QR Code Error',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan QR dengan e-wallet Anda',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GoPay, OVO, DANA, ShopeePay, LinkAja, dll',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Countdown timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _remainingSeconds < 60
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: _remainingSeconds < 60 ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_remainingSeconds),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: _remainingSeconds < 60 ? AppColors.danger : AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'menit',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: _remainingSeconds < 60 ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Status indicator + LAST CHECKED TIMESTAMP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isChecking || _manualRefreshInProgress)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                _isChecking || _manualRefreshInProgress 
                    ? 'Sedang memeriksa...' 
                    : 'Menunggu pembayaran...',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // ✅ NEW: Last Checked Timestamp
          if (_lastCheckedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Terakhir diperiksa: ${_formatTimestamp(_lastCheckedAt!)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ✅ IMPROVED: Manual Check Button (WITH ANTI-SPAM)
          if (_paymentStatus == 'PENDING')
            _buildManualCheckButton(),

          if (_showManualButton && _paymentStatus == 'PENDING') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSubmittingManual ? null : _showManualConfirmDialog,
              icon: _isSubmittingManual
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                    )
                  : const Icon(Icons.help_outline, size: 18),
              label: Text(_isSubmittingManual ? 'Memproses...' : 'Pelanggan sudah membayar?'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons: Tunda / Batal
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _onPendingExit(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Tunda',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _onCancelExit(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualCheckButton() {
    // FIX #4: Add explicit check for manual refresh in progress
    if (_manualRefreshInProgress) {
      return OutlinedButton(
        onPressed: null, // Disabled
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: Colors.grey.shade400),
          backgroundColor: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Sedang memeriksa...',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    // Check cooldown period
    final now = DateTime.now();
    final cooldownRemaining = _cooldownEndTime.difference(now);
    
    if (cooldownRemaining.inMilliseconds > 0) {
      return OutlinedButton(
        onPressed: null, // Disabled
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: Colors.grey.shade400),
          backgroundColor: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Icon(
                Icons.timer_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Tunggu ${cooldownRemaining.inSeconds}s lagi...',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    // Check anti-spam from rapid taps
    if (!_canCheckPayment()) {
      return OutlinedButton(
        onPressed: null, // Disabled
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: Colors.grey.shade400),
          backgroundColor: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Terlalu sering tap!',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    // Normal enabled state
    return ElevatedButton.icon(
      onPressed: _manualCheck,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Periksa Sekarang'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResultState(NumberFormat formatter) {
    final isExpired = _paymentStatus == 'EXPIRED';
    final isFailed = _paymentStatus == 'FAILED' || _paymentStatus == 'CANCELLED';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isExpired || isFailed
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpired
                    ? Icons.timer_off_outlined
                    : isFailed
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                size: 40,
                color: isExpired || isFailed ? AppColors.danger : AppColors.success,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              isExpired
                  ? 'QR Code Kedaluwarsa'
                  : isFailed
                      ? 'Pembayaran Gagal'
                      : 'Pembayaran Berhasil',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isExpired
                  ? 'Silakan buat transaksi baru'
                  : isFailed
                      ? 'Terjadi kesalahan saat memproses pembayaran'
                      : 'Rp ${formatter.format(widget.amount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (isExpired) {
                    Navigator.pop(context, 'expired');
                  } else if (isFailed) {
                    Navigator.pop(context, 'cancelled');
                  } else {
                    Navigator.pop(context, 'paid');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired || isFailed ? Colors.grey.shade200 : AppColors.primary,
                  foregroundColor: isExpired || isFailed ? AppColors.textPrimary : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isExpired || isFailed ? 'Kembali' : 'Selesai',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
