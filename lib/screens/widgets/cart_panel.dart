import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/stock_provider.dart';
import '../../services/order_service.dart';
import '../../services/voucher_service.dart';
import '../../services/receipt_service.dart';
import '../../services/printer_service.dart';
import '../../services/receipt_template_service.dart';
import '../../models/cart_item.dart';
import '../../models/payment_status.dart';
import '../../services/pending_payment_service.dart';
import '../payment_webview.dart';
import '../qris_payment_screen.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _ConfirmDialogContent extends StatefulWidget {
  final List<CartItem> cart;
  final String orderType;
  final String paymentType;
  final int total;
  final int finalTotal;
  final int discount;
  final NumberFormat formatter;
  // Shared notifiers so actions row (outside content subtree) can react
  final ValueNotifier<bool> cashValidNotifier;
  final ValueNotifier<int> uangDiterimaNotifier;

  const _ConfirmDialogContent({
    required this.cart,
    required this.orderType,
    required this.paymentType,
    required this.total,
    required this.finalTotal,
    required this.discount,
    required this.formatter,
    required this.cashValidNotifier,
    required this.uangDiterimaNotifier,
  });

  @override
  State<_ConfirmDialogContent> createState() => _ConfirmDialogContentState();
}

class _ConfirmDialogContentState extends State<_ConfirmDialogContent> {
  final _uangDiterimaController = TextEditingController();
  int _uangDiterima = 0;
  int _kembalian = 0;

  @override
  void initState() {
    super.initState();
    _uangDiterimaController.addListener(_onUangDiterimaChanged);
  }

  @override
  void dispose() {
    _uangDiterimaController.dispose();
    super.dispose();
  }

