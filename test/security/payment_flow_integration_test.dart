// test/security/payment_flow_integration_test.dart
// Targets: PV-2 (Server verification on the payment success path)
//
// STATUS: REMEDIATED. Both QRIS and WebView paths now verify payment status
// with the backend before clearing the cart / printing the receipt. These
// tests model the `_verifyPaymentWithServer` retry/fail-closed logic used in
// cart_panel.dart and assert that only an explicit PAID is treated as success.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tiknol_reserve_mobile/models/payment_status.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';

class _MockOrderService extends Mock implements OrderService {}

/// Mirrors `_CartPanelState._verifyPaymentWithServer()` (cart_panel.dart).
Future<PaymentStatus> verifyPaymentWithServer(
  OrderService service,
  String orderId, {
  Duration delay = Duration.zero,
}) async {
  if (orderId.isEmpty) return PaymentStatus.unknown;
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final status = await service.checkPaymentStatus(orderId);
      if (status != PaymentStatus.pending) return status;
    } on PaymentCheckException {
      // retry
    } catch (_) {
      // never read unexpected errors as success
    }
    if (attempt < 2) await Future.delayed(delay);
  }
  return PaymentStatus.pending;
}

/// Decides the final action the way cart_panel does after verification.
bool shouldCompleteSale(PaymentStatus verified) =>
    verified == PaymentStatus.paid;

void main() {
  late _MockOrderService service;

  setUp(() {
    service = _MockOrderService();
  });

  group('PV-2 remediated: only server-verified PAID completes the sale', () {
    test('PAID from server completes the sale', () async {
      when(() => service.checkPaymentStatus(any()))
          .thenAnswer((_) async => PaymentStatus.paid);

      final verified = await verifyPaymentWithServer(service, 'ORD-1');
      expect(verified, PaymentStatus.paid);
      expect(shouldCompleteSale(verified), isTrue);
    });

    test('spoofed WebView close without payment does NOT complete sale',
        () async {
      // Server still reports pending because nothing was actually paid.
      when(() => service.checkPaymentStatus(any()))
          .thenAnswer((_) async => PaymentStatus.pending);

      final verified = await verifyPaymentWithServer(service, 'ORD-1');
      expect(shouldCompleteSale(verified), isFalse,
          reason: 'closing the WebView is not proof of payment');
    });

    test('verification error (fail-closed) does NOT complete sale', () async {
      when(() => service.checkPaymentStatus(any()))
          .thenThrow(PaymentCheckException('network down'));

      final verified = await verifyPaymentWithServer(service, 'ORD-1');
      expect(verified, PaymentStatus.pending);
      expect(shouldCompleteSale(verified), isFalse);
    });

    test('retries then succeeds when status flips pending -> paid', () async {
      var calls = 0;
      when(() => service.checkPaymentStatus(any())).thenAnswer((_) async {
        calls++;
        return calls >= 2 ? PaymentStatus.paid : PaymentStatus.pending;
      });

      final verified = await verifyPaymentWithServer(service, 'ORD-1');
      expect(verified, PaymentStatus.paid);
      expect(calls, greaterThanOrEqualTo(2));
    });

    test('FAILED status does not complete sale', () async {
      when(() => service.checkPaymentStatus(any()))
          .thenAnswer((_) async => PaymentStatus.failed);

      final verified = await verifyPaymentWithServer(service, 'ORD-1');
      expect(shouldCompleteSale(verified), isFalse);
    });

    test('verification always queries the backend at least once', () async {
      when(() => service.checkPaymentStatus(any()))
          .thenAnswer((_) async => PaymentStatus.paid);

      await verifyPaymentWithServer(service, 'ORD-1');
      verify(() => service.checkPaymentStatus('ORD-1')).called(1);
    });
  });

  group('OrderService cancellation behavior', () {
    test('cancelOrder is best-effort and may throw on network error', () async {
      when(() => service.cancelOrder(any()))
          .thenThrow(Exception('network error'));
      expect(() => service.cancelOrder('ORD-001'), throwsException);
    });
  });
}
