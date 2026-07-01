import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'auth_provider.dart';

/// Kitchen state dengan optimistic updates & per-status pagination
class KitchenState {
  final Map<String, List<dynamic>> ordersByStatus;
  final Map<String, bool> hasMore;
  final Map<String, int> page;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  static const int _pageSize = 20;

  KitchenState({
    Map<String, List<dynamic>>? ordersByStatus,
    Map<String, bool>? hasMore,
    Map<String, int>? page,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  })  : ordersByStatus = ordersByStatus ?? {
          'PAID': [],
          'PREPARING': [],
          'READY': [],
          'COMPLETED': [],
        },
        hasMore = hasMore ?? {
          'PAID': true,
          'PREPARING': true,
          'READY': true,
          'COMPLETED': true,
        },
        page = page ?? {
          'PAID': 1,
          'PREPARING': 1,
          'READY': 1,
          'COMPLETED': 1,
        };

  KitchenState copyWith({
    Map<String, List<dynamic>>? ordersByStatus,
    Map<String, bool>? hasMore,
    Map<String, int>? page,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return KitchenState(
      ordersByStatus: ordersByStatus ?? this.ordersByStatus,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  static const List<String> statusOrder = ['PAID', 'PREPARING', 'READY', 'COMPLETED'];
}

class KitchenNotifier extends Notifier<KitchenState> {
  Timer? _refreshTimer;
  DateTime? _lastFetch;

  @override
  KitchenState build() {
    // Auto-fetch on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchAll();
    });
    return KitchenState();
  }

  /// Debounced fetch — hanya fetch jika belum fetch dalam 5 detik terakhir
  Future<void> fetchAll({bool force = false}) async {
    if (!force && _lastFetch != null) {
      final diff = DateTime.now().difference(_lastFetch!);
      if (diff.inSeconds < 5) return;
    }

    state = state.copyWith(isLoading: state.ordersByStatus.values.every((l) => l.isEmpty));

    try {
      final auth = ref.read(authProvider);
      final api = ref.read(apiClientProvider);
      final branchId = auth.branchId ?? '';
      final url = branchId.isNotEmpty
          ? '/api/admin/orders?branchId=$branchId'
          : '/api/admin/orders';

      final response = await api.client.get(url);
      if (response.statusCode == 200 && response.data is List) {
        final allOrders = (response.data as List)
            .where((o) => o['status'] != 'CANCELLED')
            .toList();

        final grouped = <String, List<dynamic>>{};
        for (final s in KitchenState.statusOrder) {
          grouped[s] = allOrders.where((o) => o['status'] == s).toList();
        }

        state = KitchenState(
          ordersByStatus: grouped,
          hasMore: {
            for (final s in KitchenState.statusOrder)
              s: (grouped[s]?.length ?? 0) >= KitchenState._pageSize,
          },
          page: {for (final s in KitchenState.statusOrder) s: 1},
          isLoading: false,
          isRefreshing: false,
        );
        _lastFetch = DateTime.now();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  /// Optimistic update — pindahkan order di state lokal dulu
  Future<bool> updateStatus(String orderId, String newStatus) async {
    // Find order in current state
    String? currentStatus;
    dynamic order;
    for (final s in KitchenState.statusOrder) {
      final found = state.ordersByStatus[s]?.firstWhere(
        (o) => o['id'] == orderId,
        orElse: () => null,
      );
      if (found != null) {
        currentStatus = s;
        order = found;
        break;
      }
    }

    if (currentStatus == null || order == null) return false;

    // Optimistic: move order locally
    final newOrders = <String, List<dynamic>>{};
    for (final s in KitchenState.statusOrder) {
      newOrders[s] = List.from(state.ordersByStatus[s] ?? []);
    }
    newOrders[currentStatus]!.removeWhere((o) => o['id'] == orderId);
    final updatedOrder = Map<String, dynamic>.from(order);
    updatedOrder['status'] = newStatus;
    newOrders[newStatus] = [...newOrders[newStatus]!, updatedOrder];

    state = state.copyWith(ordersByStatus: newOrders);

    // Sync ke server
    try {
      final api = ref.read(apiClientProvider);
      await api.client.post('/api/admin/update-status', data: {
        'id': orderId,
        'status': newStatus,
      });
      return true;
    } catch (e) {
      // Rollback on error
      fetchAll(force: true);
      return false;
    }
  }

  /// Load more untuk status tertentu (pagination)
  Future<void> loadMore(String status) async {
    if (!state.hasMore[status]!) return;
    // For now, just show all (server returns all)
    // In future, implement server-side pagination
  }

  void clearError() => state = state.copyWith(error: null);

  void dispose() {
    _refreshTimer?.cancel();
  }
}

final kitchenProvider = NotifierProvider<KitchenNotifier, KitchenState>(KitchenNotifier.new);
