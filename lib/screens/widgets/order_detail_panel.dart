import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';

class OrderDetailPanel extends ConsumerWidget {
  final Map<String, dynamic> order;
  const OrderDetailPanel({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,###', 'id');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    final id = order['id']?.toString() ?? '-';
    final total = _parseNum(order['totalAmount']);
    final subtotal = _parseNum(order['subtotal']);
    final discount = _parseNum(order['discountAmount']);
    final status = order['status']?.toString() ?? '';
    final payment = order['paymentType']?.toString() ?? '-';
    final customer = order['customerName']?.toString() ?? 'Customer';
    final cashier = order['cashierName']?.toString();
    final orderType = order['orderType']?.toString() ?? 'DINE_IN';
    final createdRaw = order['createdAt']?.toString();
    final createdAt = createdRaw != null ? DateTime.tryParse(createdRaw) : null;
    final items = _parseItems(order['items']);
    final voucher = order['voucher'] as Map<String, dynamic>?;

    final statusInfo = _getStatusInfo(status);
    final payInfo = _getPaymentInfo(payment);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ HEADER CARD ═══
          _buildHeaderCard(id, statusInfo, createdAt, dateFmt),
          const SizedBox(height: 16),

          // ═══ INFO GRID ═══
          _buildInfoCard(customer, orderType, payInfo, cashier, voucher),
          const SizedBox(height: 16),

          // ═══ ITEMS CARD ═══
          _buildItemsCard(items, fmt),
          const SizedBox(height: 16),

          // ═══ SUMMARY CARD ═══
          _buildSummaryCard(subtotal, discount, voucher, total, fmt),
          const SizedBox(height: 24),

          // ═══ ACTION BUTTON ═══
          _buildReprintButton(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HEADER CARD
  // ═══════════════════════════════════════════════
  Widget _buildHeaderCard(String id, _StatusInfo status, DateTime? createdAt, DateFormat dateFmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${id.length > 8 ? id.substring(id.length - 8) : id}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt != null ? dateFmt.format(createdAt) : '-',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: status.textColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // INFO CARD — Grid layout
  // ═══════════════════════════════════════════════
  Widget _buildInfoCard(String customer, String orderType, _PaymentInfo payInfo, String? cashier, Map<String, dynamic>? voucher) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        children: [
          _infoRow(LucideIcons.user, 'Customer', customer),
          const SizedBox(height: 10),
          _infoRow(
            LucideIcons.store,
            'Order Type',
            orderType == 'DINE_IN' ? 'Dine In' : 'Take Away',
          ),
          const SizedBox(height: 10),
          _infoRow(payInfo.icon, 'Payment', payInfo.label),
          if (cashier != null && cashier.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow(LucideIcons.userCheck, 'Cashier', cashier),
          ],
          if (voucher != null) ...[
            const SizedBox(height: 10),
            _infoRow(
              LucideIcons.tag,
              'Voucher',
              voucher['code']?.toString() ?? '-',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // ITEMS CARD
  // ═══════════════════════════════════════════════
  Widget _buildItemsCard(List<Map<String, dynamic>> items, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${items.length})',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final name = item['name']?.toString() ?? '-';
            final qty = (item['qty'] ?? 1) as num;
            final price = _parseNum(item['price']);
            final lineTotal = qty * price;
            final temp = item['temp']?.toString();
            final size = item['size']?.toString();
            final notes = item['notes']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${qty}x',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (temp != null || size != null || notes != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              temp,
                              size,
                              if (notes != null) 'Note: $notes',
                            ].nonNulls.join(' · '),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rp ${fmt.format(lineTotal)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // SUMMARY CARD
  // ═══════════════════════════════════════════════
  Widget _buildSummaryCard(num subtotal, num discount, Map<String, dynamic>? voucher, num total, NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', subtotal, fmt),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Discount', -discount, fmt, isDiscount: true),
          ],
          if (voucher != null) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Voucher (${voucher['code']})',
              -discount,
              fmt,
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Rp ${fmt.format(total)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, num value, NumberFormat fmt, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${isDiscount ? '- ' : ''}Rp ${fmt.format(value.abs())}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDiscount ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // REPRINT BUTTON
  // ═══════════════════════════════════════════════
  Widget _buildReprintButton() {
    return Consumer(
      builder: (context, ref, child) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reprint feature coming soon')),
              );
            },
            icon: Icon(LucideIcons.printer, size: 16, color: Colors.white),
            label: Text(
              'REPRINT RECEIPT',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════
  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'COMPLETED':
      case 'PAID':
        return _StatusInfo('Paid', AppColors.success, const Color(0xFFE8F5EE));
      case 'FAILED':
      case 'CANCELLED':
        return _StatusInfo('Failed', AppColors.danger, const Color(0xFFFFEBE8));
      case 'PREPARING':
        return _StatusInfo('Preparing', Colors.blue, const Color(0xFFE8F0FE));
      case 'READY':
        return _StatusInfo('Ready', AppColors.accent, const Color(0xFFFFF4E0));
      case 'PENDING':
        return _StatusInfo('Pending', Colors.orange, const Color(0xFFFFF3E0));
      default:
        return _StatusInfo(status, Colors.grey, Colors.grey.shade100);
    }
  }

  _PaymentInfo _getPaymentInfo(String payment) {
    switch (payment) {
      case 'CASH':
        return _PaymentInfo('Cash', LucideIcons.banknote);
      case 'QRIS':
      case 'ONLINE':
        return _PaymentInfo('QRIS', LucideIcons.qrCode);
      default:
        return _PaymentInfo(payment, LucideIcons.wallet);
    }
  }

  static num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    return [];
  }
}

// ═══════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════
class _StatusInfo {
  final String label;
  final Color textColor;
  final Color bgColor;
  _StatusInfo(this.label, this.textColor, this.bgColor);
}

class _PaymentInfo {
  final String label;
  final IconData icon;
  _PaymentInfo(this.label, this.icon);
}
