import '../core/constants.dart';

class Product {
  final String id;
  final String name;
  final int price;
  final String category;
  final String? image;
  final bool isAvailable;
  final bool hasCustomization;
  final CustomizationOptions? customizationOptions;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.image,
    this.isAvailable = true,
    this.hasCustomization = false,
    this.customizationOptions,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image'] as String?;
    String? imageUrl;
    if (rawImage != null && rawImage.isNotEmpty) {
      if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
        imageUrl = rawImage;
      } else if (rawImage.startsWith('/')) {
        // Relative path from server (e.g. /uploads/product.png)
        imageUrl = '${Constants.baseUrl}$rawImage';
      } else {
        imageUrl = rawImage;
      }
    }

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: json['price'] ?? 0,
      category: json['category'] ?? 'OTHER',
      image: imageUrl,
      isAvailable: json['isAvailable'] ?? true,
      hasCustomization: json['hasCustomization'] ?? false,
      customizationOptions: json['customizationOptions'] != null
          ? CustomizationOptions.fromJson(json['customizationOptions'])
          : null,
    );
  }
}

class CustomizationOptions {
  final List<String> temps;
  final List<String> sizes;

  const CustomizationOptions({
    this.temps = const [],
    this.sizes = const [],
  });

  factory CustomizationOptions.fromJson(Map<String, dynamic> json) {
    return CustomizationOptions(
      temps: (json['temps'] as List<dynamic>?)?.cast<String>() ?? [],
      sizes: (json['sizes'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