  void _onUangDiterimaChanged() {
    final val = int.tryParse(_uangDiterimaController.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _uangDiterima = val;
      _kembalian = val - widget.finalTotal;
    });
    widget.uangDiterimaNotifier.value = val;
    widget.cashValidNotifier.value = val >= widget.finalTotal;
  }

  void _setQuickAmount(int amount) {
    _uangDiterimaController.text = amount.toString();
  }



  @override
  Widget build(BuildContext context) {
    final isCash = widget.paymentType == 'CASH';
    final isGrab = widget.paymentType == 'GRAB';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${widget.orderType} • ${widget.paymentType}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...widget.cart.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text('${item.qty}x ${item.product.name}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
              Text('Rp ${widget.formatter.format(item.subtotal)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        )),
        const Divider(height: 20, color: Colors.grey),
        if (widget.discount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('Rp ${widget.formatter.format(widget.total)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough)),
            ],
          ),
        if (widget.discount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Diskon', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('-Rp ${widget.formatter.format(widget.discount)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black)),
            Text('Rp ${widget.formatter.format(widget.finalTotal)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
          ],
        ),
        if (isCash) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _uangDiterimaController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Uang Diterima',
              labelStyle: const TextStyle(color: Colors.black54),
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[400]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.reserve, width: 2)),
            ),
          ),
          const SizedBox(height: 8),
          if (_uangDiterima > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _kembalian >= 0 ? 'Kembalian' : 'Kurang',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kembalian >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
                Text(
                  'Rp ${widget.formatter.format(_kembalian.abs())}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kembalian >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((amount) {
              final isExact = amount == widget.finalTotal;
              return ActionChip(
                label: Text(
                  isExact ? 'Uang Pas' : '${(amount ~/ 1000)}rb',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExact ? Colors.white : Colors.black87,
                    fontWeight: isExact ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                backgroundColor: isExact ? AppColors.success : Colors.grey[200],
                side: BorderSide(color: isExact ? AppColors.success : Colors.grey[400]!),
                onPressed: () => _setQuickAmount(amount),
              );
            }).toList(),
          ),
        ],
        if (isGrab) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.grab.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.grab.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining, color: AppColors.grab, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Order masuk via platform online (Grab, GoFood, dll). Pembayaran diterima dari aplikasi.',
                    style: TextStyle(fontSize: 12, color: AppColors.grab, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<int> get _quickAmounts {
    final t = widget.finalTotal;
    final rounded = ((t + 999) ~/ 1000) * 1000;
    // Jika total sudah kelipatan 1000, rounded == t → "Uang Pas" sudah tercakup,
    // jadi tidak perlu ditambahkan lagi sebagai chip terpisah agar tidak duplikat.
    final amounts = <int>[t]; // "Uang Pas" selalu ada di posisi pertama
    if (rounded != t) amounts.insert(0, rounded); // pembulatan ke atas (hanya jika berbeda)
    amounts.addAll([rounded + 10000, rounded + 50000]);
    return amounts;
  }
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final _customerNameController = TextEditingController();
  final _voucherController = TextEditingController();
  final Set<String> _removingItemKeys = {};
  final Set<String> _enteredItemKeys = {};
  final List<Timer> _pendingRemoveTimers = [];
  String _orderType = 'DINE_IN';
  bool _isProcessing = false;
  bool _submitting = false;
  bool _hasAutoPrinted = false;
  bool _showVoucherInput = false;
  VoucherResult? _voucher;
  String? _voucherError;

  void _onRemoveItem(CartItem item) {
    if (item.qty > 1) {
      ref.read(cartProvider.notifier).removeItem(item.key);
      return;
    }
    setState(() => _removingItemKeys.add(item.key));
    final timer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _removingItemKeys.remove(item.key);
        _enteredItemKeys.remove(item.key);
      });
      ref.read(cartProvider.notifier).removeItem(item.key);
    });
    _pendingRemoveTimers.add(timer);
  }

  @override
  void initState() {
    super.initState();
    _refreshPrinterConnection();
  }

  @override
  void dispose() {
    for (final timer in _pendingRemoveTimers) {
      timer.cancel();
    }
    _pendingRemoveTimers.clear();
    _customerNameController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrinterConnection() async {
    final printerService = PrinterService();
    try {
      final ok = await printerService.reconnectToSaved()
          .timeout(const Duration(seconds: 5));
      if (!ok) {
        await printerService.disconnect(); // Clear stale state
      }
    } catch (e) {
      debugPrint('Printer reconnect error: $e');
      await printerService.disconnect();
    }
    if (mounted) setState(() {});
  }

  int get _discount => _voucher?.discount ?? 0;

  Future<void> _validateVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;

    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);

    setState(() {
      _voucherError = null;
    });

    try {
      final voucherService = ref.read(voucherServiceProvider);
      final result = await voucherService.validate(
        code: code,
        cartTotal: total,
        items: cart.map((i) => {'id': i.product.id, 'qty': i.qty}).toList(),
      );

      setState(() {
        if (result.valid) {
          _voucher = result;
          _voucherError = null;
        } else {
          _voucher = null;
          _voucherError = result.errorMessage;
        }
      });
    } catch (e) {
      setState(() {
        _voucherError = 'Gagal validasi voucher';
      });
    }
  }

  Future<void> _processCashPayment({required int uangDiterima}) async {
    // B8: Double-tap prevention — hard guard
    if (_submitting) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada shift aktif. Buka shift terlebih dahulu.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    _hasAutoPrinted = false; // Reset for new transaction
    _submitting = true;
    setState(() => _isProcessing = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      final subtotal = ref.read(cartTotalProvider);
      final finalTotal = subtotal - _discount;

      final order = await orderService.createCashOrder(
        customerName: _customerNameController.text,
        orderType: _orderType,
        items: cart,
        totalAmount: finalTotal,
        subtotal: subtotal,
        discountAmount: _discount,
        shiftId: shiftState.currentShift!.id,
        uangDiterima: uangDiterima,
        voucherId: _voucher?.voucherId,
      );

      final auth = ref.read(authProvider);
      await ref.read(shiftProvider.notifier).refreshExpectedCash();

      // Deduct stok permanen sesuai qty yang terjual
      await ref.read(stockProvider.notifier).deductForCart(
        cart.map((item) => (productId: item.product.id, qty: item.qty)).toList(),
      );

      // Clear cart
      ref.read(cartProvider.notifier).clear();
      _customerNameController.clear();
      _voucherController.clear();
      setState(() {
        _voucher = null;
        _voucherError = null;
        _isProcessing = false;
      });

      if (mounted) {
        final isTablet = MediaQuery.sizeOf(context).width > 600;
        if (!isTablet && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showSuccessDialog(
          order['id'] ?? '',
          items: cart,
          total: finalTotal,
          paymentType: 'CASH',
          subtotal: subtotal,
          discount: _discount,
          cashierName: auth.userName ?? 'Staff',
          branchName: auth.branchName ?? '',
          customerName: _customerNameController.text,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      _submitting = false;
    }
  }

  Future<void> _processGrabOrder() async {
    if (_submitting) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada shift aktif. Buka shift terlebih dahulu.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    _hasAutoPrinted = false;
    _submitting = true;
    setState(() => _isProcessing = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      final subtotal = ref.read(cartTotalProvider);
      final finalTotal = subtotal - _discount;

      final order = await orderService.createCashOrder(
        customerName: _customerNameController.text,
        orderType: _orderType,
        items: cart,
        totalAmount: finalTotal,
        subtotal: subtotal,
        discountAmount: _discount,
        shiftId: shiftState.currentShift!.id,
        uangDiterima: finalTotal, // GRAB: uang diterima = total (tidak ada kembalian)
        voucherId: _voucher?.voucherId,
        paymentType: 'GRAB',
      );

      final auth = ref.read(authProvider);
      // GRAB tidak mempengaruhi kas fisik — tidak perlu refresh expected cash

      await ref.read(stockProvider.notifier).deductForCart(
        cart.map((item) => (productId: item.product.id, qty: item.qty)).toList(),
      );

      ref.read(cartProvider.notifier).clear();
      _customerNameController.clear();
      _voucherController.clear();
      setState(() {
        _voucher = null;
        _voucherError = null;
        _isProcessing = false;
      });

      if (mounted) {
        final isTablet = MediaQuery.sizeOf(context).width > 600;
        if (!isTablet && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showSuccessDialog(
          order['id'] ?? '',
          items: cart,
          total: finalTotal,
          paymentType: 'GRAB',
          subtotal: subtotal,
          discount: _discount,
          cashierName: auth.userName ?? 'Staff',
          branchName: auth.branchName ?? '',
          customerName: _customerNameController.text,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      _submitting = false;
    }
  }

  Future<void> _processOnlinePayment() async {
    // B8: Double-tap prevention — hard guard
    if (_submitting) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada shift aktif. Buka shift terlebih dahulu.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    _hasAutoPrinted = false; // Reset for new transaction
    _submitting = true;
    setState(() => _isProcessing = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      final subtotal = ref.read(cartTotalProvider);
      final finalTotal = subtotal - _discount;

      final clientTxnId = 'qris_${DateTime.now().millisecondsSinceEpoch}';

      // Create payment (backend auto-picks QRIS)
      final result = await orderService.createOnlinePayment(
        customerName: _customerNameController.text,
        orderType: _orderType,
        items: cart,
        subtotal: subtotal,
        discountAmount: _discount,
        branchId: ref.read(authProvider).branchId ?? '',
        voucherId: _voucher?.voucherId,
        shiftId: shiftState.currentShift!.id,
        clientTransactionId: clientTxnId,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final orderId = result['orderId'] ?? '';
      final qrString = result['qrString'] ?? '';
      final amount = int.tryParse(result['amount'] ?? '0') ?? finalTotal;
      final expiryPeriod = int.tryParse(result['expiryPeriod'] ?? '10') ?? 10;

      // Show the payment screen (QRIS or WebView fallback). Neither screen is
      // trusted to decide success — see PV-1/PV-2. Their return value is only a
      // hint that the user is done; the authoritative status comes from the
      // server verification below.
      String? paymentResult;
      if (qrString.isNotEmpty) {
        paymentResult = await Navigator.push<String?>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => QrisPaymentScreen(
              orderId: orderId,
              qrString: qrString,
              amount: amount,
              expiryMinutes: expiryPeriod,
              customerName: _customerNameController.text.isEmpty
                  ? 'Customer POS'
                  : _customerNameController.text,
            ),
          ),
        );
      } else {
        // Fallback to WebView if qrString not available
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaymentWebView(
              paymentUrl: result['paymentUrl'] ?? '',
              orderId: orderId,
            ),
          ),
        );
      }

      if (!mounted) return;

      // Handle postpone (pending) explicitly: keep order alive, save QR locally,
      // don't clear cart, and skip server verification.
      if (paymentResult == 'pending') {
        await PendingPaymentService.savePendingPayment(
          PendingPayment(
            orderId: orderId,
            qrString: qrString,
            amount: amount,
            expiryMinutes: expiryPeriod,
            customerName: _customerNameController.text.isEmpty
                ? 'Customer POS'
                : _customerNameController.text,
            createdAt: DateTime.now(),
          ),
        );
        setState(() => _isProcessing = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran ditunda. Order tetap aktif.'),
            backgroundColor: AppColors.primary,
          ),
        );
        return;
      }

      // PV-1/PV-2: verify the real payment status with the backend before
      // treating the transaction as paid. Only an explicit PAID clears the cart
      // and prints the receipt.
      final verified = await _verifyPaymentWithServer(orderId);
      if (!mounted) return;

      // Clean up any local pending record once we've reached a final check.
      await PendingPaymentService.removePendingPayment(orderId);

      if (verified == PaymentStatus.paid) {
        final auth = ref.read(authProvider);

        // Deduct stok permanen sesuai qty yang terjual
        await ref.read(stockProvider.notifier).deductForCart(
          cart.map((item) => (productId: item.product.id, qty: item.qty)).toList(),
        );

        ref.read(cartProvider.notifier).clear();
        _customerNameController.clear();
        setState(() {
          _voucher = null;
          _isProcessing = false;
        });
        _showSuccessDialog(
          orderId,
          items: cart,
          total: finalTotal,
          paymentType: 'QRIS',
          subtotal: subtotal,
          discount: _discount,
          cashierName: auth.userName ?? 'Staff',
          branchName: auth.branchName ?? '',
          customerName: _customerNameController.text,
        );
      } else {
        // Not proven paid. Cancel the pending order (best-effort) and inform
        // the cashier. We never assume success on an unverified/pending state.
        if (orderId.isNotEmpty &&
            verified != PaymentStatus.pending &&
            verified != PaymentStatus.unknown) {
          await orderService.cancelOrder(orderId);
        }
        setState(() => _isProcessing = false);
        if (mounted) {
          String msg;
          if (paymentResult == 'expired') {
            msg = 'QR Code kedaluwarsa. Order telah dibatalkan.';
          } else if (paymentResult == 'cancelled') {
            msg = 'Pembayaran dibatalkan.';
          } else if (verified == PaymentStatus.pending ||
              verified == PaymentStatus.unknown) {
            msg = 'Pembayaran belum terkonfirmasi. Cek ulang status sebelum menutup.';
          } else {
            msg = 'Pembayaran dibatalkan';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      _submitting = false;
    }
  }

  /// Verifies payment status with the backend with a short retry window.
  ///
  /// PV-5: fails closed — network/parse errors are retried, and an
  /// unconfirmed result returns [PaymentStatus.pending] rather than assuming
  /// success. Only an explicit non-pending status is returned early.
  Future<PaymentStatus> _verifyPaymentWithServer(String orderId) async {
    if (orderId.isEmpty) return PaymentStatus.unknown;
    final orderService = ref.read(orderServiceProvider);
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final status = await orderService.checkPaymentStatus(orderId);
        if (status != PaymentStatus.pending) return status;
      } on PaymentCheckException {
        // Could not verify this attempt — retry.
      } catch (_) {
        // Defensive: never let an unexpected error be read as success.
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    // Could not prove payment within the window — treat as pending (NOT paid).
    return PaymentStatus.pending;
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('503') || msg.contains('timeout') || msg.contains('Timeout')) {
      return 'Server tidak merespons. Coba lagi.';
    }
    if (msg.contains('401')) return 'Sesi habis. Silakan login ulang.';
    if (msg.contains('400')) return 'Data order tidak valid.';
    if (msg.contains('429')) return 'Terlalu banyak percobaan. Tunggu sebentar.';
    return 'Terjadi kesalahan. Coba lagi.';
  }

  Future<void> _showConfirmDialog(String paymentType) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final total = ref.read(cartTotalProvider);
    final finalTotal = total - _discount;
    final formatter = NumberFormat('#,###', 'id');

    final isCash = paymentType == 'CASH';
    final isGrab = paymentType == 'GRAB';

    final uangDiterimaResult = await showDialog<int?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cashValidNotifier = ValueNotifier<bool>(false);
        final uangDiterimaNotifier = ValueNotifier<int>(0);

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isGrab ? Icons.delivery_dining : Icons.receipt_long,
                color: isGrab ? AppColors.grab : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text('Konfirmasi Pembayaran',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
            ],
          ),
          content: SingleChildScrollView(
            child: _ConfirmDialogContent(
              cart: cart,
              orderType: _orderType,
              paymentType: paymentType,
              total: total,
              finalTotal: finalTotal,
              discount: _discount,
              formatter: formatter,
              cashValidNotifier: cashValidNotifier,
              uangDiterimaNotifier: uangDiterimaNotifier,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isCash ? cashValidNotifier : ValueNotifier(true),
              builder: (context, isValid, child) {
                return ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.pop(ctx, isCash ? uangDiterimaNotifier.value : 0)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid
                        ? (isGrab ? AppColors.grab : AppColors.success)
                        : Colors.grey[300],
                    foregroundColor: isValid ? Colors.white : Colors.grey[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isGrab ? 'Catat Order' : 'Konfirmasi Bayar',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                );
              },
            ),
          ],
        );
      },
    );

    if (uangDiterimaResult != null) {
      if (paymentType == 'CASH') {
        await _processCashPayment(uangDiterima: uangDiterimaResult);
      } else if (paymentType == 'GRAB') {
        await _processGrabOrder();
      } else {
        await _processOnlinePayment();
      }
    }
  }

  void _showSuccessDialog(
    String orderId, {
    required List<CartItem> items,
    required int total,
    required String paymentType,
    required int subtotal,
    required int discount,
    required String cashierName,
    required String branchName,
    String? customerName,
  }) {
    final formatter = NumberFormat('#,###', 'id');
    final printerService = PrinterService();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          bool isPrinting = false;
          String? printStatus;

          Future<void> doPrint() async {
            setState(() => isPrinting = true);
            try {
              final template = await ReceiptTemplateService.load();
              final bytes = await ReceiptGenerator.generateEscPosBytes(
                orderId: orderId,
                items: items,
                subtotal: subtotal,
                discount: discount,
                total: total,
                paymentType: paymentType,
                cashierName: cashierName,
                branchName: branchName,
                customerName: customerName,
                template: template,
              );
              await printerService.sendBytes(bytes.toList());
              setState(() {
                isPrinting = false;
                printStatus = 'Struk berhasil dicetak';
              });
            } catch (e) {
              setState(() {
                isPrinting = false;
                printStatus = 'Gagal cetak: $e';
              });
            }
          }

          // Auto-print once on dialog open (class-level flag prevents loop)
          if (!_hasAutoPrinted && printerService.isConnected) {
            _hasAutoPrinted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => doPrint());
          }

          return AlertDialog(
            backgroundColor: AppColors.posCartBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(24),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                  const SizedBox(height: 16),
                  Text('Pembayaran Berhasil!',
                      style: GoogleFonts.spaceMono(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('#$orderId',
                      style: GoogleFonts.spaceMono(fontSize: 12, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (paymentType == 'GRAB' ? AppColors.grab : AppColors.success).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (paymentType == 'GRAB' ? AppColors.grab : AppColors.success).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (paymentType == 'GRAB') ...[ 
                          const Icon(Icons.delivery_dining, size: 14, color: AppColors.grab),
                          const SizedBox(width: 4),
                        ],
                        Text(paymentType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: paymentType == 'GRAB' ? AppColors.grab : AppColors.success,
                            )),
                      ],
                    ),
                  ),
                  // Printer status
                  const SizedBox(height: 12),
                  StreamBuilder<bool>(
                    stream: printerService.connectionState,
                    initialData: printerService.isConnected,
                    builder: (ctx, snapshot) {
                      final connected = snapshot.data ?? false;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: connected
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: connected ? AppColors.success : AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              connected
                                  ? 'Printer: ${printerService.connectedDeviceName ?? 'Terhubung'}'
                                  : 'Printer tidak terhubung',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: connected ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  // Print status
                  if (printStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      printStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: printStatus!.contains('berhasil') ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                  // Receipt items
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.posBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.posDivider),
                    ),
                    child: Column(
                      children: [
                        ...items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('${item.qty}x ${item.product.name}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('Rp ${formatter.format(item.subtotal)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        )),
                        const Divider(height: 12, color: AppColors.posDivider),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                            Text('Rp ${formatter.format(total)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!printerService.isConnected)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showPrinterConnectionDialog(setState),
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text('Atur Printer', style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700, letterSpacing: 2)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.reserve,
                      side: const BorderSide(color: AppColors.reserve),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (printerService.isConnected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isPrinting ? null : doPrint,
                    icon: isPrinting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.print, size: 16),
                    label: Text(isPrinting ? 'Mencetak...' : 'Cetak Struk', style: GoogleFonts.spaceMono(fontWeight: FontWeight.w900, letterSpacing: 2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.reserve,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.reserve,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('OK', style: GoogleFonts.spaceMono(fontWeight: FontWeight.w900, letterSpacing: 3)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPrinterConnectionDialog(StateSetter parentSetState) {
    final printerService = PrinterService();

    List<Map<String, dynamic>> devices = [];
    bool isScanning = true;
    bool isConnecting = false;
    String? connectingId;
    String? errorMsg;
    bool loaded = false;

    Future<void> doScan(StateSetter setS, BuildContext ctx) async {
      setS(() { isScanning = true; errorMsg = null; });
      try {
        final all = await printerService.scanAllDevices(
          timeout: const Duration(seconds: 8),
          filterPrinter: true,
        );
        if (!ctx.mounted) return;
        setS(() { devices = all; isScanning = false; });
      } catch (e) {
        if (!ctx.mounted) return;
        setS(() { isScanning = false; errorMsg = 'Gagal scan: $e'; });
      }
    }

    Future<void> loadBonded(StateSetter setS, BuildContext ctx) async {
      try {
        final bonded = await printerService.getBondedDevices(filterPrinter: true);
        if (!ctx.mounted) return;
        if (bonded.isNotEmpty) {
          setS(() { devices = bonded; isScanning = false; });
        } else if (ctx.mounted) {
          // No bonded devices — scan for nearby printers
          doScan(setS, ctx);
        }
      } catch (e) {
        if (!ctx.mounted) return;
        // Failed to load bonded — try scan
        doScan(setS, ctx);
      }
    }

    Future<void> doConnect(StateSetter setS, Map<String, dynamic> device, BuildContext ctx) async {
      setS(() { isConnecting = true; connectingId = device['id'] as String; errorMsg = null; });
      bool ok = false;
      try {
        if (device['type'] == 'ble' && device['device'] is BluetoothDevice) {
          ok = await printerService.connectBle(device['device'] as BluetoothDevice);
        } else if (device['type'] == 'classic') {
          ok = await printerService.connectClassic(device['id'] as String, device['name'] as String);
        }
      } catch (_) { ok = false; }

      if (ok && ctx.mounted) {
        Navigator.of(ctx).pop();
        parentSetState(() {});
      } else if (ctx.mounted) {
        setS(() { isConnecting = false; connectingId = null; errorMsg = 'Gagal menghubungkan ke printer'; });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setS) {
          if (!loaded) {
            loaded = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => loadBonded(setS, dialogCtx));
          }

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) printerService.stopScan();
            },
            child: AlertDialog(
              backgroundColor: AppColors.posCartBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(LucideIcons.printer, color: AppColors.reserve, size: 20),
                  const SizedBox(width: 8),
                  Text('Pilih Printer', style: GoogleFonts.spaceMono(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 11)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isScanning && devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.reserve)),
                            SizedBox(height: 8),
                            Text('Memuat printer...', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      )
                    else if (devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(LucideIcons.printer, size: 32, color: Colors.white30),
                            SizedBox(height: 8),
                            Text('Tidak ada printer ditemukan', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            Text('Pastikan Bluetooth aktif & printer ter-pair', style: TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: Column(
                            children: List.generate(devices.length, (i) {
                              final d = devices[i];
                              final isConnectingThis = isConnecting && connectingId == d['id'];
                              return Column(
                                children: [
                                  if (i > 0) const Divider(color: AppColors.posDivider, height: 1),
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.printer, size: 16, color: Colors.white54),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(d['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                              Text(d['type'].toString().toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                            ],
                                          ),
                                        ),
                                        isConnectingThis
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.reserve))
                                          : ElevatedButton(
                                              onPressed: isConnecting ? null : () => doConnect(setS, d, dialogCtx),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.reserve,
                                                foregroundColor: Colors.black,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              child: const Text('Hubungkan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    if (!isScanning) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => doScan(setS, dialogCtx),
                        icon: const Icon(LucideIcons.refreshCw, size: 14, color: AppColors.reserve),
                        label: const Text('Scan Printer', style: TextStyle(fontSize: 11, color: AppColors.reserve)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Batal', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final finalTotal = total - _discount;
    final formatter = NumberFormat('#,###', 'id');
    final hasStockIssue = ref.watch(cartHasStockIssueProvider);



    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.reserve, width: 4),
          ),
        ),
        child: SafeArea(
          child: Container(
            color: AppColors.posCartBg,
            child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.posCardBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORDER LIST',
                        style: GoogleFonts.spaceMono(
                            fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white)),
                    const SizedBox(height: 10),
                    // Action row: order type + voucher + trash
                    Row(
                      children: [
                        _orderTypeChip('DINE IN', 'DINE_IN'),
                        const SizedBox(width: 6),
                        _orderTypeChip('TAKE AWAY', 'TAKE_AWAY'),
                        const Spacer(),
                        if (cart.isNotEmpty) ...[
                          // Voucher toggle button
                          GestureDetector(
                            onTap: () => setState(() => _showVoucherInput = !_showVoucherInput),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _showVoucherInput ? AppColors.reserve.withValues(alpha: 0.15) : AppColors.posBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _showVoucherInput ? AppColors.reserve : AppColors.posDivider,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.ticket,
                                      size: 13,
                                      color: _showVoucherInput ? AppColors.reserve : Colors.white54),
                                  const SizedBox(width: 4),
                                  Text('Voucher',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _showVoucherInput ? AppColors.reserve : Colors.white54,
                                      )),
                                ],
                              ),
                            ),
                          ),
                          // Clear cart
                          GestureDetector(
                            onTap: () {
                              ref.read(cartProvider.notifier).clear();
                              _customerNameController.clear();
                              setState(() {
                                _voucher = null;
                                _voucherError = null;
                                _showVoucherInput = false;
                                _enteredItemKeys.clear();
                                _removingItemKeys.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.trash2,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

            // Expandable Voucher Input
            if (cart.isNotEmpty && _showVoucherInput && _voucher == null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                color: AppColors.posCartBg,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        textCapitalization: TextCapitalization.characters,
                        keyboardType: TextInputType.text,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Kode Voucher',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: AppColors.posBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          suffixIcon: _voucherController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                  onPressed: () {
                                    _voucherController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.posDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.posDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.reserve, width: 1.5),
                          ),
                          errorText: _voucherError,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: _validateVoucher,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.reserve,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Apply',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),

            // Cart Items
            Expanded(
              child: cart.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          
                          // Icon reserve circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.reserve.withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              LucideIcons.shoppingBag,
                              size: 36,
                              color: AppColors.reserve,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Heading
                          Text(
                            'EMPTY ORDER',
                            style: GoogleFonts.spaceMono(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Subtext
                          Text(
                            'Tap produk untuk memulai pesanan',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Order type label
                          Text(
                            'ORDER TYPE',
                            style: GoogleFonts.spaceMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                              color: AppColors.reserve,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Order type chips
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _orderTypeChip('DINE IN', 'DINE_IN'),
                              const SizedBox(width: 8),
                              _orderTypeChip('TAKE AWAY', 'TAKE_AWAY'),
                            ],
                          ),
                          
                           const SizedBox(height: 32),
                           
                           // Ready badge
                           Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.reserve.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'READY TO START',
                              style: GoogleFonts.spaceMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        final isRemoving = _removingItemKeys.contains(item.key);
                        final isNew = !_enteredItemKeys.contains(item.key);

                        if (isNew) {
                          _enteredItemKeys.add(item.key);
                        }

                        Widget tile = _CartItemTile(
                          item: item,
                          onRemoveRequest: _onRemoveItem,
                        );

                        if (isNew) {
                          tile = TweenAnimationBuilder<double>(
                            key: ValueKey('enter_${item.key}'),
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: tile,
                          );
                        }

                        if (isRemoving) {
                          tile = TweenAnimationBuilder<double>(
                            key: ValueKey('exit_${item.key}'),
                            tween: Tween(begin: 1.0, end: 0.0),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: ClipRect(
                                  child: Align(
                                    heightFactor: value,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: tile,
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: tile,
                        );
                      },
                    ),
            ),

            // Customer name
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nama Pelanggan (opsional)',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white30,
                    ),
                    prefixIcon: const Icon(Icons.person, size: 18, color: Colors.white54),
                    suffixIcon: _customerNameController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                            onPressed: () {
                              _customerNameController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.posBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.posDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.posDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.reserve, width: 1.5),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

            // Voucher applied badge (stays near footer)
            if (cart.isNotEmpty && _voucher != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.posCardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.ticket,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_voucher!.voucherCode} (-Rp ${formatter.format(_discount)})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _voucher = null;
                          _voucherController.clear();
                        }),
                        child: const Icon(Icons.close, size: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Footer - Total & Pay
            if (cart.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: AppColors.posCardBg,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.reserve.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    if (_discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal',
                              style: GoogleFonts.spaceMono(
                                  color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          Text('Rp ${formatter.format(total)}',
                              style: GoogleFonts.spaceMono(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('TOTAL',
                            style: GoogleFonts.spaceMono(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 16)),
                        Text(
                          'Rp ${formatter.format(finalTotal)}',
                          style: GoogleFonts.spaceMono(
                              color: AppColors.reserve,
                              fontWeight: FontWeight.w900,
                              fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasStockIssue)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stok tidak mencukupi untuk beberapa item. Kurangi qty atau hapus item.',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  (_isProcessing || hasStockIssue) ? null : () => _showConfirmDialog('CASH'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.reserve,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black))
                                  : Text('CASH',
                                      style: GoogleFonts.spaceMono(
                                          fontWeight: FontWeight.w900, letterSpacing: 3)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  (_isProcessing || hasStockIssue) ? null : () => _showConfirmDialog('QRIS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('QRIS',
                                  style: GoogleFonts.spaceMono(
                                      fontWeight: FontWeight.w900, letterSpacing: 3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isProcessing || hasStockIssue) ? null : () => _showConfirmDialog('GRAB'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.grab,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.delivery_dining, size: 20),
                        label: Text('GRAB',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.w900, letterSpacing: 3)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _orderTypeChip(String label, String value) {
    final isActive = _orderType == value;
    return GestureDetector(
      onTap: () => setState(() => _orderType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.reserve : AppColors.posBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.reserve : AppColors.posDivider,
            width: isActive ? 1.5 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: isActive ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final void Function(CartItem item)? onRemoveRequest;

  const _CartItemTile({required this.item, this.onRemoveRequest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'id');

    // Stok persisten produk ini
    final persistedStock = ref.watch(stockByIdProvider(item.product.id));
    // Total qty produk ini di cart (semua varian)
    final totalInCart = ref.watch(cartProductQtyProvider(item.product.id));
    // Tombol + disabled jika sudah mencapai stok persisten
    final addDisabled = totalInCart >= persistedStock;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.posCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.posDivider,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.selectedTemp != null || item.selectedSize != null)
                  Text(
                    [item.selectedTemp, item.selectedSize]
                        .where((e) => e != null)
                        .join(' - '),
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 4),
                Text('Rp ${formatter.format(item.subtotal)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  if (item.qty <= 1 && onRemoveRequest != null) {
                    onRemoveRequest!(item);
                  } else {
                    ref.read(cartProvider.notifier).removeItem(item.key);
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('${item.qty}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
              ),
              _QtyButton(
                icon: Icons.add,
                disabled: addDisabled,
                onTap: addDisabled
                    ? null
                    : () => ref.read(cartProvider.notifier).addItem(
                          item.product,
                          temp: item.selectedTemp,
                          size: item.selectedSize,
                          maxQty: persistedStock,
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _QtyButton({required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: disabled ? AppColors.posBg.withValues(alpha: 0.4) : AppColors.posBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled
                ? AppColors.posDivider.withValues(alpha: 0.3)
                : AppColors.posDivider,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? Colors.white24 : Colors.white70,
        ),
      ),
    );
  }
}
