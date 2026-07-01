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
    // Tembak backend sungguhan ke IP laptop
    await ServerConfigService.setBaseUrl('http://192.168.100.95:3000');
  });

  testWidgets('AUTH-01: Staff login → POS → Logout', (tester) async {
    await setTabletOrientation();
    app.main();
    await tester.pumpAndSettle();

    final loginPage = LoginPage(tester);

    // Pastikan berada di layar login
    expect(find.text('LOGIN TO POS'), findsOneWidget);

    // Login
    await loginPage.login('EMP-001', '123456');
    
    // Beri waktu tunggu untuk response API
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Assert: berhasil masuk ke layar POS
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('ALL'), findsWidgets); // Category chip ALL
    expect(find.text('ORDER LIST'), findsOneWidget); // Cart panel title

    // Logout
    final logoutButton = find.text('Logout');
    expect(logoutButton, findsWidgets);
    await tester.tap(logoutButton.first);
    await tester.pumpAndSettle();

    // Dialog konfirmasi logout
    expect(find.text('Logout'), findsWidgets); 
    await tester.tap(find.text('Logout').last); // Biasanya tombol Confirm paling akhir
    await tester.pumpAndSettle();

    // Assert: kembali ke layar login
    expect(find.text('LOGIN TO POS'), findsOneWidget);
  });
}
