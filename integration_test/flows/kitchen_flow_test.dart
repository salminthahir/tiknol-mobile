import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tiknol_reserve_mobile/main.dart' as app;
import 'package:tiknol_reserve_mobile/services/server_config_service.dart';
import '../helpers/tablet_config.dart';
import '../page_objects/login_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ServerConfigService.setBaseUrl('http://192.168.100.95:3000');
  });

  testWidgets('KIT-03: Render Kitchen Kanban Board', (tester) async {
    await setTabletOrientation();
    app.main();
    await tester.pumpAndSettle();

    final loginPage = LoginPage(tester);

    // 0. Precondition: Login first if needed
    if (find.text('LOGIN TO POS').evaluate().isNotEmpty) {
      await loginPage.login('EMP-001', '123456');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    // 1. Pindah ke Kitchen Screen via NavRail
    final kitchenTab = find.text('Kitchen');
    expect(kitchenTab, findsOneWidget);
    await tester.tap(kitchenTab);
    
    // Fetch API orders memakan waktu
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // 2. Pastikan 4 kolom Kanban muncul
    expect(find.text('PAID'), findsWidgets);
    expect(find.text('PREPARING'), findsWidgets);
    expect(find.text('READY'), findsWidgets);
    expect(find.text('COMPLETED'), findsWidgets);
  });
}
