# Functional Testing Plan — Full Pyramid (Tablet Android)

**Version**: 2.0.0 — Opsi B: Full Pyramid  
**Date**: 2025-07-01  
**Scope**: `tiknol-mobile-flutter` (Flutter Android Tablet POS)  
**Target Hardware**: Android Tablet (10", landscape, minimum API 21)  
**Framework**: `flutter_test` + `mocktail` + `integration_test` + `flutter_driver`  

---

## 1. Executive Summary

Pilihan **Opsi B: Full Pyramid** berarti test suite mencakup ketiga level:

| Level | Eksekusi | Environment | Coverage Target |
|-------|----------|-------------|-----------------|
| **Unit Test** | `flutter test` | Laptop (headless) | 70% |
| **Widget Test** | `flutter test` | Laptop (headless + tablet viewport) | 25% |
| **Integration Test** | `flutter test integration_test/` | **Android Tablet / Emulator** | 5% (critical paths only) |

> **Kenapa Integration Test harus di tablet?** Karena fitur POS bersentuhan dengan hardware & OS: Bluetooth printer, camera (face verify), permission dialog, WebView rendering engine, dan multi-touch interaction. Semua ini tidak bisa tervalidasi di headless environment.

---

## 2. Test Infrastructure Setup

### 2.1 Dependencies (`pubspec.yaml`)

Tambahkan ke `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  integration_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
```

### 2.2 Directory Structure

```
tiknol-mobile-flutter/
├── integration_test/                 # NEW: Integration test suite
│   ├── README.md                     # Cara run integration test
│   ├── screenshots/                  # Hasil screenshot automation
│   ├── flows/
│   │   ├── auth_flow_test.dart       # Login → Logout
│   │   ├── cash_order_flow_test.dart # POS → Cart → Cash → Print
│   │   ├── qris_order_flow_test.dart # POS → Cart → QRIS → Paid → Print
│   │   ├── kitchen_flow_test.dart    # Kitchen status update cycle
│   │   ├── printer_flow_test.dart    # Bluetooth scan → connect → test print
│   │   └── product_mgmt_flow_test.dart # CRUD product
│   ├── helpers/
│   │   ├── integration_tester.dart   # Wrapper around WidgetTester
│   │   ├── tablet_config.dart        # Set tablet viewport & orientation
│   │   ├── bluetooth_helper.dart     # BLE/Classic mock or real
│   │   └── screenshot_helper.dart    # Capture screen per step
│   └── page_objects/                 # Screen abstraction (Page Object Pattern)
│       ├── login_page.dart
│       ├── pos_page.dart
│       ├── cart_panel.dart
│       ├── qris_page.dart
│       ├── kitchen_page.dart
│       ├── printer_page.dart
│       └── history_page.dart
│
├── test/                             # EXISTING (unit + widget)
│   ├── fixtures/
│   ├── helpers/
│   ├── unit/
│   │   ├── auth/
│   │   ├── cart/
│   │   ├── payment/
│   │   ├── kitchen/
│   │   ├── printer/
│   │   └── product/
│   ├── widget/
│   │   ├── auth/
│   │   ├── pos/
│   │   ├── cart/
│   │   ├── payment/
│   │   ├── kitchen/
│   │   ├── history/
│   │   ├── printer/
│   │   └── product/
│   └── security/                     # DO NOT MODIFY
│       ├── payment_flow_integration_test.dart
│       ├── payment_webview_spoof_test.dart
│       ├── order_service_tampering_test.dart
│       └── transport_security_test.dart
│
└── docs/
    └── FUNCTIONAL_TESTING_PLAN.md    # This document
```

---

## 3. Level 1 — Unit Test (Laptop, Headless)

### 3.1 Scope
Logic murni tanpa dependensi UI atau hardware. Semua external (API, DB, storage) di-mock.

### 3.2 Modul & Target

| Modul | File Target | UC-ID | Test Case |
|-------|-------------|-------|-----------|
| **Cart** | `providers/cart_provider.dart` | `CART-01` | Subtotal = Σ(price × qty) |
| | | `CART-02` | Increment qty updates total |
| | | `CART-03` | Remove item updates total |
| | | `CART-08` | Voucher discount applied correctly |
| **Payment** | `services/order_service.dart` | `PAY-03` | Tokenizer request payload correct |
| | | `PAY-05` | Polling interval = 5s, max 10 min |
| | | `PAY-11` | Retry 3× on network error |
| | | `PAY-12` | Fail-closed: error ≠ PAID |
| **Auth** | `providers/auth_provider.dart` | `AUTH-03` | Session restore dari secure storage |
| | | `AUTH-04` | 401 trigger logout |
| **Kitchen** | `providers/kitchen_provider.dart` | `KIT-02` | Group by status correctly |
| | | `KIT-04` | Optimistic update logic |
| | | `KIT-06` | Rollback on failure |
| **Printer** | `services/printer_service.dart` | `PRNT-07` | ESC/POS bytes generation |
| | | `PRNT-09` | Logo resize to 384px |
| **Product** | `providers/product_provider.dart` | `PROD-05` | Toggle availability |

### 3.3 Run Command
```bash
flutter test test/unit/
```

---

## 4. Level 2 — Widget Test (Laptop, Headless + Tablet Viewport)

### 4.1 Scope
Render widget, simulasi interaksi (tap, scroll, input), verifikasi state/UI change. Semua eksternal di-mock.

### 4.2 Tablet Viewport Configuration

Setiap widget test untuk tablet **WAJIB** set viewport:

```dart
// test/helpers/tablet_viewport.dart
import 'package:flutter_test/flutter_test.dart';

void setTabletViewport(WidgetTester tester) {
  tester.binding.window.physicalSize = const Size(1920, 1200); // 10" tablet landscape
  tester.binding.window.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.binding.window.clearPhysicalSizeTestValue();
    tester.binding.window.clearDevicePixelRatioTestValue();
  });
}
```

### 4.3 Modul & Target

| Modul | Widget Target | UC-ID | Test Case |
|-------|--------------|-------|-----------|
| **Auth** | `LoginScreen` | `AUTH-01` | Render form, tap login, show loading, navigate |
| | | `AUTH-02` | Show error on invalid credentials |
| **POS** | `PosScreen` | `POS-02` | Filter chip tap → grid update |
| | | `POS-03` | Search input → grid filter |
| | | `POS-05` | Tap product → bottom sheet → select variant |
| | | `POS-06` | Add to cart → cart badge update |
| **Cart** | `CartPanel` | `CART-02` | +/- button updates qty & total |
| | | `CART-04` | Order type toggle |
| | | `CART-06` | Valid voucher → show discount |
| | | `CART-07` | Invalid voucher → show error |
| | | `CART-10` | Pay button → confirmation dialog |
| **Payment** | `QrisPaymentScreen` | `PAY-04` | QR code rendered |
| | | `PAY-06` | Countdown timer displayed |
| | `PaymentWebView` | `PAY-09` | Block navigation to non-Duitku host |
| | | `PAY-10` | Detect return URL → pop |
| **Kitchen** | `KitchenScreen` | `KIT-03` | Kanban columns rendered (tablet layout) |
| | | `KIT-04` | Tap action → card moves column |
| **History** | `HistoryScreen` | `HIST-02` | Date chip tap → list filter |
| | | `HIST-06` | Scroll to bottom → load more |
| **Printer** | `PrinterSettingsScreen` | `PRNT-08` | Template field input → preview update |
| **Product** | `ProductManagementScreen` | `PROD-02` | Fill form → tap save → validate |

### 4.4 Run Command
```bash
flutter test test/widget/
```

---

## 5. Level 3 — Integration Test (Android Tablet / Emulator)

### 5.1 Scope
**End-to-end flow di app beneran** yang berjalan di Android OS. Tidak ada mock untuk hardware atau OS-level behavior.

### 5.2 Hardware Requirements

| Item | Requirement |
|------|-------------|
| **Device** | Android Tablet (10", landscape) minimum API 21 |
| **OS** | Android 10+ (API 29) recommended |
| **Bluetooth** | BLE + Classic support (untuk printer flow) |
| **Network** | WiFi (backend localhost atau staging) |
| **Storage** | 2GB free untuk app data & screenshots |

### 5.3 Emulator Setup (Alternatif Device Fisik)

```bash
# Buat AVD tablet
cd $ANDROID_HOME/cmdline-tools/latest/bin
./avdmanager create avd -n tablet_10inch -k "system-images;android-30;google_apis;x86_64" -d "pixel_c"

# Jalankan emulator
emulator -avd tablet_10inch -no-snapshot-load -no-audio -gpu swiftshader_indirect
```

### 5.4 Page Object Pattern

Setiap screen diwakili class agar test readable & maintainable:

```dart
// integration_test/page_objects/pos_page.dart
class PosPage {
  PosPage(this.tester);
  final WidgetTester tester;

  Future<void> tapProduct(String productName) async {
    await tester.tap(find.text(productName));
    await tester.pumpAndSettle();
  }

  Future<void> selectVariant({String? temp, String? size}) async {
    if (temp != null) await tester.tap(find.text(temp));
    if (size != null) await tester.tap(find.text(size));
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
  }

  Future<void> openCart() async {
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();
  }
}
```

### 5.5 Integration Test Cases

#### `integration_test/flows/auth_flow_test.dart`
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AUTH-01: Staff login → POS → Logout', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Login
    await tester.enterText(find.byKey(Key('employeeId')), 'EMP001');
    await tester.enterText(find.byKey(Key('pin')), '1234');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Assert: navigated to ShellScreen
    expect(find.byType(ShellScreen), findsOneWidget);

    // Logout
    await tester.tap(find.byIcon(Icons.logout));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Assert: back to LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
```

#### `integration_test/flows/cash_order_flow_test.dart`
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PAY-02: Complete cash order flow', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Precondition: already logged in (use pre-authenticated state or login)
    
    // 1. Select product
    await tester.tap(find.text('Americano'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ICE'));
    await tester.tap(find.text('L'));
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    // 2. Open cart
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // 3. Set customer name
    await tester.enterText(find.byKey(Key('customerName')), 'Budi');

    // 4. Tap Pay Cash
    await tester.tap(find.text('Bayar Cash'));
    await tester.pumpAndSettle();

    // 5. Confirm dialog
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 6. Assert: success dialog
    expect(find.text('Pembayaran Berhasil'), findsOneWidget);

    // 7. Assert: cart empty
    expect(find.text('Keranjang Kosong'), findsOneWidget);

    // 8. Screenshot
    await binding.takeScreenshot('cash_order_success');
  });
}
```

#### `integration_test/flows/qris_order_flow_test.dart`
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PAY-07: QRIS order → polling → paid → receipt', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // 1. Add product to cart
    await tester.tap(find.text('Espresso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    // 2. Open cart & pay QRIS
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar QRIS'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 3. Assert: QRIS screen with QR code
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Menunggu Pembayaran'), findsOneWidget);

    // 4. Simulate external payment (mock or staging backend trigger)
    // OR wait for real payment in sandbox
    await tester.pumpAndSettle(const Duration(seconds: 30));

    // 5. Assert: success state
    expect(find.text('Pembayaran Berhasil'), findsOneWidget);
  });
}
```

#### `integration_test/flows/printer_flow_test.dart`
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PRNT-10: Bluetooth scan → connect → test print', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    // Navigate to Printer Settings
    await tester.tap(find.byIcon(Icons.print));
    await tester.pumpAndSettle();

    // Request permissions (Android dialog)
    await tester.tap(find.text('Grant Permissions'));
    await tester.pumpAndSettle();
    // Note: Permission dialog is OS-level, may need `uiautomator` or manual grant

    // Scan devices
    await tester.tap(find.text('Scan Devices'));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Select first found device
    final firstDevice = find.byType(ListTile).first;
    await tester.tap(firstDevice);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Test print
    await tester.tap(find.text('Test Print'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Assert: no error snackbar
    expect(find.text('Print Error'), findsNothing);
  });
}
```

### 5.6 Run Integration Test

```bash
# Di device fisik (tablet Android via USB)
flutter test integration_test/flows/cash_order_flow_test.dart -d <device_id>

# Di emulator
flutter test integration_test/flows/ --no-pub -d emulator-5554

# Semua integration test
flutter test integration_test/
```

---

## 6. CI/CD Integration (GitHub Actions / Codemagic)

### 6.1 Unit + Widget Test (Fast, di runner)

```yaml
# .github/workflows/test.yml
name: Unit & Widget Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
      - run: flutter pub get
      - run: flutter test test/unit/ --coverage
      - run: flutter test test/widget/ --coverage
      - run: flutter test test/security/ --coverage
```

### 6.2 Integration Test (Tablet Emulator, di runner atau self-hosted)

```yaml
# .github/workflows/integration-test.yml
name: Integration Tests (Tablet)
on: [push]
jobs:
  integration:
    runs-on: macos-latest # macOS supports Android emulator
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
      - name: Setup Android Emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 30
          arch: x86_64
          profile: pixel_c # 10" tablet
          script: |
            flutter pub get
            flutter test integration_test/flows/auth_flow_test.dart
            flutter test integration_test/flows/cash_order_flow_test.dart
```

> **Note**: Integration test dengan Bluetooth **tidak bisa** di emulator (Bluetooth di-emulated). Untuk PRNT-10, butuh **self-hosted runner** dengan tablet fisik terhubung, atau run manual.

---

## 7. Execution Roadmap (4 Sprint)

### Sprint 1: Foundation & Unit Tests
**Deliverable**: 100% unit test untuk critical logic

| Day | Task | Output |
|-----|------|--------|
| 1-2 | Setup `test/helpers/`, `test/fixtures/`, mock classes | `test/helpers/mock_services.dart` |
| 3-4 | Unit: Cart & Pricing (`CART-01` s/d `CART-08`) | `test/unit/cart/` |
| 5-6 | Unit: Payment Logic (`PAY-03`, `PAY-05`, `PAY-11`, `PAY-12`) | `test/unit/payment/` |
| 7 | Unit: Auth & Kitchen (`AUTH-03`, `AUTH-04`, `KIT-02` s/d `KIT-06`) | `test/unit/auth/`, `test/unit/kitchen/` |
| 8 | Unit: Printer (`PRNT-07`, `PRNT-09`) | `test/unit/printer/` |
| 9-10 | Code review, coverage report, refactor | `coverage/lcov.info` |

**Definition of Done**: `flutter test test/unit/` pass, coverage ≥70%.

### Sprint 2: Widget Tests (Tablet Viewport)
**Deliverable**: Widget tests untuk semua screen utama dengan tablet viewport

| Day | Task | Output |
|-----|------|--------|
| 1-2 | Setup `test/helpers/tablet_viewport.dart` | Helper function |
| 3-4 | Widget: Auth & POS (`AUTH-01`, `AUTH-02`, `POS-02` s/d `POS-06`) | `test/widget/auth/`, `test/widget/pos/` |
| 5-6 | Widget: Cart & Payment (`CART-02` s/d `CART-10`, `PAY-04`, `PAY-06`, `PAY-09`, `PAY-10`) | `test/widget/cart/`, `test/widget/payment/` |
| 7-8 | Widget: Kitchen, History, Printer, Product | `test/widget/kitchen/`, `test/widget/history/`, etc. |
| 9-10 | Coverage review, fix flaky tests | Stable widget test suite |

**Definition of Done**: `flutter test test/widget/` pass, tidak ada `pumpAndSettle` tanpa bound.

### Sprint 3: Integration Tests (Device)
**Deliverable**: Integration test suite yang jalan di tablet Android

| Day | Task | Output |
|-----|------|--------|
| 1-2 | Setup `integration_test/` structure, Page Objects | `integration_test/page_objects/` |
| 3-4 | Integration: Auth Flow (`auth_flow_test.dart`) | Login → Logout |
| 5-6 | Integration: Cash Order Flow (`cash_order_flow_test.dart`) | POS → Cart → Cash → Receipt |
| 7 | Integration: QRIS Flow (`qris_order_flow_test.dart`) | POS → Cart → QRIS → Paid |
| 8 | Integration: Kitchen Flow (`kitchen_flow_test.dart`) | Status update cycle |
| 9 | Integration: Printer Flow (`printer_flow_test.dart`) | Bluetooth → Print |
| 10 | Integration: Product Mgmt Flow (`product_mgmt_flow_test.dart`) | CRUD product |

**Definition of Done**: `flutter test integration_test/` pass di tablet / emulator.

### Sprint 4: CI/CD & Hardening
**Deliverable**: Automated pipeline + final coverage ≥70%

| Day | Task | Output |
|-----|------|--------|
| 1-2 | Setup GitHub Actions untuk unit + widget | `.github/workflows/test.yml` |
| 3-4 | Setup integration test runner (emulator atau self-hosted) | `.github/workflows/integration-test.yml` |
| 5 | Screenshot automation pada integration test failure | `integration_test/screenshots/` |
| 6-7 | Performance test: app startup time < 3s | `test/performance/startup_test.dart` |
| 8-9 | Accessibility audit (talkback, font scaling) | A11y report |
| 10 | Final coverage report & documentation update | `docs/TEST_REPORT.md` |

---

## 8. Risk & Mitigation (Tablet-Specific)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Bluetooth tidak tersedia di emulator** | PRNT-10 gagal | Gunakan device fisik untuk printer test; di emulator mock `flutter_bluetooth_serial` |
| **Permission dialog Android blocking test** | Flow terhenti | Grant permission via ADB sebelum test: `adb shell pm grant <package> <permission>` |
| **WebView rendering beda emulator vs real device** | PAY-09 flaky | Test WebView hanya di device fisik; di emulator gunakan mock |
| **Tablet landscape rotation** | Layout break | Lock orientation di `AndroidManifest.xml`; test hanya landscape |
| **Slow emulator** | Integration test timeout | Gunakan emulator dengan GPU acceleration; naikkan timeout ke 60s |
| **Backend tidak available saat test** | Semua flow gagal | Gunakan mock backend (mockserver/mechanize) atau staging environment |

---

## 9. Definition of Done (Global)

- [ ] Unit test coverage ≥70% (verified by `flutter test --coverage`)
- [ ] Widget test coverage ≥50% (critical screens)
- [ ] Integration test pass di tablet Android (physical atau emulator)
- [ ] Tidak ada test flaky (run 10× berturut-turut, 100% pass)
- [ ] CI/CD pipeline hijau (unit + widget auto-run di setiap PR)
- [ ] Integration test hijau (nightly run atau pre-release gate)
- [ ] Screenshot / screen recording tersedia untuk setiap integration test flow
- [ ] Security tests (existing) tetap pass dan tidak ter-regresi

---

## Appendix A: Tablet-Specific Test Configuration

### AndroidManifest.xml
```xml
<activity
    android:name=".MainActivity"
    android:screenOrientation="landscape"> <!-- Lock landscape -->
```

### Integration Test Entry Point
```dart
// integration_test/helpers/integration_tester.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class TabletIntegrationTester {
  static void initialize() {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    // Set default timeout for slow tablet interactions
    WidgetTester.binding.defaultTestTimeout = const Duration(minutes: 5);
  }
}
```

### ADB Commands for Test Preparation
```bash
# Grant all permissions before running test
adb shell pm grant com.example.tiknol_reserve_mobile android.permission.BLUETOOTH_SCAN
adb shell pm grant com.example.tiknol_reserve_mobile android.permission.BLUETOOTH_CONNECT
adb shell pm grant com.example.tiknol_reserve_mobile android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.tiknol_reserve_mobile android.permission.CAMERA

# Set screen always on during test
adb shell svc power stayon true

# Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

---

## Appendix B: Deployment & Build Exclusions (Test Files)

> **Penting**: Semua file testing **TIDAK** ikut masuk ke build production (APK/AAB). Ini adalah default behavior Flutter dan telah diverifikasi.

### Apa yang DIKECUALIKAN dari Release Build

| Direktori / File | Masuk Build? | Keterangan |
|------------------|--------------|------------|
| `test/` | ❌ **Tidak** | Unit & widget tests — Flutter build mengabaikan direktori ini |
| `integration_test/` | ❌ **Tidak** | Integration tests — sama, diabaikan saat `flutter build` |
| `test/fixtures/` | ❌ **Tidak** | JSON fixtures untuk test data |
| `test/helpers/` | ❌ **Tidak** | Mock classes & test utilities |
| `coverage/` | ❌ **Tidak** | LCOV coverage reports (sudah di `.gitignore`) |
| `docs/` | ❌ **Tidak** | Markdown dokumentasi (opsional, bisa di-exclude) |
| `dev_dependencies` | ❌ **Tidak** | `mocktail`, `integration_test`, dll — tidak di-link ke release |
| `*.test.dart` | ❌ **Tidak** | File dengan suffix `.test.dart` |

### Verifikasi Konfigurasi Build

File `android/app/build.gradle.kts` saat ini **standar** — tidak ada directive yang secara accidental menyertakan direktori test:

```kotlin
// android/app/build.gradle.kts (current)
flutter {
    source = "../.."  // Hanya pointing ke root project, tidak include test/
}
```

### Yang MASUK ke Release Build

Hanya direktori & file berikut yang dipaket ke APK/AAB:

- `lib/` — Dart source code aplikasi
- `assets/` — Gambar, font, icon
- `android/` — Native Android code & manifest
- `pubspec.yaml` — Dependencies production (`dependencies`, BUKAN `dev_dependencies`)

### Pre-Deployment Checklist (Opsional)

Jika ingin **double-verify** sebelum deployment:

```bash
# 1. Build APK release
flutter build apk --release

# 2. Analisis APK (paket yang ter-install)
# Android Studio → Build → Analyze APK → Lihat classes.dex & assets/
# Tidak akan ada file .test.dart atau direktori test/

# 3. Verifikasi ukuran APK tidak membengkak
# APK seharusnya ~15-25MB (tergantung assets), test files tidak menambah ukuran
```

### CI/CD Guard (GitHub Actions)

Tambahkan step ini ke pipeline deployment untuk memastikan test files tidak ter-commit ke branch production:

```yaml
# .github/workflows/deploy.yml (optional guard)
- name: Verify no test files in release branch
  run: |
    if ls test/ integration_test/ 1> /dev/null 2>&1; then
      echo "❌ Test directories found in release branch!"
      exit 1
    fi
    echo "✅ No test files in release branch"
```

> **Catatan**: Jika menggunakan **monorepo** atau **multi-package**, pastikan `pubspec.yaml` tidak memasukkan `test/` ke `assets:` atau `fonts:`.

---

*Document Owner: Engineering Team*  
*Target Hardware: Android Tablet 10" (Landscape)*  
*Integration Test Requirement: MUST run on real Android OS (emulator or physical)*
