import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';

final productServiceProvider = Provider((ref) => ProductService(ref));

class ProductService {
  final Ref ref;
  ProductService(this.ref);

  ApiClient get _api => ref.read(apiClientProvider);
  String get _branchId => ref.read(authProvider).branchId ?? '';

  Future<List<Product>> getProducts({bool all = false}) async {
    final url = _branchId.isNotEmpty
        ? '/api/admin/products?branchId=$_branchId${all ? '&all=1' : ''}'
        : '/api/admin/products';
    final response = await _api.client.get(url);
    if (response.statusCode == 200) {
      final data = response.data as List<dynamic>;
      return data.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
    }
    throw Exception('Gagal memuat produk');
  }

  Future<Product> createProduct({
    required String name,
    required int price,
    required String category,
    String? description,
    String? image,
    bool hasCustomization = false,
    CustomizationOptions? customizationOptions,
    bool isAvailable = true,
    int? branchPrice,
  }) async {
    final response = await _api.client.post('/api/admin/products', data: {
      'name': name,
      'price': price,
      'category': category,
      if (description != null && description.isNotEmpty) 'description': description,
      if (image != null && image.isNotEmpty) 'image': image,
      'hasCustomization': hasCustomization,
      if (customizationOptions != null) 'customizationOptions': customizationOptions.toJson(),
      // Set availability for current branch
      if (_branchId.isNotEmpty)
        'productBranches': [
          {'branchId': _branchId, 'isAvailable': isAvailable, 'branchPrice': branchPrice}
        ],
    });
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Product.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Gagal membuat produk');
  }

  Future<Product> updateProduct(Product product) async {
    final body = <String, dynamic>{
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'image': product.image ?? '',
      'description': product.description ?? '',
      'hasCustomization': product.hasCustomization,
      'customizationOptions': product.customizationOptions?.toJson(),
    };

    // Send branchId so backend updates ProductBranch.isAvailable and branchPrice
    if (_branchId.isNotEmpty) {
      body['branchId'] = _branchId;
      body['isAvailable'] = product.isAvailable;
      if (product.branchPrice != null) {
        body['branchPrice'] = product.branchPrice;
      }
    }

    final response = await _api.client.put('/api/admin/products', data: body);
    if (response.statusCode == 200) {
      return Product.fromJson(response.data as Map<String, dynamic>);
    }
    throw Exception(response.data['error'] ?? 'Gagal mengupdate produk');
  }

  Future<void> deleteProduct(String productId) async {
    final response = await _api.client.delete('/api/admin/products', data: {'id': productId});
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(response.data['error'] ?? 'Gagal menghapus produk');
    }
  }

  Future<String> uploadImage(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });
    final response = await _api.client.post('/api/upload', data: formData);
    if (response.statusCode == 200 && response.data['url'] != null) {
      return response.data['url'] as String;
    }
    throw Exception(response.data['error'] ?? 'Gagal upload gambar');
  }
}
