import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme.dart';
import '../providers/history_provider.dart';
import 'widgets/order_detail_panel.dart';
import 'widgets/skeleton_screens.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedOrderId;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).fetch();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(historyProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(history),
            _buildFilters(history),
            Expanded(
              child: isTablet
                  ? _buildTabletLayout(history)
                  : _buildPhoneLayout(history),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HEADER — Clean & Minimal
  // ═══════════════════════════════════════════════
  Widget _buildHeader(HistoryState history) {
    final hasSearch = history.searchQuery.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order History',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  history.from != null && history.to != null
                      ? '${DateFormat('dd MMM').format(history.from!)} - ${DateFormat('dd MMM yyyy').format(history.to!)} · ${history.total} orders'
                      : '${history.total} orders',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Search
          _iconButton(
            hasSearch ? LucideIcons.searchX : LucideIcons.search,
            hasSearch ? AppColors.primary : AppColors.textSecondary,
            () => _showSearchDialog(),
          ),
          const SizedBox(width: 4),
          // Refresh
          _iconButton(
            LucideIcons.refreshCw,
            AppColors.textSecondary,
            () => ref.read(historyProvider.notifier).fetch(),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // FILTERS — Pill-shaped, minimal
  // ═══════════════════════════════════════════════
  Widget _buildFilters(HistoryState history) {
    final now = DateTime.now();
    final dateChips = [
      _DateChip(label: 'All', from: null, to: null),
      _DateChip(
        label: 'Today',
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day),
      ),
      _DateChip(
        label: 'Yesterday',
        from: DateTime(now.year, now.month, now.day - 1),
        to: DateTime(now.year, now.month, now.day - 1),
      ),
      _DateChip(
        label: '7 Days',
        from: now.subtract(const Duration(days: 7)),
        to: now,
      ),
      _DateChip(
        label: 'This Month',
        from: DateTime(now.year, now.month, 1),
        to: now,
      ),
    ];

    bool isDateSelected(_DateChip chip) {
      if (chip.from == null) return history.from == null && history.to == null;
      if (history.from == null || history.to == null) return false;
      final a = DateFormat('yyyy-MM-dd').format(chip.from!);
      final b = DateFormat('yyyy-MM-dd').format(chip.to!);
      final c = DateFormat('yyyy-MM-dd').format(history.from!);
      final d = DateFormat('yyyy-MM-dd').format(history.to!);
      return a == c && b == d;
    }

    final statusOptions = [
      _StatusOption(label: 'All', value: 'ALL'),
      _StatusOption(label: 'Paid', value: 'PAID'),
      _StatusOption(label: 'Pending', value: 'PENDING'),
      _StatusOption(label: 'Cancelled', value: 'CANCELLED'),
      _StatusOption(label: 'Failed', value: 'FAILED'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...dateChips.map((chip) {
                  final active = isDateSelected(chip);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterPill(
                      label: chip.label,
                      active: active,
                      onTap: () {
                        if (chip.from == null) {
                          ref.read(historyProvider.notifier).clearDateRange();
                        } else {
                          ref.read(historyProvider.notifier).setDateRange(chip.from!, chip.to!);
                        }
                      },
                    ),
                  );
                }),
                _FilterPill(
                  label: 'Custom',
                  active: false,
                  icon: LucideIcons.calendar,
                  onTap: _showDateRangePicker,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: statusOptions.map((option) {
                final active =
                    (history.status == option.value) ||
                    (history.status == null && option.value == 'ALL');
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterPill(
                    label: option.label,
                    active: active,
                    onTap: () => ref
                        .read(historyProvider.notifier)
                        .setStatus(option.value),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // TABLET LAYOUT
  // ═══════════════════════════════════════════════
  Widget _buildTabletLayout(HistoryState history) {
    if (history.isLoading && history.orders.isEmpty) {
      return const HistorySkeleton();
    }

    if (history.error != null && history.orders.isEmpty) {
      return _buildError(history.error!);
    }

    final selected = history.orders.cast<Map<String, dynamic>>().firstWhere(
      (o) => o['id'] == _selectedOrderId,
      orElse: () => history.orders.isNotEmpty
          ? history.orders.first as Map<String, dynamic>
          : {},
    );

    return Row(
      children: [
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            border: Border(
              right: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: _buildOrderList(history, isTablet: true),
        ),
        Expanded(
          child: selected.isNotEmpty
              ? Container(
                  color: Colors.white,
                  child: OrderDetailPanel(order: selected),
                )
              : _buildEmptyDetail(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // PHONE LAYOUT
  // ═══════════════════════════════════════════════
  Widget _buildPhoneLayout(HistoryState history) {
    return _buildOrderList(history, isTablet: false);
  }

  // ═══════════════════════════════════════════════
  // ORDER LIST — Card-based, breathable
  // ═══════════════════════════════════════════════
  Widget _buildOrderList(HistoryState history, {required bool isTablet}) {
    if (history.isLoading && history.orders.isEmpty) {
      return const HistorySkeleton();
    }

    if (history.error != null && history.orders.isEmpty) {
      return _buildError(history.error!);
    }

    if (history.orders.isEmpty) {
      return _buildEmpty();
    }

    final formatter = NumberFormat('#,###', 'id');
    final timeFmt = DateFormat('HH:mm');

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: history.orders.length + (history.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= history.orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final order = history.orders[i] as Map<String, dynamic>;
        final id = (order['id'] ?? '').toString();
        final total = order['totalAmount'] ?? 0;
        final status = order['status'] ?? '';
        final payment = order['paymentType'] ?? '';
        final customer = order['customerName'] ?? 'Customer';
        final createdAtRaw = order['createdAt']?.toString();
        final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;
        final isSelected = _selectedOrderId == id;

        final statusInfo = _getStatusInfo(status);
        final payInfo = _getPaymentInfo(payment);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected ? const Color(0xFFF0EEF7) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (isTablet) {
                  setState(() => _selectedOrderId = id);
                } else {
                  _showPhoneDetail(order);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
                      : Border.all(color: Colors.grey.shade100, width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Time badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            createdAt != null ? timeFmt.format(createdAt) : '--:--',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Order ID
                        Expanded(
                          child: Text(
                            '#${id.length > 8 ? id.substring(id.length - 8) : id}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusInfo.bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusInfo.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusInfo.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(payInfo.icon, size: 11, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    payInfo.label,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rp ${formatter.format(total)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            error,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => ref.read(historyProvider.notifier).fetch(),
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.receipt, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDetail() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.mousePointerClick, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Select an order to view details',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

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

  // ═══════════════════════════════════════════════
  // BOTTOM SHEET (Phone)
  // ═══════════════════════════════════════════════
  void _showPhoneDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Order Details',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            body: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: OrderDetailPanel(order: order),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // SEARCH DIALOG
  // ═══════════════════════════════════════════════
  void _showSearchDialog() {
    final history = ref.read(historyProvider);
    _searchController.text = history.searchQuery;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Search Orders',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Order ID or customer name',
              hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
              prefixIcon: Icon(LucideIcons.search, size: 18, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 14),
            onSubmitted: (val) {
              ref.read(historyProvider.notifier).setSearch(val.trim());
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              onPressed: () {
                ref.read(historyProvider.notifier).setSearch(_searchController.text.trim());
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Search', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // DATE RANGE PICKER
  // ═══════════════════════════════════════════════
  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          appBarTheme: const AppBarTheme(backgroundColor: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(historyProvider.notifier).setDateRange(picked.start, picked.end);
    }
  }
}

// ═══════════════════════════════════════════════
// FILTER PILL — Minimal, clean
// ═══════════════════════════════════════════════
class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: active ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════
class _DateChip {
  final String label;
  final DateTime? from;
  final DateTime? to;
  _DateChip({required this.label, this.from, this.to});
}

class _StatusOption {
  final String label;
  final String value;
  _StatusOption({required this.label, required this.value});
}

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
