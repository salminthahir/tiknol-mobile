import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tiknol_reserve_mobile/main.dart' as app;
import 'package:tiknol_reserve_mobile/services/server_config_service.dart';
import '../helpers/tablet_config.dart';
import '../page_objects/login_page.dart';
import '../page_objects/pos_page.dart';
import '../page_objects/cart_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ServerConfigService.setBaseUrl('http://192.168.100.95:3000');
  });

  testWidgets('PAY-04: Complete QRIS order flow', (tester) async {
    await setTabletOrientation();
    app.main();
    await tester.pumpAndSettle();

    final loginPage = LoginPage(tester);
    final posPage = PosPage(tester);
    final cartPanel = CartPanelPage(tester);

    // 0. Precondition: Login first if needed
    if (find.text('LOGIN TO POS').evaluate().isNotEmpty) {
      await loginPage.login('EMP-001', '123456');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    // 1. Select product
    await posPage.tapProduct('Iced Tea'); // Produk tanpa varian, langsung masuk cart

    // 2. Set customer name in cart
    await cartPanel.setCustomerName('Caca QRIS Test');

    // 3. Tap QRIS
    await cartPanel.tapQris();

    // 4. Konfirmasi pembayaran QRIS
    expect(find.text('Konfirmasi Pembayaran'), findsOneWidget);
    await tester.tap(find.text('Konfirmasi Bayar'));
    
    // Tunggu proses tokenizer API
    // Gunakan runAsync agar real network request bisa berjalan sementara kita memantau UI
    await tester.runAsync(() async {
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        if (find.byType(SnackBar).evaluate().isNotEmpty) {
          final snackbarText = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
          final textWidget = tester.widget<Text>(snackbarText.first);
          // ignore: avoid_print
          print('QRIS API ERROR MESSAGE FOUND IN LOOP: ${textWidget.data}');
        }
        if (find.text('Konfirmasi Pembayaran').evaluate().isEmpty) {
          break; // Dialog sudah tertutup
        }
      }
    });
    
    // Beri waktu 1 detik lagi untuk screen transition (push WebView/QRIS screen)
    await tester.pump(const Duration(seconds: 1));

    // 5. Pastikan layar QRIS atau WebView muncul
    if (find.text('QRIS Payment').evaluate().isEmpty && find.text('Selesaikan Pembayaran').evaluate().isEmpty) {
      final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
      // ignore: avoid_print
      print('FAILED TO RENDER QRIS. TEXTS ON SCREEN: $allTexts');
      
      // Check if there is a SnackBar error
      if (find.byType(SnackBar).evaluate().isNotEmpty) {
        final snackbarText = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
        final textWidget = tester.widget<Text>(snackbarText.first);
        // ignore: avoid_print
        print('QRIS API ERROR MESSAGE: ${textWidget.data}');
      }
    }
    expect(
      find.text('QRIS Payment').evaluate().isNotEmpty || find.text('Selesaikan Pembayaran').evaluate().isNotEmpty,
      true,
    );

    // Tunggu 3 detik di layar QRIS
    await tester.pump(const Duration(seconds: 3));

    // 6. Karena kita tidak bisa scan/bayar di automation (dan ini ngehit backend/Duitku asli),
    // kita cancel (tekan tombol close)
    final closeButton = find.byIcon(Icons.close);
    await tester.tap(closeButton);
    await tester.pump(const Duration(seconds: 2));

    // Pastikan cart kembali muncul (atau error message dibatalkan)
    expect(find.text('DINE IN'), findsWidgets); // DINE IN button should be visible again
  });
}
