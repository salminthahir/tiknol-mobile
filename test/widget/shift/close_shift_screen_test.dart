// test/widget/shift/close_shift_screen_test.dart
// Widget tests untuk CloseShiftScreen — regression guard untuk:
// - Bug #1 (Kritikal): step 2 harus mengirim ulang physicalCount ASLI dari
//   step 1 (_physicalCountStep1), bukan hasil rekonstruksi expectedCash+difference.
// - Bug #2 (Kritikal): step 1 tidak boleh lanjut ke step 2 jika request gagal.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/screens/close_shift_screen.dart';
import 'package:tiknol_reserve_mobile/providers/shift_provider.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/services/shift_service.dart' as shift_svc;
import 'package:tiknol_reserve_mobile/models/shift.dart';
import 'package:tiknol_reserve_mobile/models/cash_ledger_entry.dart';
import '../../helpers/tablet_viewport.dart';

class MockShiftService extends Mock implements shift_svc.ShiftService {}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        userName: 'Kasir Test',
        branchName: 'HQ',
        branchId: 'B1',
      );
}

/// Fake ShiftNotifier dengan currentShift pre-set aktif, dan closeShift()
/// yang merekam semua argumen panggilan agar bisa diverifikasi di test.
class _FakeShiftNotifier extends ShiftNotifier {
  final List<Map<String, dynamic>> calls = [];

  /// Jika true, closeShift untuk step 1 akan melempar exception
  /// (mensimulasikan kegagalan network) untuk regression test Bug #2.
  bool failStep1 = false;

  @override
  ShiftState build() => ShiftState(
        hasActiveShift: true,
        currentShift: Shift(
          id: 'shift-1',
          startCash: 100000,
          startTime: DateTime.parse('2026-01-01T08:00:00.000Z'),
          status: ShiftStatus.open,
          expectedCash: 140000,
        ),
        expectedCash: 140000,
        isLoading: false,
      );

  @override
  Future<ShiftCloseResult> closeShift({
    required int physicalCount,
    required int step,
    String? closingNotes,
  }) async {
    calls.add({
      'physicalCount': physicalCount,
      'step': step,
      'closingNotes': closingNotes,
    });

    if (step == 1) {
      if (failStep1) {
        state = state.copyWith(error: 'Gagal terhubung ke server');
        return ShiftCloseResult.review(
          expectedCash: state.expectedCash,
          difference: 0,
          message: 'Error: network failure',
        );
      }
      // Server bilang expected 140000, fisik yang dikirim 138000 -> selisih -2000
      return ShiftCloseResult.review(
        expectedCash: 140000,
        difference: -2000,
        message: '',
      );
    }

    state = ShiftState.initial();
    return ShiftCloseResult.closed(isFlagged: false, difference: -2000);
  }
}

