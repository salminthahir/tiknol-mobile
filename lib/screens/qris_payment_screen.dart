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
  int _remainingSeconds = 0;
  String _paymentStatus = 'PENDING'; // PENDING, PAID, EXPIRED, FAILED
  bool _isChecking = false;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 120; // 10 minutes at 5s intervals

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiryMinutes * 60;
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
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
          _paymentStatus = 'PAID';
          _stopTimers();
          await _playSuccessSound();
          setState(() {});
          // Auto-navigate back after short delay
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context, 'paid');
        } else if (status == PaymentStatus.cancelled ||
            status == PaymentStatus.failed ||
            status == PaymentStatus.expired) {
          _paymentStatus =
              status == PaymentStatus.expired ? 'EXPIRED' : 'FAILED';
          _stopTimers();
          setState(() {});
        }
      } on PaymentCheckException {
        // PV-5: could not verify this tick — keep polling, never assume paid.
      } catch (e) {
        // Silently retry on next tick
      } finally {
        _isChecking = false;
      }
    });
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
  }

  Future<void> _playSuccessSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Ignore sound errors
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

          // Status indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Menunggu pembayaran...',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

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
