import 'package:flutter_test/flutter_test.dart';

class PosPage {
  final WidgetTester tester;
  PosPage(this.tester);

  Future<void> tapProduct(String productName) async {
    await tester.tap(find.text(productName));
    await tester.pumpAndSettle();
  }

  Future<void> selectVariant({String? temp, String? size}) async {
    if (temp != null) {
      await tester.tap(find.text(temp));
      await tester.pumpAndSettle();
    }
    if (size != null) {
      await tester.tap(find.text(size));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('ADD TO CART'));
    await tester.pumpAndSettle();
  }
}
