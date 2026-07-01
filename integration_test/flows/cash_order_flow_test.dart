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

  testWidgets('PAY-02: Complete cash order flow', (tester) async {
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
    await posPage.tapProduct('Americanno MLG'); // Menggunakan nama produk dari database asli
    // Jika tidak punya varian, lewati selectVariant. Tapi sepertinya ada variant di DB?
    // Jika tidak ada bottom sheet yang muncul, hapus selectVariant.
    // await posPage.selectVariant(temp: 'ICE', size: 'L');

    // 2. Set customer name in cart
    await cartPanel.setCustomerName('Budi Test');

    // 3. Tap CASH
    await cartPanel.tapCash();

    // 4. Konfirmasi pembayaran Cash
    expect(find.text('Konfirmasi Pembayaran'), findsOneWidget);
    await tester.tap(find.text('Konfirmasi Bayar'));
    
    // Tunggu proses order API
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // 5. Verifikasi Sukses (Dialog / Snackbar)
    // Dialog biasanya ada tombol OK
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Pastikan cart kosong kembali
    expect(find.text('EMPTY ORDER'), findsOneWidget);
  });
}
