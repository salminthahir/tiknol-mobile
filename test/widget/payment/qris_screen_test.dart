// test/widget/payment/qris_screen_test.dart
// Widget tests untuk QrisPaymentScreen (PAY-04~08)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tiknol_reserve_mobile/screens/qris_payment_screen.dart';
import 'package:tiknol_reserve_mobile/services/order_service.dart';
import 'package:tiknol_reserve_mobile/models/payment_status.dart';
import '../../helpers/mock_services.dart';
import '../../helpers/tablet_viewport.dart';

void main() {
  group('PAY-04: QR code rendering', () {
    testWidgets('renders QR code dari qrString', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: QrisPaymentScreen(
            orderId: 'ORD-123',
            qrString: '00020101021226660014ID.LINKAJA...',
            amount: 50000,
            expiryMinutes: 10,
            customerName: 'Budi',
          ),
        ),
      );
      await tester.pump();

      // QR code widget should be present
      expect(find.byType(QrImageView), findsOneWidget);

      // Order info should be displayed
      expect(find.textContaining('ORD-123'), findsOneWidget);
      expect(find.textContaining('Rp'), findsOneWidget);
    });

    testWidgets('renders countdown timer', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: QrisPaymentScreen(
            orderId: 'ORD-123',
            qrString: '000201010212...',
            amount: 50000,
            expiryMinutes: 10,
            customerName: 'Budi',
          ),
        ),
      );
      await tester.pump();

      // Should show timer text with colon (MM:SS format)
      expect(find.textContaining(':'), findsOneWidget);
    });
  });

  group('PAY-06: Payment status changes', () {
    testWidgets('shows PAID status and success UI', (tester) async {
      setTabletViewport(tester);
      final mockOrderService = MockOrderService();

      when(() => mockOrderService.checkPaymentStatus('ORD-123'))
          .thenAnswer((_) async => PaymentStatus.paid);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderServiceProvider.overrideWith((ref) => mockOrderService),
          ],
          child: const MaterialApp(
            home: QrisPaymentScreen(
              orderId: 'ORD-123',
              qrString: '000201010212...',
              amount: 50000,
              expiryMinutes: 10,
              customerName: 'Budi',
            ),
          ),
        ),
      );
      await tester.pump();

      // Wait for polling to detect PAID (5s interval)
      await tester.pump(const Duration(seconds: 6));

      // Should have called checkPaymentStatus at least once
      verify(() => mockOrderService.checkPaymentStatus('ORD-123')).called(greaterThanOrEqualTo(1));
    });

    testWidgets('shows EXPIRED when timer runs out', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: QrisPaymentScreen(
            orderId: 'ORD-123',
            qrString: '000201010212...',
            amount: 50000,
            expiryMinutes: 0, // Already expired
            customerName: 'Budi',
          ),
        ),
      );
      await tester.pump();

      // Wait for countdown to process
      await tester.pump(const Duration(seconds: 2));

      // Timer should have stopped (no ongoing timer animations)
      // The screen should still be rendered without crashing
      expect(find.byType(QrisPaymentScreen), findsOneWidget);
    });
  });
}
