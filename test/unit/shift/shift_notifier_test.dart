// test/unit/shift/shift_notifier_test.dart
// Unit tests untuk ShiftNotifier (SHIFT-01 s/d SHIFT-06)
//
// Regression coverage untuk bug yang ditemukan di
// Docs/plan/shift-system-audit-and-improvement-plan.md:
// - Bug #1 (Kritikal): payload step 2 close-shift harus memakai nilai
//   physicalCount yang benar-benar dikirim ke server, bukan hasil
//   rekonstruksi (expectedCash + difference).
// - Bug #4 (Tinggi): refreshExpectedCash tidak boleh menelan error diam-diam.
// - Bug #5 (Sedang): 409 saat openShift tidak boleh menimpa pesan error asli
//   tanpa indikasi apapun ke caller.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:tiknol_reserve_mobile/providers/shift_provider.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:tiknol_reserve_mobile/models/cash_ledger_entry.dart';
import '../../helpers/mock_services.dart';

void main() {
  late ProviderContainer container;
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.client).thenReturn(mockDio);
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Response<dynamic> jsonResponse(String path, Map<String, dynamic> data) {
    return Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }

  group('openShift', () {
    test('SHIFT-01: sukses menyimpan currentShift & expectedCash', () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/open', {
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 100000,
              }));

      final notifier = container.read(shiftProvider.notifier);
      final ok = await notifier.openShift(100000);

      expect(ok, isTrue);
      final state = container.read(shiftProvider);
      expect(state.hasActiveShift, isTrue);
      expect(state.currentShift?.id, 'shift-1');
      expect(state.expectedCash, 100000);
      expect(state.error, isNull);
    });

    test('SHIFT-02: gagal (bukan 409) menyimpan pesan error', () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/shift/open'),
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/api/shift/open'),
        ),
        message: 'Server error 500',
      ));

      final notifier = container.read(shiftProvider.notifier);
      final ok = await notifier.openShift(100000);

      expect(ok, isFalse);
      final state = container.read(shiftProvider);
      expect(state.hasActiveShift, isFalse);
      expect(state.error, isNotNull);
    });

    test('SHIFT-03: 409 memicu checkActiveShift tanpa exception', () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/shift/open'),
        response: Response(
          statusCode: 409,
          requestOptions: RequestOptions(path: '/api/shift/open'),
        ),
        message: 'DioException [409]: conflict',
      ));
      when(() => mockDio.get('/api/shift/current'))
          .thenAnswer((_) async => jsonResponse('/api/shift/current', {
                'hasActiveShift': true,
                'id': 'shift-existing',
                'startCash': 50000,
                'startTime': '2026-01-01T07:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 55000,
              }));

      final notifier = container.read(shiftProvider.notifier);
      final ok = await notifier.openShift(100000);

      expect(ok, isFalse);
      final state = container.read(shiftProvider);
      expect(state.hasActiveShift, isTrue);
      expect(state.currentShift?.id, 'shift-existing');
    });
  });

  group('closeShift — regression payload step 2 (Bug #1)', () {
    test(
        'SHIFT-04: physicalCount yang dikirim ke service pada step 2 harus '
        'sama persis dengan nilai yang diberikan notifier (bukan hasil '
        'rekonstruksi lain)', () async {
      // Setup: shift aktif
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/open', {
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 100000,
              }));
      final notifier = container.read(shiftProvider.notifier);
      await notifier.openShift(100000);

      // Step 1: hitung fisik asli kasir = 138000, expectedCash server = 140000
      when(() => mockDio.post('/api/shift/close', data: any(named: 'data')))
          .thenAnswer((invocation) async {
        final sentData =
            invocation.namedArguments[#data] as Map<String, dynamic>;
        if (sentData['step'] == 1) {
          return jsonResponse('/api/shift/close', {
            'expectedCash': 140000,
            'difference': -2000, // 138000 - 140000
            'message': '',
          });
        }
        return jsonResponse('/api/shift/close', {
          'isFlagged': false,
          'difference': -2000,
        });
      });

      const physicalCountAsli = 138000;

      final step1Result = await notifier.closeShift(
        physicalCount: physicalCountAsli,
        step: 1,
      );
      expect(step1Result.expectedCash, 140000);
      expect(step1Result.difference, -2000);

      // Step 2 — HARUS mengirim ulang physicalCountAsli (138000), BUKAN
      // expectedCash + difference (140000 + -2000 = 138000, kebetulan sama
      // secara aritmatika tapi harus tetap berasal dari sumber yang benar).
      await notifier.closeShift(
        physicalCount: physicalCountAsli,
        step: 2,
      );

      final captured = verify(() => mockDio.post(
            '/api/shift/close',
            data: captureAny(named: 'data'),
          )).captured;

      // captured[0] = step 1 call, captured[1] = step 2 call
      final step2Payload = captured[1] as Map<String, dynamic>;
      expect(step2Payload['step'], 2);
      expect(step2Payload['physicalCount'], physicalCountAsli);
    });

    test('SHIFT-05: closeShift step 2 mereset state ke initial saat sukses',
        () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/open', {
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 100000,
              }));
      final notifier = container.read(shiftProvider.notifier);
      await notifier.openShift(100000);

      when(() => mockDio.post('/api/shift/close', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/close', {
                'isFlagged': false,
                'difference': 0,
              }));

      await notifier.closeShift(physicalCount: 100000, step: 2);

      final state = container.read(shiftProvider);
      expect(state.hasActiveShift, isFalse);
      expect(state.currentShift, isNull);
    });

    test('SHIFT-06: closeShift tanpa shift aktif mengembalikan pesan error',
        () async {
      final notifier = container.read(shiftProvider.notifier);
      final result =
          await notifier.closeShift(physicalCount: 1000, step: 1);
      expect(result.message, 'Tidak ada shift aktif');
      verifyNever(() => mockDio.post('/api/shift/close',
          data: any(named: 'data')));
    });
  });

  group('refreshExpectedCash', () {
    test('SHIFT-07: sukses memperbarui expectedCash', () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/open', {
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 100000,
              }));
      final notifier = container.read(shiftProvider.notifier);
      await notifier.openShift(100000);

      when(() => mockDio.get('/api/shift/current'))
          .thenAnswer((_) async => jsonResponse('/api/shift/current', {
                'hasActiveShift': true,
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 175000,
              }));

      await notifier.refreshExpectedCash();
      expect(container.read(shiftProvider).expectedCash, 175000);
    });

    test('SHIFT-08: tidak melakukan apa-apa jika tidak ada shift aktif',
        () async {
      final notifier = container.read(shiftProvider.notifier);
      await notifier.refreshExpectedCash();
      verifyNever(() => mockDio.get('/api/shift/current'));
    });
  });

  group('recordManualCash', () {
    test('SHIFT-09: sukses mencatat & refresh expectedCash', () async {
      when(() => mockDio.post('/api/shift/open', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/shift/open', {
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 100000,
              }));
      final notifier = container.read(shiftProvider.notifier);
      await notifier.openShift(100000);

      when(() => mockDio.post('/api/cash-ledger', data: any(named: 'data')))
          .thenAnswer((_) async => jsonResponse('/api/cash-ledger', {
                'id': 'ledger-1',
                'shiftId': 'shift-1',
                'type': 'CASH_OUT',
                'amount': 20000,
                'note': 'Beli galon',
                'createdAt': '2026-01-01T09:00:00.000Z',
              }));
      when(() => mockDio.get('/api/shift/current'))
          .thenAnswer((_) async => jsonResponse('/api/shift/current', {
                'hasActiveShift': true,
                'id': 'shift-1',
                'startCash': 100000,
                'startTime': '2026-01-01T08:00:00.000Z',
                'status': 'OPEN',
                'expectedCash': 80000,
              }));

      final entry = await notifier.recordManualCash(
        type: CashLedgerType.cashOut,
        amount: 20000,
        note: 'Beli galon',
      );

      expect(entry, isNotNull);
      expect(container.read(shiftProvider).expectedCash, 80000);
    });

    test('SHIFT-10: tanpa shift aktif tidak memanggil service', () async {
      final notifier = container.read(shiftProvider.notifier);
      final entry = await notifier.recordManualCash(
        type: CashLedgerType.cashOut,
        amount: 20000,
        note: 'Beli galon',
      );
      expect(entry, isNull);
      verifyNever(() => mockDio.post('/api/cash-ledger', data: any(named: 'data')));
    });
  });
}
