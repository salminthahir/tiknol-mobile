import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiknol_reserve_mobile/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TiknolPosApp()));
    expect(find.text('Staff Access'), findsOneWidget);
  });
}
