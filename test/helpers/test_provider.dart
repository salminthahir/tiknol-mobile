// test/helpers/test_provider.dart
// Helper untuk override Riverpod providers saat testing

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';
import 'mock_services.dart';

/// Membuat ProviderScope dengan override untuk testing
ProviderScope createTestScope({
  List<Object> overrides = const [],
  required Widget child,
}) {
  return ProviderScope(
    overrides: overrides,
    child: child,
  );
}

/// Override standar untuk OrderService
Object mockOrderService(MockOrderService mock) {
  return orderServiceProvider.overrideWith((ref) => mock);
}
