import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import 'auth_provider.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(authProvider); // Reactive dependency: re-fetch when auth/branch changes
  final productService = ref.read(productServiceProvider);
  final products = await productService.getProducts(all: false);
  return products.where((p) => p.isAvailable).toList();
});

final categoryFilterProvider = NotifierProvider<CategoryFilterNotifier, String>(CategoryFilterNotifier.new);
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);
final sortByProvider = NotifierProvider<SortByNotifier, SortBy>(SortByNotifier.new);

class CategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'ALL';
  void set(String value) => state = value;
}

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

enum SortBy { name, priceAsc, priceDesc }

class SortByNotifier extends Notifier<SortBy> {
  @override
  SortBy build() => SortBy.name;
  void set(SortBy value) => state = value;
}

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final category = ref.watch(categoryFilterProvider);
  final search = ref.watch(searchQueryProvider);
  final sortBy = ref.watch(sortByProvider);

  return productsAsync.when(
    data: (products) {
      var filtered = products.where((p) {
        final matchCat = category == 'ALL' || p.category == category;
        final matchSearch =
            p.name.toLowerCase().contains(search.toLowerCase());
        return matchCat && matchSearch;
      }).toList();

      switch (sortBy) {
        case SortBy.name:
          filtered.sort((a, b) => a.name.compareTo(b.name));
          break;
        case SortBy.priceAsc:
          filtered.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortBy.priceDesc:
          filtered.sort((a, b) => b.price.compareTo(a.price));
          break;
      }

      return filtered;
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

final categoriesProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.when(
    data: (products) {
      final cats = products.map((p) => p.category).toSet().toList()..sort();
      return ['ALL', ...cats];
    },
    loading: () => ['ALL'],
    error: (_, _) => ['ALL'],
  );
});
