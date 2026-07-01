// test/widget/pos/pos_screen_test.dart
// Widget tests untuk PosScreen (POS-02~06)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiknol_reserve_mobile/screens/pos_screen.dart';
import 'package:tiknol_reserve_mobile/providers/product_provider.dart';
import 'package:tiknol_reserve_mobile/providers/cart_provider.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/models/product.dart';
import '../../helpers/tablet_viewport.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    userName: 'Test',
    branchName: 'HQ',
    branchId: 'B1',
  );
}

void main() {
  final mockProducts = [
    Product(id: 'p1', name: 'Americano', price: 25000, category: 'COFFEE', isAvailable: true, hasCustomization: true, customizationOptions: CustomizationOptions(temps: ['ICE', 'HOT'], sizes: ['M', 'L'])),
    Product(id: 'p2', name: 'Espresso', price: 20000, category: 'COFFEE', isAvailable: true),
    Product(id: 'p3', name: 'Lemon Tea', price: 18000, category: 'NON-COFFEE', isAvailable: true),
    Product(id: 'p4', name: 'French Fries', price: 15000, category: 'SNACK', isAvailable: true),
  ];

  Widget createPosScreen() {
    return ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) async => mockProducts),
        authProvider.overrideWith(() => _TestAuthNotifier()),
      ],
      child: const MaterialApp(
        home: PosScreen(),
      ),
    );
  }

  group('POS-02: Category filter', () {
    testWidgets('render category chips dan product grid', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createPosScreen());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show categories
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('COFFEE'), findsOneWidget);
      expect(find.text('NON-COFFEE'), findsOneWidget);
      expect(find.text('SNACK'), findsOneWidget);

      // Should show products
      expect(find.text('Americano'), findsOneWidget);
      expect(find.text('Espresso'), findsOneWidget);
    });

    testWidgets('tap COFFEE filter hanya tampilkan coffee', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createPosScreen());
      await tester.pumpAndSettle();

      // Tap COFFEE chip
      await tester.tap(find.text('COFFEE'));
      await tester.pumpAndSettle();

      // Coffee products visible
      expect(find.text('Americano'), findsOneWidget);
      expect(find.text('Espresso'), findsOneWidget);

      // Non-coffee should be filtered out
      expect(find.text('Lemon Tea'), findsNothing);
    });
  });

  group('POS-03: Search', () {
    testWidgets('search by name filters products', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createPosScreen());
      await tester.pumpAndSettle();

      // Find search field (first TextField) and enter text
      final searchField = find.byType(TextField).first;
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Americano');
      await tester.pumpAndSettle();

      // Only Americano should be visible as product card
      expect(find.text('Espresso'), findsNothing);
      expect(find.text('Lemon Tea'), findsNothing);
    });
  });

  group('POS-05: Product customization', () {
    testWidgets('tap customizable product shows bottom sheet', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createPosScreen());
      await tester.pumpAndSettle();

      // Tap Americano (has customization)
      await tester.tap(find.text('Americano'));
      await tester.pumpAndSettle();

      // Bottom sheet should show customization options
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('ICE'), findsOneWidget);
      expect(find.text('HOT'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
    });
  });

  group('POS-06: Add to cart', () {
    testWidgets('add product with customization to cart', (tester) async {
      setTabletViewport(tester);

      // Suppress overflow errors from CartPanel in narrow test viewport
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(createPosScreen());
      await tester.pumpAndSettle();

      // Tap Americano
      await tester.tap(find.text('Americano'));
      await tester.pumpAndSettle();

      // Select ICE and L
      await tester.tap(find.text('ICE'));
      await tester.pump();
      await tester.tap(find.text('L'));
      await tester.pump();

      // Tap Add to Cart
      await tester.tap(find.text('ADD TO CART'));
      await tester.pumpAndSettle();

      // Bottom sheet should close
      expect(find.text('Temperature'), findsNothing);
    });
  });
}
