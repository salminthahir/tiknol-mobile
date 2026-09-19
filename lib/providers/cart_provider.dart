import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

// Derived providers
final cartTotalProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.subtotal);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.qty);
});

final cartProductQtyProvider = Provider.family<int, String>((ref, productId) {
  final cart = ref.watch(cartProvider);
  return cart
      .where((item) => item.product.id == productId)
      .fold(0, (sum, item) => sum + item.qty);
});

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  /// Tambah item ke cart.
  /// [maxQty] = stok tersedia saat ini (persisted - in-cart lainnya).
  /// Jika qty di cart sudah mencapai [maxQty], penambahan diabaikan (return false).
  /// Return true jika berhasil ditambah.
  bool addItem(Product product, {String? temp, String? size, int maxQty = 9999}) {
    final key = '${product.id}_${temp ?? ''}_${size ?? ''}';
    final existingIndex = state.indexWhere((item) => item.key == key);

    // Total qty produk ini di cart (semua varian)
    final totalInCart = state
        .where((item) => item.product.id == product.id)
        .fold(0, (sum, item) => sum + item.qty);

    if (totalInCart >= maxQty) return false; // stok habis, tolak

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(qty: existing.qty + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state,
        CartItem(
          product: product,
          qty: 1,
          selectedTemp: temp,
          selectedSize: size,
        ),
      ];
    }
    return true;
  }

  void removeItem(String key) {
    final existingIndex = state.indexWhere((item) => item.key == key);
    if (existingIndex < 0) return;

    final existing = state[existingIndex];
    if (existing.qty > 1) {
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(qty: existing.qty - 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state.sublist(0, existingIndex),
        ...state.sublist(existingIndex + 1),
      ];
    }
  }

  void clear() {
    state = [];
  }
}
