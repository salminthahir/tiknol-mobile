import '../models/product.dart';

class CartItem {
  final Product product;
  final int qty;
  final String? selectedTemp;
  final String? selectedSize;

  const CartItem({
    required this.product,
    this.qty = 1,
    this.selectedTemp,
    this.selectedSize,
  });

  /// Unique key for identifying same product with same customization
  String get key => '${product.id}_${selectedTemp ?? ''}_${selectedSize ?? ''}';

  /// Display name with customization
  String get displayName {
    final parts = <String>[];
    if (selectedTemp != null) parts.add(selectedTemp!);
    if (selectedSize != null) parts.add(selectedSize!);
    if (parts.isEmpty) return product.name;
    return '${product.name} (${parts.join('/')})';
  }

  int get subtotal => product.price * qty;

  CartItem copyWith({int? qty}) {
    return CartItem(
      product: product,
      qty: qty ?? this.qty,
      selectedTemp: selectedTemp,
      selectedSize: selectedSize,
    );
  }
}
