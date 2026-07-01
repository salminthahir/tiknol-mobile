// test/unit/payment/order_service_test.dart
// Unit tests untuk OrderService (PAY-03, PAY-05, PAY-11, PAY-12)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';
import 'package:tiknol_reserve_mobile/models/cart_item.dart';
import 'package:tiknol_reserve_mobile/models/product.dart';
import 'package:tiknol_reserve_mobile/models/payment_status.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:dio/dio.dart';
import '../../helpers/mock_services.dart';

void main() {
  late ProviderContainer container;
  late MockApiClient mockApiClient;
  late OrderService orderService;

  Product dummyProduct({String id = 'p1', String name = 'Americano', int price = 25000}) {
    return Product(id: id, name: name, price: price, category: 'COFFEE');
  }

  setUp(() {
    mockApiClient = MockApiClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );
    orderService = container.read(orderServiceProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('createCashOrder', () {
    test('PAY-01: payload lengkap dikirim ke /api/cash-order', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      final response = Response(
        data: {'orderId': 'ORD-123', 'status': 'PAID'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/cash-order'),
      );

      when(() => mockDio.post(
        '/api/cash-order',
        data: any(named: 'data'),
      )).thenAnswer((_) async => response);

      final result = await orderService.createCashOrder(
        customerName: 'Budi',
        orderType: 'DINE_IN',
        items: [
          CartItem(product: dummyProduct(id: 'p1', name: 'Americano'), qty: 2),
        ],
        totalAmount: 50000,
        subtotal: 50000,
        discountAmount: 0,
        voucherId: null,
      );

      expect(result['orderId'], 'ORD-123');

      // Verifikasi payload structure
      final captured = verify(() => mockDio.post(
        '/api/cash-order',
        data: captureAny(named: 'data'),
      )).captured.single as Map<String, dynamic>;

      expect(captured['customerName'], 'Budi');
      expect(captured['orderType'], 'DINE_IN');
      expect(captured['items'], isA<List>());
      expect(captured['items'].length, 1);
      expect(captured['items'][0]['id'], 'p1');
      expect(captured['items'][0]['qty'], 2);
      expect(captured['totalAmount'], 50000);
      expect(captured['discountAmount'], 0);
    });

    test('PAY-01: customerName kosong di-replace jadi "Customer POS"', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      final response = Response(
        data: {'orderId': 'ORD-123'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/cash-order'),
      );

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => response);

      await orderService.createCashOrder(
        customerName: '',
        orderType: 'TAKE_AWAY',
        items: [CartItem(product: dummyProduct(), qty: 1)],
        totalAmount: 25000,
        subtotal: 25000,
        discountAmount: 0,
      );

      final captured = verify(() => mockDio.post(
        any(),
        data: captureAny(named: 'data'),
      )).captured.single as Map<String, dynamic>;

      expect(captured['customerName'], 'Customer POS');
    });

    test('PAY-01: throw Exception jika statusCode != 200', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'error': 'Stok habis'},
                statusCode: 400,
                requestOptions: RequestOptions(path: '/api/cash-order'),
              ));

      expect(
        () => orderService.createCashOrder(
          customerName: 'Budi',
          orderType: 'DINE_IN',
          items: [CartItem(product: dummyProduct(), qty: 1)],
          totalAmount: 25000,
          subtotal: 25000,
          discountAmount: 0,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Stok habis'),
        )),
      );
    });
  });

  group('createOnlinePayment', () {
    test('PAY-03: tokenizer mengembalikan paymentUrl, orderId, qrString', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      final response = Response(
        data: {
          'orderId': 'ORD-456',
          'paymentUrl': 'https://sandbox.duitku.com/pay/ORD-456',
          'qrString': '0002010102...',
          'amount': 50000,
          'expiryPeriod': 10,
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/tokenizer'),
      );

      when(() => mockDio.post('/api/tokenizer', data: any(named: 'data')))
          .thenAnswer((_) async => response);

      final result = await orderService.createOnlinePayment(
        customerName: 'Budi',
        orderType: 'DINE_IN',
        items: [CartItem(product: dummyProduct(), qty: 2)],
        subtotal: 50000,
        discountAmount: 0,
        branchId: 'branch-1',
      );

      expect(result['orderId'], 'ORD-456');
      expect(result['paymentUrl'], 'https://sandbox.duitku.com/pay/ORD-456');
      expect(result['qrString'], '0002010102...');
      expect(result['amount'], '50000');
      expect(result['expiryPeriod'], '10');
    });

    test('PAY-03: throw jika response tanpa orderId', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'details': 'Branch tidak valid'},
                statusCode: 400,
                requestOptions: RequestOptions(path: '/api/tokenizer'),
              ));

      expect(
        () => orderService.createOnlinePayment(
          customerName: 'Budi',
          orderType: 'DINE_IN',
          items: [CartItem(product: dummyProduct(), qty: 1)],
          subtotal: 25000,
          discountAmount: 0,
          branchId: 'invalid-branch',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('checkPaymentStatus', () {
    test('PAY-05: status PAID dari server', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post('/api/payment/check-status', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'status': 'PAID'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/payment/check-status'),
              ));

      final status = await orderService.checkPaymentStatus('ORD-123');
      expect(status, PaymentStatus.paid);
    });

    test('PAY-05: status PENDING dari server', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'status': 'PENDING'},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      final status = await orderService.checkPaymentStatus('ORD-123');
      expect(status, PaymentStatus.pending);
    });

    test('PAY-12: status tidak dikenal → PaymentCheckException (fail-closed)', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'status': 'GARBLED_STATUS'},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      expect(
        () => orderService.checkPaymentStatus('ORD-123'),
        throwsA(isA<PaymentCheckException>()),
      );
    });

    test('PAY-11: DioException → PaymentCheckException (network error)', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ));

      expect(
        () => orderService.checkPaymentStatus('ORD-123'),
        throwsA(isA<PaymentCheckException>().having(
          (e) => e.message,
          'message',
          contains('jaringan'),
        )),
      );
    });

    test('PAY-11: orderId kosong → ArgumentError', () async {
      expect(
        () => orderService.checkPaymentStatus(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PAY-11: HTTP != 200 → PaymentCheckException', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {},
                statusCode: 500,
                requestOptions: RequestOptions(path: ''),
              ));

      expect(
        () => orderService.checkPaymentStatus('ORD-123'),
        throwsA(isA<PaymentCheckException>()),
      );
    });
  });

  group('cancelOrder', () {
    test('PAY-13: best-effort cancel, tidak throw meski error', () async {
      final mockDio = MockDio();
      when(() => mockApiClient.client).thenReturn(mockDio);

      when(() => mockDio.post('/api/payment/reset', data: any(named: 'data')))
          .thenThrow(Exception('network error'));

      // Tidak boleh throw — best effort
      await expectLater(
        orderService.cancelOrder('ORD-123'),
        completes,
      );
    });

    test('PAY-13: orderId kosong → no-op', () async {
      // Tidak ada network call yang terjadi
      await expectLater(
        orderService.cancelOrder(''),
        completes,
      );
    });
  });
}
