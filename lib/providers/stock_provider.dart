import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stock_service.dart';
import 'cart_provider.dart';

// ─── State Notifier ──────────────────────────────────────────────────────────

class StockNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final service = ref.read(stockServiceProvider);
    return service.loadAll();
  }

  /// Set stok produk. Optimistic update: ubah state dulu, simpan ke disk.
  Future<void> setStock(String productId, int qty) async {
    final service = ref.read(stockServiceProvider);

    // Optimistic update
    final current = state.value ?? {};
    state = AsyncData({...current, productId: qty});

    // Persist
    await service.setStock(productId, qty);
  }

  /// Kurangi stok permanen untuk setiap item yang ada di cart saat order sukses.
  Future<void> deductForCart(List<({String productId, int qty})> items) async {
    final service = ref.read(stockServiceProvider);
    final current = Map<String, int>.from(state.value ?? {});

    for (final item in items) {
      final current0 = current[item.productId] ?? 99;
      final newQty = (current0 - item.qty).clamp(0, 9999);
      current[item.productId] = newQty;
      await service.setStock(item.productId, newQty);
    }

    state = AsyncData(current);
  }

  /// Baca stok satu produk dari state saat ini.
  /// Jika belum ada di state (map belum load), return 99 (default).
  int getStockSync(String productId) {
    return state.value?[productId] ?? 99;
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final stockProvider = AsyncNotifierProvider<StockNotifier, Map<String, int>>(
  StockNotifier.new,
);

/// Stok persisten per-produk (dari disk). Dipakai di Inventory screen.
final stockByIdProvider = Provider.family<int, String>((ref, productId) {
  final stockMap = ref.watch(stockProvider).value ?? {};
  return stockMap[productId] ?? 99;
});

/// Stok live per-produk = stok persisten MINUS qty yang ada di cart.
/// Dipakai di badge POS agar stok berkurang secara real-time saat item ditambah ke cart.
final stockAvailableByIdProvider = Provider.family<int, String>((ref, productId) {
  final persisted = ref.watch(stockByIdProvider(productId));
  final inCart = ref.watch(cartProductQtyProvider(productId));
  return (persisted - inCart).clamp(0, 9999);
});

/// True jika ada item di cart yang qty-nya melebihi stok persisten.
/// Dipakai untuk disable tombol bayar saat stok tidak mencukupi.
final cartHasStockIssueProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  final stockMap = ref.watch(stockProvider).value ?? {};

  for (final item in cart) {
    final persisted = stockMap[item.product.id] ?? 99;
    // Total qty produk ini di cart (semua varian digabung per productId)
    final totalInCart = cart
        .where((c) => c.product.id == item.product.id)
        .fold(0, (sum, c) => sum + c.qty);
    if (totalInCart > persisted) return true;
  }
  return false;
});
