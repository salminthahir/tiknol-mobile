import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/voucher_service.dart';
import '../../services/receipt_service.dart';
import '../../services/printer_service.dart';
import '../../services/receipt_template_service.dart';
import '../../models/cart_item.dart';
import '../payment_webview.dart';

class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key});

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  final _customerNameController = TextEditingController();
  final _voucherController = TextEditingController();
  final _listKey = GlobalKey<AnimatedListState>();
  List<String> _previousCartKeys = [];
  int _listLength = 0;
  String _orderType = 'DINE_IN';
  bool _isProcessing = false;
  bool _submitting = false; // B8: Hard guard against double-tap
  bool _hasAutoPrinted = false; // Prevent infinite print loop
  VoucherResult? _voucher;
  String? _voucherError;

  @override
  void dispose() {
    _customerNameController.dispose();
    _voucherController.dispose();
    super.dispose();
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

  Future<void> _processCashPayment() async {
    // B8: Double-tap prevention — hard guard
    if (_submitting) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

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
        voucherId: _voucher?.voucherId,
      );

      final auth = ref.read(authProvider);

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

  Future<void> _processOnlinePayment() async {
    // B8: Double-tap prevention — hard guard
    if (_submitting) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    _hasAutoPrinted = false; // Reset for new transaction
    _submitting = true;
    setState(() => _isProcessing = true);

    try {
      final orderService = ref.read(orderServiceProvider);
      final subtotal = ref.read(cartTotalProvider);
      final finalTotal = subtotal - _discount;

      // Get payment methods
      final methods = await orderService.getPaymentMethods(finalTotal);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Show method selection
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: _PaymentMethodSheet(methods: methods),
          ),
        ),
      );

      if (selected == null || !mounted) return;

      setState(() => _isProcessing = true);

      final result = await orderService.createOnlinePayment(
        customerName: _customerNameController.text,
        orderType: _orderType,
        items: cart,
        subtotal: subtotal,
        discountAmount: _discount,
        paymentMethod: selected,
        branchId: ref.read(authProvider).branchId ?? '',
        voucherId: _voucher?.voucherId,
      );

      // Open in-app WebView
      if (!mounted) return;
      final paymentSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaymentWebView(
            paymentUrl: result['paymentUrl'] ?? '',
            orderId: result['orderId'] ?? '',
            returnUrl: '${Constants.baseUrl}/ticket/',
          ),
        ),
      );

      if (paymentSuccess == true && mounted) {
        // Payment success
        final auth = ref.read(authProvider);
        ref.read(cartProvider.notifier).clear();
        _customerNameController.clear();
        setState(() {
          _voucher = null;
          _isProcessing = false;
        });
        _showSuccessDialog(
          result['orderId'] ?? '',
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
        // B5: Cancel PENDING order when user dismisses WebView without paying
        final orderId = result['orderId'] ?? '';
        if (orderId.isNotEmpty) {
          await orderService.cancelOrder(orderId);
        }
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran dibatalkan'),
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

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Konfirmasi Pembayaran',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_orderType • $paymentType',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...cart.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.qty}x ${item.product.name}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text('Rp ${formatter.format(item.subtotal)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
              const Divider(height: 20),
              if (_discount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('Rp ${formatter.format(total)}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                  ],
                ),
              if (_discount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Diskon', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('-Rp ${formatter.format(_discount)}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('Rp ${formatter.format(finalTotal)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.success)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Konfirmasi Bayar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (paymentType == 'CASH') {
        await _processCashPayment();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(24),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                  const SizedBox(height: 16),
                  const Text('Pembayaran Berhasil!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('#$orderId',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(paymentType,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ),
                  // Printer status
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: printerService.isConnected
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
                            color: printerService.isConnected ? AppColors.success : AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          printerService.isConnected
                              ? 'Printer: ${printerService.connectedDeviceName ?? 'Terhubung'}'
                              : 'Printer tidak terhubung',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: printerService.isConnected ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
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
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text('Rp ${formatter.format(item.subtotal)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
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
                    onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          nav.pushNamed('/printer');
                        }
                      });
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Atur Printer', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
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
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print, size: 16),
                    label: Text(isPrinting ? 'Mencetak...' : 'Cetak Struk', style: const TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
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

    // Sync AnimatedList with cart changes
    final currentKeys = cart.map((e) => e.key).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final listState = _listKey.currentState;
      if (listState == null) return;

      final newKeys = currentKeys.toSet();
      final removedIndices = <int>[];

      // Find indices to remove (end to start)
      for (int i = _previousCartKeys.length - 1; i >= 0; i--) {
        if (!newKeys.contains(_previousCartKeys[i])) {
          removedIndices.add(i);
        }
      }

      // Remove items — each removeItem decrements AnimatedList count by 1
      for (final idx in removedIndices) {
        final removeAt = idx.clamp(0, _listLength - 1);
        if (removeAt < _listLength) {
          final key = _previousCartKeys[idx];
          listState.removeItem(
            removeAt,
            (context, animation) => SizeTransition(
              sizeFactor: animation,
              child: _buildRemovedItem(key),
            ),
            duration: const Duration(milliseconds: 200),
          );
          _listLength--;
        }
      }

      // Insert new items
      for (int i = 0; i < currentKeys.length; i++) {
        if (!_previousCartKeys.contains(currentKeys[i])) {
          listState.insertItem(i, duration: const Duration(milliseconds: 250));
          _listLength++;
        }
      }

      _previousCartKeys = List.from(currentKeys);
    });

    // Reset when cart is empty
    if (cart.isEmpty && _previousCartKeys.isNotEmpty) {
      _previousCartKeys = [];
      _listLength = 0;
    }
    // Initialize list length when AnimatedList first appears
    if (cart.isNotEmpty && _previousCartKeys.isEmpty) {
      _listLength = cart.length;
    }

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
            color: const Color(0xFFFFC567),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORDER LIST',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    // Order type toggle
                    Row(
                      children: [
                        _orderTypeChip('DINE IN', 'DINE_IN'),
                        const SizedBox(width: 6),
                        _orderTypeChip('TAKE AWAY', 'TAKE_AWAY'),
                      ],
                    ),
                  ],
                ),
                if (cart.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      ref.read(cartProvider.notifier).clear();
                      setState(() {
                        _voucher = null;
                        _voucherError = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.trash2,
                          size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            ),

            // Customer name
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: TextField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Nama Pelanggan (opsional)',
                    prefixIcon: const Icon(Icons.person, size: 18),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
              ),

            // Cart Items
            Expanded(
              child: cart.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.shoppingBag,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Keranjang kosong',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ],
                      ),
                    )
                  : AnimatedList(
                      key: _listKey,
                      initialItemCount: cart.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index, animation) {
                        if (index >= cart.length) return const SizedBox.shrink();
                        return SizeTransition(
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CartItemTile(item: cart[index]),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Voucher
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _voucher != null
                    ? Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.ticket,
                                size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_voucher!.voucherCode} (-Rp ${formatter.format(_discount)})',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _voucher = null;
                                _voucherController.clear();
                              }),
                              child: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _voucherController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Kode Voucher',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorText: _voucherError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _validateVoucher,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Apply',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
              ),

            const SizedBox(height: 8),

            // Footer - Total & Pay
            if (cart.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    if (_discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          Text('Rp ${formatter.format(total)}',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        Text(
                          'Rp ${formatter.format(finalTotal)}',
                          style: const TextStyle(
                              color: Color(0xFFFFC567),
                              fontWeight: FontWeight.w900,
                              fontSize: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _isProcessing ? null : () => _showConfirmDialog('CASH'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('CASH',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _isProcessing ? null : () => _showConfirmDialog('QRIS'),
                                style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('QRIS',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedItem(String key) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Item dihapus',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }

  Widget _orderTypeChip(String label, String value) {
    final isActive = _orderType == value;
    return GestureDetector(
      onTap: () => setState(() => _orderType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.success : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###', 'id');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.selectedTemp != null || item.selectedSize != null)
                  Text(
                    [item.selectedTemp, item.selectedSize]
                        .where((e) => e != null)
                        .join(' - '),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 4),
                Text('Rp ${formatter.format(item.subtotal)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () =>
                    ref.read(cartProvider.notifier).removeItem(item.key),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${item.qty}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14)),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => ref.read(cartProvider.notifier).addItem(
                      item.product,
                      temp: item.selectedTemp,
                      size: item.selectedSize,
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
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _PaymentMethodSheet extends StatelessWidget {
  final List<dynamic> methods;
  const _PaymentMethodSheet({required this.methods});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilih Metode Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: methods.length,
              itemBuilder: (_, i) {
                final m = methods[i] as Map<String, dynamic>;
                final fee = _parseNum(m['totalFee']);
                return ListTile(
                  title: Text(m['paymentName'] ?? 'Unknown'),
                  subtitle: fee > 0
                      ? Text('Fee: Rp ${NumberFormat('#,###', 'id').format(fee)}')
                      : null,
                  onTap: () => Navigator.pop(context, m['paymentMethod'] as String?),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
