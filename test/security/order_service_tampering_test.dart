// test/security/order_service_tampering_test.dart
// Targets: PV-3 (Price / Discount Tampering via Client-Side Payload)
//          PV-5 (Silent Failure in Payment Status Check)
//
// NOTE: These tests prove the tampering surface and fail-closed behavior.
// After remediation (server-side recalculation, strict error handling),
// assertions must be updated to enforce the secure behavior.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import 'package:tiknol_reserve_mobile/models/cart_item.dart';
import 'package:tiknol_reserve_mobile/models/payment_status.dart';
import 'package:tiknol_reserve_mobile/models/product.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';

class _MockDio extends Mock implements Dio {}

class _FakeApiClient extends ApiClient {
  final Dio _mockDio;
  _FakeApiClient(this._mockDio) : super(onUnauthorized: null);

  @override
  Dio get client => _mockDio;
}

void _setupTokenizerSuccess(_MockDio dio, Map<String, dynamic> data) {
  when(() => dio.post(
    '/api/tokenizer',
    data: any(named: 'data'),
  )).thenAnswer((_) async => Response(
    data: data,
    statusCode: 200,
    requestOptions: RequestOptions(path: '/api/tokenizer'),
  ));
}

void _setupCashOrderSuccess(_MockDio dio) {
  when(() => dio.post(
    '/api/cash-order',
    data: any(named: 'data'),
  )).thenAnswer((_) async => Response(
    data: {'id': 'ORD-CASH-001'},
    statusCode: 200,
    requestOptions: RequestOptions(path: '/api/cash-order'),
  ));
}

void _setupCheckStatus(_MockDio dio, String status) {
  when(() => dio.post(
    '/api/payment/check-status',
    data: any(named: 'data'),
  )).thenAnswer((_) async => Response(
    data: {'status': status},
    statusCode: 200,
    requestOptions: RequestOptions(path: '/api/payment/check-status'),
  ));
}

void _setupNetworkFailure(_MockDio dio, String path) {
  when(() => dio.post(
    path,
    data: any(named: 'data'),
  )).thenThrow(DioException(
    requestOptions: RequestOptions(path: path),
    type: DioExceptionType.connectionTimeout,
  ));
}

List<CartItem> _buildCart() {
  final product = Product(
    id: 'P1',
    name: 'Espresso',
    price: 25000,
    category: 'Beverage',
    isAvailable: true,
  );
  return [CartItem(product: product, qty: 2)]; // 50.000
}

void main() {
  late _MockDio mockDio;
  late ProviderContainer container;

  setUp(() {
    mockDio = _MockDio();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient(mockDio)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('PV-3: Client-side price/discount tampering surface', () {
    test('createCashOrder sends prices computed on client', () async {
      _setupCashOrderSuccess(mockDio);
      final orderService = container.read(orderServiceProvider);

      await orderService.createCashOrder(
        customerName: 'Test',
        orderType: 'Dine In',
        items: _buildCart(),
        totalAmount: 50000,
        subtotal: 50000,
        discountAmount: 0,
      );

      final captured = verify(() => mockDio.post(
        '/api/cash-order',
        data: captureAny(named: 'data'),
      )).captured.single as Map<String, dynamic>;

      // The payload contains client-computed totals
      expect(captured['totalAmount'], 50000);
      expect(captured['subtotal'], 50000);
      expect(captured['discountAmount'], 0);
      expect((captured['items'] as List).first['price'], 25000);
    });

    test('createOnlinePayment sends client-controlled subtotal/discount', () async {
      _setupTokenizerSuccess(mockDio, {
        'orderId': 'ORD-001',
        'paymentUrl': 'https://sandbox.duitku.com/topup/...',
        'qrString': '',
        'amount': 50000,
        'expiryPeriod': 10,
      });
      final orderService = container.read(orderServiceProvider);

      await orderService.createOnlinePayment(
        customerName: 'Test',
        orderType: 'Takeaway',
        items: _buildCart(),
        subtotal: 50000,
        discountAmount: 0,
        branchId: 'B1',
      );

      final captured = verify(() => mockDio.post(
        '/api/tokenizer',
        data: captureAny(named: 'data'),
      )).captured.single as Map<String, dynamic>;

      // These values originate from client-side state
      expect(captured['subtotal'], 50000);
      expect(captured['discountAmount'], 0);
      expect((captured['items'] as List).first['price'], 25000);

      // PV-3: If backend blindly trusts these values for Duitku paymentAmount,
      // an attacker could set subtotal=1 and pay Rp 1 for a Rp 50.000 order.
    });

    test('malicious discount could be injected via client payload', () async {
      _setupTokenizerSuccess(mockDio, {
        'orderId': 'ORD-002',
        'paymentUrl': 'https://...',
        'qrString': '',
        'amount': 50000,
        'expiryPeriod': 10,
      });
      final orderService = container.read(orderServiceProvider);

      await orderService.createOnlinePayment(
        customerName: 'Test',
        orderType: 'Dine In',
        items: _buildCart(),
        subtotal: 50000,
        // Attacker injects a fake discount larger than the order
        discountAmount: 100000,
        branchId: 'B1',
      );

      final captured = verify(() => mockDio.post(
        '/api/tokenizer',
        data: captureAny(named: 'data'),
      )).captured.single as Map<String, dynamic>;

      // The negative/discount value is transmitted without client-side validation
      expect(captured['discountAmount'], 100000);
      // Secure backend must recalculate and reject this.
    });
  });

  group('PV-5 remediated: checkPaymentStatus fails closed', () {
    test('network timeout throws PaymentCheckException (not PENDING)', () async {
      _setupNetworkFailure(mockDio, '/api/payment/check-status');
      final orderService = container.read(orderServiceProvider);

      await expectLater(
        orderService.checkPaymentStatus('ORD-001'),
        throwsA(isA<PaymentCheckException>()),
      );
      // Errors are no longer silently mapped to PENDING; the caller can
      // distinguish "could not verify" from "not yet paid".
    });

    test('malformed/non-map response throws PaymentCheckException', () async {
      when(() => mockDio.post(
        '/api/payment/check-status',
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        data: 'not-json',
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/payment/check-status'),
      ));
      final orderService = container.read(orderServiceProvider);

      await expectLater(
        orderService.checkPaymentStatus('ORD-001'),
        throwsA(isA<PaymentCheckException>()),
      );
    });

    test('unrecognized status string throws (fail-closed)', () async {
      _setupCheckStatus(mockDio, 'WEIRD_STATUS');
      final orderService = container.read(orderServiceProvider);

      await expectLater(
        orderService.checkPaymentStatus('ORD-001'),
        throwsA(isA<PaymentCheckException>()),
      );
    });

    test('explicit PAID maps to PaymentStatus.paid', () async {
      _setupCheckStatus(mockDio, 'PAID');
      final orderService = container.read(orderServiceProvider);

      final status = await orderService.checkPaymentStatus('ORD-001');
      expect(status, PaymentStatus.paid);
    });

    test('explicit PENDING maps to PaymentStatus.pending', () async {
      _setupCheckStatus(mockDio, 'PENDING');
      final orderService = container.read(orderServiceProvider);

      final status = await orderService.checkPaymentStatus('ORD-001');
      expect(status, PaymentStatus.pending);
    });

    test('empty orderId is rejected with ArgumentError', () async {
      final orderService = container.read(orderServiceProvider);
      await expectLater(
        orderService.checkPaymentStatus(''),
        throwsArgumentError,
      );
    });
  });
}
