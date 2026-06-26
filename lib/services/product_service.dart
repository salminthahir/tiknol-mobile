import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/product.dart';

final productServiceProvider = Provider((ref) => ProductService(ref));

class ProductService {
  final Ref ref;
  ProductService(this.ref);

  Future<List<Product>> fetchProducts({String? branchId}) async {
    final api = ref.read(apiClientProvider);
    final url = branchId != null
        ? '/api/admin/products?branchId=$branchId'
        : '/api/admin/products';

    final response = await api.client.get(url);

    if (response.statusCode == 200 && response.data is List) {
      return (response.data as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .where((p) => p.isAvailable)
          .toList();
    }

    throw Exception('Failed to fetch products');
  }
}
