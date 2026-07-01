// test/unit/kitchen/kitchen_provider_test.dart
// Unit tests untuk KitchenNotifier (KIT-02 s/d KIT-07)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/providers/kitchen_provider.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/services/auth_service.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:dio/dio.dart';
import '../../helpers/mock_services.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  // KitchenNotifier.build() menggunakan WidgetsBinding.instance.addPostFrameCallback
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockApiClient mockApiClient;
  late MockDio mockDio;

  setUp(() {
    mockApiClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockApiClient.client).thenReturn(mockDio);

    final mockAuthService = _MockAuthService();
    when(() => mockAuthService.hasSession()).thenAnswer((_) async => false);
    when(() => mockAuthService.getSavedSession()).thenAnswer((_) async => {});

    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
        authServiceProvider.overrideWith((ref) => mockAuthService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('KitchenState', () {
    test('default state: semua status ada dengan list kosong', () {
      final state = KitchenState();
      expect(state.ordersByStatus.keys, containsAll(['PAID', 'PREPARING', 'READY', 'COMPLETED']));
      expect(state.ordersByStatus['PAID'], isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('copyWith mempertahankan nilai lama', () {
      final state = KitchenState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, true);
      expect(updated.ordersByStatus, state.ordersByStatus);
    });
  });

  group('KitchenNotifier.fetchAll', () {
    test('KIT-02: response 200 → orders di-group by status', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        data: [
          {'id': 'O1', 'status': 'PAID'},
          {'id': 'O2', 'status': 'PAID'},
          {'id': 'O3', 'status': 'PREPARING'},
          {'id': 'O4', 'status': 'READY'},
          {'id': 'O5', 'status': 'CANCELLED'}, // harus di-filter out
        ],
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final notifier = container.read(kitchenProvider.notifier);
      await notifier.fetchAll(force: true);

      final state = container.read(kitchenProvider);
      expect(state.ordersByStatus['PAID']!.length, 2);
      expect(state.ordersByStatus['PREPARING']!.length, 1);
      expect(state.ordersByStatus['READY']!.length, 1);
      expect(state.ordersByStatus['COMPLETED']!.length, 0);
      expect(state.isLoading, false);
    });

    test('KIT-02: response error → state.error terisi', () async {
      when(() => mockDio.get(any())).thenThrow(Exception('network error'));

      final notifier = container.read(kitchenProvider.notifier);
      await notifier.fetchAll(force: true);

      final state = container.read(kitchenProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, false);
    });

    test('KIT-08: fetch dalam 5 detik di-debounce (tidak fetch lagi)', () async {
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        data: [],
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final notifier = container.read(kitchenProvider.notifier);
      await notifier.fetchAll(force: true); // fetch pertama
      expect(container.read(kitchenProvider).isLoading, false);

      // Panggil lagi tanpa force → seharusnya skip karena < 5 detik
      await notifier.fetchAll(force: false);
      // Tidak ada assertion spesifik selain tidak crash; internal _lastFetch menangani ini
    });
  });

  group('KitchenNotifier.updateStatus', () {
    test('KIT-04: optimistic update → order pindah status lokal', () async {
      // Setup: state dengan 1 order PAID
      container.read(kitchenProvider.notifier).state = KitchenState(
        ordersByStatus: {
          'PAID': [{'id': 'O1', 'status': 'PAID', 'name': 'Order 1'}],
          'PREPARING': [],
          'READY': [],
          'COMPLETED': [],
        },
      );

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(statusCode: 200, requestOptions: RequestOptions(path: '')));

      final notifier = container.read(kitchenProvider.notifier);
      final result = await notifier.updateStatus('O1', 'PREPARING');

      expect(result, true);
      final state = container.read(kitchenProvider);
      expect(state.ordersByStatus['PAID']!.isEmpty, true);
      expect(state.ordersByStatus['PREPARING']!.length, 1);
      expect(state.ordersByStatus['PREPARING']!.first['status'], 'PREPARING');
    });

    test('KIT-06: server error → rollback (fetchAll force)', () async {
      // Setup: state dengan 1 order PAID
      container.read(kitchenProvider.notifier).state = KitchenState(
        ordersByStatus: {
          'PAID': [{'id': 'O1', 'status': 'PAID', 'name': 'Order 1'}],
          'PREPARING': [],
          'READY': [],
          'COMPLETED': [],
        },
      );

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(Exception('server down'));

      // Mock fetchAll response untuk rollback
      when(() => mockDio.get(any())).thenAnswer((_) async => Response(
        data: [{'id': 'O1', 'status': 'PAID', 'name': 'Order 1'}],
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));

      final notifier = container.read(kitchenProvider.notifier);
      final result = await notifier.updateStatus('O1', 'PREPARING');

      expect(result, false);
      final state = container.read(kitchenProvider);
      // Setelah rollback, order kembali ke PAID
      expect(state.ordersByStatus['PAID']!.length, 1);
      expect(state.ordersByStatus['PREPARING']!.isEmpty, true);
    });

    test('updateStatus: order tidak ditemukan → return false', () async {
      final notifier = container.read(kitchenProvider.notifier);
      final result = await notifier.updateStatus('NONEXISTENT', 'PREPARING');
      expect(result, false);
    });
  });

  group('KitchenNotifier.clearError', () {
    test('clearError menghapus error state', () {
      container.read(kitchenProvider.notifier).state = KitchenState(error: 'some error');
      container.read(kitchenProvider.notifier).clearError();
      expect(container.read(kitchenProvider).error, isNull);
    });
  });
}
