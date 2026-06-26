import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import '../core/theme.dart';
import '../providers/kitchen_provider.dart';
import 'widgets/skeleton.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kitchenProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    ref.read(kitchenProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = ref.watch(kitchenProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: kitchen.isLoading && _isAllEmpty(kitchen)
            ? _buildSkeleton(isTablet)
            : Column(
                children: [
                  _buildHeader(kitchen),
                  if (isTablet)
                    Expanded(child: _buildKanbanBoard(kitchen))
                  else
                    Expanded(
                      child: Column(
                        children: [
                          _buildPhoneTabs(kitchen),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: KitchenState.statusOrder
                                  .map((s) => _buildOrderList(
                                        kitchen.ordersByStatus[s] ?? [],
                                        s,
                                        kitchen,
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  bool _isAllEmpty(KitchenState state) {
    return state.ordersByStatus.values.every((l) => l.isEmpty);
  }

  // ═══════════════════════════════════════════════
  // SKELETON
  // ═══════════════════════════════════════════════
  Widget _buildSkeleton(bool isTablet) {
    return Column(
      children: [
        _buildSkeletonHeader(),
        if (isTablet)
          Expanded(
            child: Row(
              children: List.generate(4, (_) => Expanded(
                child: Column(
                  children: [
                    _buildSkeletonColumnHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: 3,
                        itemBuilder: (context, index) => _buildSkeletonCard(),
                      ),
                    ),
                  ],
                ),
              )),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              itemBuilder: (context, index) => _buildSkeletonCard(),
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
      ),
      child: Row(
        children: [
          Skeleton(width: 160, height: 28, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildSkeletonColumnHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Skeleton(width: double.infinity, height: 20, borderRadius: 4),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(width: 80, height: 16, borderRadius: 4),
          const SizedBox(height: 6),
          Skeleton(width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: 4),
          Skeleton(width: 100, height: 12, borderRadius: 4),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════
  Widget _buildHeader(KitchenState kitchen) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
      ),
      child: Row(
        children: [
          Text(
            'KITCHEN ',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: Colors.black,
              letterSpacing: -1,
            ),
          ),
          Text(
            'CONTROL',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: const Color(0xFFFBC02D),
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          // Refresh button
          GestureDetector(
            onTap: () => ref.read(kitchenProvider.notifier).fetchAll(force: true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.refreshCw,
                  size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PHONE TABS
  // ═══════════════════════════════════════════════
  Widget _buildPhoneTabs(KitchenState kitchen) {
    final tabs = [
      _TabConfig('PAID', 'Baru', const Color(0xFFFBC02D)),
      _TabConfig('PREPARING', 'Proses', Colors.black),
      _TabConfig('READY', 'Siap', const Color(0xFF00995E)),
      _TabConfig('COMPLETED', 'Selesai', Colors.grey.shade400),
    ];

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorWeight: 3,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: tabs.map((t) {
          final count = (kitchen.ordersByStatus[t.status]?.length ?? 0);
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(t.label),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: t.color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // KANBAN BOARD (TABLET)
  // ═══════════════════════════════════════════════
  Widget _buildKanbanBoard(KitchenState kitchen) {
    final columns = [
      _KanbanColumn(
        status: 'PAID',
        label: 'BARU',
        color: const Color(0xFFFBC02D),
        bgColor: const Color(0xFFFFF8E1),
      ),
      _KanbanColumn(
        status: 'PREPARING',
        label: 'DIPROSES',
        color: Colors.black,
        bgColor: const Color(0xFFF5F5F5),
      ),
      _KanbanColumn(
        status: 'READY',
        label: 'SIAP',
        color: const Color(0xFF00995E),
        bgColor: const Color(0xFFE8F5E9),
      ),
      _KanbanColumn(
        status: 'COMPLETED',
        label: 'SELESAI',
        color: Colors.grey.shade500,
        bgColor: const Color(0xFFF5F5F5),
      ),
    ];

    return Row(
      children: columns.map((col) {
        final orders = kitchen.ordersByStatus[col.status] ?? [];
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 1),
            decoration: BoxDecoration(
              color: col.bgColor,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Column header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: col.color, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: col.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        col.label,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: col.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${orders.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: col.color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (orders.length > 20)
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'More',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: col.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Orders list
                Expanded(
                  child: orders.isEmpty
                      ? _buildEmptyColumn(col.label)
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: orders.length,
                          itemBuilder: (context, i) => _CompactOrderCard(
                            order: orders[i],
                            onAction: () => _handleAction(orders[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyColumn(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.inbox, size: 32, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'Tidak ada $label',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // ORDER LIST (PHONE)
  // ═══════════════════════════════════════════════
  Widget _buildOrderList(
    List<dynamic> orders,
    String status,
    KitchenState kitchen,
  ) {
    if (orders.isEmpty) {
      return _buildEmptyColumn(_getLabel(status));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(kitchenProvider.notifier).fetchAll(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: orders.length,
        itemBuilder: (context, i) => _CompactOrderCard(
          order: orders[i],
          onAction: () => _handleAction(orders[i]),
        ),
      ),
    );
  }

  String _getLabel(String status) {
    switch (status) {
      case 'PAID': return 'Baru';
      case 'PREPARING': return 'Diproses';
      case 'READY': return 'Siap';
      case 'COMPLETED': return 'Selesai';
      default: return status;
    }
  }

  Future<void> _handleAction(dynamic order) async {
    final id = order['id']?.toString();
    if (id == null) return;

    final currentStatus = order['status']?.toString() ?? '';
    String nextStatus;
    switch (currentStatus) {
      case 'PAID':
        nextStatus = 'PREPARING';
        break;
      case 'PREPARING':
        nextStatus = 'READY';
        break;
      case 'READY':
        nextStatus = 'COMPLETED';
        break;
      default:
        return;
    }

    final success = await ref.read(kitchenProvider.notifier).updateStatus(id, nextStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $_getLabel(currentStatus) → $_getLabel(nextStatus)'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════
// COMPACT ORDER CARD
// ═══════════════════════════════════════════════════

class _CompactOrderCard extends StatelessWidget {
  final dynamic order;
  final VoidCallback onAction;

  const _CompactOrderCard({required this.order, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final items = order['items'];
    List<dynamic> itemList = [];
    if (items is String) {
      try { itemList = List.from(jsonDecode(items)); } catch (_) {}
    } else if (items is List) {
      itemList = items;
    }

    final createdRaw = order['createdAt']?.toString();
    final createdAt = createdRaw != null ? DateTime.tryParse(createdRaw) : null;
    final orderId = order['id']?.toString() ?? '';

    final actionConfig = _getActionConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: actionConfig.headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: const Border(bottom: BorderSide(color: Colors.black, width: 2)),
            ),
            child: Row(
              children: [
                Text(
                  '#${orderId.length > 5 ? orderId.substring(orderId.length - 5).toUpperCase() : orderId.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: actionConfig.headerText,
                  ),
                ),
                const Spacer(),
                Text(
                  createdAt != null
                      ? DateFormat('HH:mm').format(createdAt)
                      : '--:--',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: actionConfig.headerText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order['customerName']?.toString() ?? 'Customer',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        order['orderType']?.toString() ?? 'DINE_IN',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Items (compact, max 3 visible)
                ...itemList.take(3).map((item) {
                  final custom = (item as Map<String, dynamic>)['custom'] as Map<String, dynamic>?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Center(
                            child: Text(
                              '${item['qty'] ?? 1}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name']?.toString() ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (custom != null) ...[
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    if (custom['temp'] != null)
                                      _miniTag(custom['temp'].toString()),
                                    if (custom['size'] != null) ...[
                                      const SizedBox(width: 3),
                                      _miniTag(custom['size'].toString()),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                if (itemList.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 23, top: 2),
                    child: Text(
                      '+${itemList.length - 3} item lainnya',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action button
          if (status != 'COMPLETED')
            GestureDetector(
              onTap: onAction,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: actionConfig.buttonBg,
                  border: const Border(
                    top: BorderSide(color: Colors.black, width: 2),
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(
                  actionConfig.buttonLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: actionConfig.buttonText,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 7,
          fontWeight: FontWeight.w800,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  _ActionConfig _getActionConfig(String status) {
    switch (status) {
      case 'PAID':
        return _ActionConfig(
          headerBg: const Color(0xFFFBC02D),
          headerText: Colors.black,
          buttonBg: Colors.black,
          buttonText: Colors.white,
          buttonLabel: 'TERIMA / MASAK',
        );
      case 'PREPARING':
        return _ActionConfig(
          headerBg: Colors.white,
          headerText: Colors.black,
          buttonBg: Colors.white,
          buttonText: Colors.black,
          buttonLabel: 'SELESAI MASAK',
        );
      case 'READY':
        return _ActionConfig(
          headerBg: const Color(0xFF00995E),
          headerText: Colors.white,
          buttonBg: const Color(0xFF00995E),
          buttonText: Colors.white,
          buttonLabel: 'PANGGIL / SELESAI',
        );
      default:
        return _ActionConfig(
          headerBg: Colors.grey.shade200,
          headerText: Colors.grey.shade600,
          buttonBg: Colors.grey.shade200,
          buttonText: Colors.grey.shade600,
          buttonLabel: '',
        );
    }
  }
}

// ═══════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════

class _TabConfig {
  final String status;
  final String label;
  final Color color;
  _TabConfig(this.status, this.label, this.color);
}

class _KanbanColumn {
  final String status;
  final String label;
  final Color color;
  final Color bgColor;
  _KanbanColumn({
    required this.status,
    required this.label,
    required this.color,
    required this.bgColor,
  });
}

class _ActionConfig {
  final Color headerBg;
  final Color headerText;
  final Color buttonBg;
  final Color buttonText;
  final String buttonLabel;
  _ActionConfig({
    required this.headerBg,
    required this.headerText,
    required this.buttonBg,
    required this.buttonText,
    required this.buttonLabel,
  });
}
