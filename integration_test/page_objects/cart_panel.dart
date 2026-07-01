import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CartPanelPage {
  final WidgetTester tester;
  CartPanelPage(this.tester);

  Future<void> setCustomerName(String name) async {
    final textField = find.byType(TextField).first; // Customer name is the first text field in the cart panel
    await tester.enterText(textField, name);
    await tester.pumpAndSettle();
  }

  Future<void> tapCash() async {
    await tester.tap(find.text('CASH'));
    await tester.pumpAndSettle();
  }
  
  Future<void> tapQris() async {
    await tester.tap(find.text('QRIS'));
    await tester.pumpAndSettle();
  }
}