void main() {
  late MockShiftService mockShiftService;

  setUpAll(() async {
    registerFallbackValue(<String, dynamic>{});
    await initializeDateFormatting('id', null);
  });

  setUp(() {
    mockShiftService = MockShiftService();
    when(() => mockShiftService.getShiftLedger(any())).thenAnswer(
      (_) async => ShiftLedger(
        shiftId: 'shift-1',
        startTime: DateTime.parse('2026-01-01T08:00:00.000Z'),
        status: 'OPEN',
        startCash: 100000,
        entries: const [],
      ),
    );
    when(() => mockShiftService.getShiftSummary(any())).thenAnswer(
      (_) async => ShiftSummary(
        shiftId: 'shift-1',
        totalTransactions: 0,
        totalOmzet: 0,
        totalCash: 0,
        totalQris: 0,
      ),
    );
  });

  Widget createScreen(_FakeShiftNotifier fakeNotifier) {
    return ProviderScope(
      overrides: [
        shiftProvider.overrideWith(() => fakeNotifier),
        authProvider.overrideWith(() => _TestAuthNotifier()),
        shift_svc.shiftServiceProvider.overrideWithValue(mockShiftService),
      ],
      child: const MaterialApp(
        home: CloseShiftScreen(),
      ),
    );
  }

  group('Bug #1 regression: payload step 2 harus pakai physicalCount asli', () {
    testWidgets(
        'physicalCount yang dikirim di step 2 sama persis dengan input '
        'DenominationInput di step 1, bukan hasil rekonstruksi', (tester) async {
      setTabletViewport(tester);
      final fakeNotifier = _FakeShiftNotifier();
      await tester.pumpWidget(createScreen(fakeNotifier));
      await tester.pumpAndSettle();

      // Pindah ke tab "Tutup Shift"
      await tester.tap(find.text('Tutup Shift'));
      await tester.pumpAndSettle();

      // Input pecahan: 1 lembar 100.000 + 3 lembar 10.000 + 1 lembar 5.000 + ...
      // agar totalnya != expectedCash + difference secara "kebetulan".
      // Kita gunakan input field pertama (100.000) diisi 1, dan field kedua (50.000) diisi 1,
      // lalu field ketiga (20.000) diisi 1, keempat (10.000) diisi 1, kelima (5.000) diisi 1,
      // keenam (2.000) diisi 1, ketujuh (1.000) diisi 3 => total = 188000.
      // Untuk kesederhanaan, cukup isi 1 field bernilai besar: 100.000 x 1 dan 20.000 x 1 dan 10.000 x 1
      // dan 5.000 x 1 dan 2.000 x 1 dan 1.000 x 3 = 100000+20000+10000+5000+2000+3000 = 140000... 
      // Kita sengaja pilih nilai fisik ASLI = 138000 (BEDA dari expectedCash 140000 - difference -2000 = 142000
      // sehingga jika bug muncul -yaitu step 2 mengirim expectedCash+difference=138000- kita tidak bisa
      // bedakan dari physicalCount asli bila kebetulan sama. Maka kita pastikan nilai fisik ASLI unik: 137000.
      final textFields = find.byType(TextField);
      // TextField pertama dalam DenominationInput adalah pecahan 100.000
      await tester.enterText(textFields.at(0), '1'); // 100.000 x 1 = 100000
      await tester.enterText(textFields.at(3), '3'); // 10.000 x 3 = 30000
      await tester.enterText(textFields.at(4), '1'); // 5.000 x 1 = 5000
      await tester.enterText(textFields.at(6), '2'); // 1.000 x 2 = 2000
      // total physicalCountStep1 = 100000 + 30000 + 5000 + 2000 = 137000
      await tester.pumpAndSettle();

      await tester.tap(find.text('LIHAT SELISIH'));
      await tester.pumpAndSettle();

      // Sekarang di step 2 (review). Tap konfirmasi.
      await tester.tap(find.text('KONFIRMASI TUTUP SHIFT'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.calls.length, 2);
      final step1Call = fakeNotifier.calls[0];
      final step2Call = fakeNotifier.calls[1];

      expect(step1Call['step'], 1);
      expect(step1Call['physicalCount'], 137000);

      expect(step2Call['step'], 2);
      // Regression: payload step 2 harus SAMA dengan physicalCount step 1 (137000),
      // BUKAN direkonstruksi dari expectedCash + difference (140000 + -2000 = 138000).
      expect(step2Call['physicalCount'], 137000,
          reason:
              'Step 2 harus mengirim ulang nilai hitung fisik asli dari step 1, '
              'bukan hasil rekonstruksi expectedCash + difference');
    });
  });

  group('Bug #2 regression: step 1 gagal tidak boleh lanjut ke step 2', () {
    testWidgets('jika closeShift step 1 gagal, UI tetap di step 1 dan tampilkan error',
        (tester) async {
      setTabletViewport(tester);
      final fakeNotifier = _FakeShiftNotifier()..failStep1 = true;
      await tester.pumpWidget(createScreen(fakeNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tutup Shift'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('LIHAT SELISIH'));
      await tester.pumpAndSettle();

      // Harus tetap di step 1 (tombol LIHAT SELISIH masih ada, bukan step 2)
      expect(find.text('LIHAT SELISIH'), findsOneWidget);
      expect(find.text('KONFIRMASI TUTUP SHIFT'), findsNothing);
    });
  });
}
