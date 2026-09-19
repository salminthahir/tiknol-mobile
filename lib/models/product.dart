import '../core/constants.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final int price;
  final int? branchPrice;
  final String category;
  final String? image;
  final bool isAvailable;
  final bool hasCustomization;
  final CustomizationOptions? customizationOptions;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.branchPrice,
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
        imageUrl = '${Constants.baseUrl}$rawImage';
      } else {
        imageUrl = rawImage;
      }
    }

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] as String?,
      price: json['price'] ?? 0,
      branchPrice: json['branchPrice'] as int?,
      category: json['category'] ?? 'OTHER',
      image: imageUrl,
      isAvailable: json['isAvailable'] ?? true,
      hasCustomization: json['hasCustomization'] ?? false,
      customizationOptions: json['customizationOptions'] != null
          ? CustomizationOptions.fromJson(json['customizationOptions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'branchPrice': branchPrice,
      'category': category,
      'image': image,
      'isAvailable': isAvailable,
      'hasCustomization': hasCustomization,
      'customizationOptions': customizationOptions?.toJson(),
    };
  }

  // Sentinel untuk copyWith agar bisa menerima null
  static const _unset = Object();

  Product copyWith({
    String? id,
    String? name,
    Object? description = _unset,
    int? price,
    Object? branchPrice = _unset,
    String? category,
    Object? image = _unset,
    bool? isAvailable,
    bool? hasCustomization,
    Object? customizationOptions = _unset,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _unset) ? this.description : description as String?,
      price: price ?? this.price,
      branchPrice: identical(branchPrice, _unset) ? this.branchPrice : branchPrice as int?,
      category: category ?? this.category,
      image: identical(image, _unset) ? this.image : image as String?,
      isAvailable: isAvailable ?? this.isAvailable,
      hasCustomization: hasCustomization ?? this.hasCustomization,
      customizationOptions: identical(customizationOptions, _unset) 
          ? this.customizationOptions 
          : customizationOptions as CustomizationOptions?,
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

  Map<String, dynamic> toJson() {
    return {
      'temps': temps,
      'sizes': sizes,
    };
  }
}
