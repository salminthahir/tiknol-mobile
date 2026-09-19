import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final stockServiceProvider = Provider<StockService>((ref) => StockService());

class StockService {
  static const String _prefix = 'stock_';
  static const int _defaultStock = 99;

  /// Load semua stok yang pernah disimpan.
  /// Return: Map of productId to qty
  Future<Map<String, int>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final result = <String, int>{};
    for (final key in keys) {
      final productId = key.substring(_prefix.length);
      result[productId] = prefs.getInt(key) ?? _defaultStock;
    }
    return result;
  }

  /// Simpan stok untuk satu produk.
  Future<void> setStock(String productId, int qty) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$productId', qty);
  }

  /// Baca stok satu produk. Jika belum pernah diset, return defaultStock (99).
  Future<int> getStock(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$productId') ?? _defaultStock;
  }
}
