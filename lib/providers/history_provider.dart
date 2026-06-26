import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../providers/auth_provider.dart';

class HistoryState {
  final List<dynamic> orders;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final DateTime? from;
  final DateTime? to;
  final String? status;
  final String? paymentType;
  final String searchQuery;

  const HistoryState({
    this.orders = const [],
    this.page = 1,
    this.limit = 50,
    this.total = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.from,
    this.to,
    this.status,
    this.paymentType,
    this.searchQuery = '',
  });

  HistoryState copyWith({
    List<dynamic>? orders,
    int? page,
    int? limit,
    int? total,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    DateTime? from,
    DateTime? to,
    String? status,
    String? paymentType,
    String? searchQuery,
  }) {
    return HistoryState(
      orders: orders ?? this.orders,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      from: from ?? this.from,
      to: to ?? this.to,
      status: status ?? this.status,
      paymentType: paymentType ?? this.paymentType,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, error: null, page: 1);
    try {
      final orders = await _fetchPage(1);
      state = state.copyWith(
        orders: orders,
        isLoading: false,
        hasMore: state.page < state.totalPages,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Gagal memuat data',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final moreOrders = await _fetchPage(nextPage);
      state = state.copyWith(
        orders: [...state.orders, ...moreOrders],
        page: nextPage,
        isLoadingMore: false,
        hasMore: nextPage < state.totalPages,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.message ?? 'Gagal memuat data',
      );
    }
  }

  Future<List<dynamic>> _fetchPage(int page) async {
    final auth = ref.read(authProvider);
    final api = ref.read(apiClientProvider);

    final branchId = auth.branchId ?? '';
    final queryParams = <String, String>{
      if (branchId.isNotEmpty) 'branchId': branchId,
      'page': page.toString(),
      'limit': state.limit.toString(),
      if (state.from != null)
        'from': DateFormat('yyyy-MM-dd').format(state.from!),
      if (state.to != null) 'to': DateFormat('yyyy-MM-dd').format(state.to!),
      if (state.status != null && state.status != 'ALL')
        'status': state.status!,
      if (state.paymentType != null && state.paymentType != 'ALL')
        'paymentType': state.paymentType!,
      if (state.searchQuery.isNotEmpty) 'q': state.searchQuery,
    };

    final uri = Uri(
      path: '/api/admin/pos-history',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await api.client.get(uri.toString());

    if (response.statusCode == 200) {
      // New paginated format: { data: [...], meta: {...} }
      if (response.data is Map && response.data['data'] is List) {
        final meta = response.data['meta'] as Map<String, dynamic>? ?? {};
        state = state.copyWith(
          total: (meta['total'] ?? 0) as int,
          totalPages: (meta['totalPages'] ?? 1) as int,
        );
        return response.data['data'] as List<dynamic>;
      }
      // Legacy format: [...] (fallback)
      if (response.data is List) {
        final list = response.data as List<dynamic>;
        state = state.copyWith(total: list.length, totalPages: 1);
        return list;
      }
    }
    return [];
  }

  void setDateRange(DateTime from, DateTime to) {
    state = state.copyWith(from: from, to: to, page: 1);
    fetch();
  }

  void clearDateRange() {
    state = state.copyWith(from: null, to: null, page: 1);
    fetch();
  }

  void setStatus(String? s) {
    state = state.copyWith(status: s, page: 1);
    fetch();
  }

  void setPaymentType(String? p) {
    state = state.copyWith(paymentType: p, page: 1);
    fetch();
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q, page: 1);
    fetch();
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', page: 1);
    fetch();
  }

  void resetFilters() {
    state = const HistoryState();
    fetch();
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
