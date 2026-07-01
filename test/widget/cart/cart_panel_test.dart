// test/widget/cart/cart_panel_test.dart
// Widget tests untuk CartPanel (CART-02~10)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiknol_reserve_mobile/screens/widgets/cart_panel.dart';
import 'package:tiknol_reserve_mobile/providers/cart_provider.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/models/product.dart';
import 'package:tiknol_reserve_mobile/models/cart_item.dart';
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

class _TestCartNotifier extends CartNotifier {
  final List<CartItem> _initialCart;
  _TestCartNotifier(this._initialCart);

  @override
  List<CartItem> build() => _initialCart;
}

void main() {
  final mockProduct = Product(id: 'p1', name: 'Americano', price: 25000, category: 'COFFEE');

  Widget createCartPanel({List<CartItem> initialCart = const []}) {
    return ProviderScope(
      overrides: [
        cartProvider.overrideWith(() => _TestCartNotifier(initialCart)),
        authProvider.overrideWith(() => _TestAuthNotifier()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 1000,
            child: CartPanel(),
          ),
        ),
      ),
    );
  }

  group('CART-02: Increment/decrement quantity', () {
    testWidgets('tap + increases qty', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 1)],
      ));
      await tester.pumpAndSettle();

      // Find qty text
      expect(find.text('1'), findsWidgets);

      // Find and tap the + button
      final addButton = find.byIcon(Icons.add);
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Qty should be 2
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tap - decreases qty', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 2)],
      ));
      await tester.pumpAndSettle();

      final removeButton = find.byIcon(Icons.remove);
      expect(removeButton, findsOneWidget);

      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Qty should be 1
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('tap - on qty 1 removes item', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 1)],
      ));
      await tester.pumpAndSettle();

      final removeButton = find.byIcon(Icons.remove);
      await tester.tap(removeButton);
      await tester.pumpAndSettle();

      // Item removed, cart empty
      expect(find.text('EMPTY ORDER'), findsOneWidget);
    });
  });

  group('CART-10: Pay button shows confirmation', () {
    testWidgets('tap CASH button shows confirmation dialog', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 1)],
      ));
      await tester.pumpAndSettle();

      // Tap CASH button
      await tester.tap(find.text('CASH'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('tap QRIS button shows confirmation dialog', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 1)],
      ));
      await tester.pumpAndSettle();

      // Tap QRIS button
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('CART-06/07: Voucher input', () {
    testWidgets('voucher toggle and input field rendered', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createCartPanel(
        initialCart: [CartItem(product: mockProduct, qty: 1)],
      ));
      await tester.pumpAndSettle();

      // Tap voucher toggle (look for widget containing 'Voucher' text)
      final voucherFinder = find.text('Voucher');
      expect(voucherFinder, findsOneWidget);

      await tester.tap(voucherFinder);
      await tester.pumpAndSettle();

      // Look for voucher text field
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });
  });
}
