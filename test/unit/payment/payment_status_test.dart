// test/unit/payment/payment_status_test.dart
// Unit tests untuk PaymentStatus enum & paymentStatusFromString

import 'package:flutter_test/flutter_test.dart';
import 'package:tiknol_reserve_mobile/models/payment_status.dart';

void main() {
  group('paymentStatusFromString', () {
    test('PAID uppercase → PaymentStatus.paid', () {
      expect(paymentStatusFromString('PAID'), PaymentStatus.paid);
    });

    test('SUCCESS → PaymentStatus.paid', () {
      expect(paymentStatusFromString('SUCCESS'), PaymentStatus.paid);
    });

    test('FAILED uppercase → PaymentStatus.failed', () {
      expect(paymentStatusFromString('FAILED'), PaymentStatus.failed);
    });

    test('FAIL → PaymentStatus.failed', () {
      expect(paymentStatusFromString('FAIL'), PaymentStatus.failed);
    });

    test('CANCELLED (double L) → PaymentStatus.cancelled', () {
      expect(paymentStatusFromString('CANCELLED'), PaymentStatus.cancelled);
    });

    test('CANCELED (single L) → PaymentStatus.cancelled', () {
      expect(paymentStatusFromString('CANCELED'), PaymentStatus.cancelled);
    });

    test('EXPIRED → PaymentStatus.expired', () {
      expect(paymentStatusFromString('EXPIRED'), PaymentStatus.expired);
    });

    test('PENDING → PaymentStatus.pending', () {
      expect(paymentStatusFromString('PENDING'), PaymentStatus.pending);
    });

    test('PROCESS → PaymentStatus.pending', () {
      expect(paymentStatusFromString('PROCESS'), PaymentStatus.pending);
    });

    test('PROCESSING → PaymentStatus.pending', () {
      expect(paymentStatusFromString('PROCESSING'), PaymentStatus.pending);
    });

    test('null → PaymentStatus.unknown (fail-closed)', () {
      expect(paymentStatusFromString(null), PaymentStatus.unknown);
    });

    test('empty string → PaymentStatus.unknown', () {
      expect(paymentStatusFromString(''), PaymentStatus.unknown);
    });

    test('garbage string → PaymentStatus.unknown', () {
      expect(paymentStatusFromString('RANDOM_STATUS'), PaymentStatus.unknown);
    });

    test('lowercase "paid" → PaymentStatus.paid (case-insensitive)', () {
      expect(paymentStatusFromString('paid'), PaymentStatus.paid);
    });

    test('mixed case "PeNdInG" → PaymentStatus.pending', () {
      expect(paymentStatusFromString('PeNdInG'), PaymentStatus.pending);
    });

    test('whitespace "  PAID  " → trim + PaymentStatus.paid', () {
      expect(paymentStatusFromString('  PAID  '), PaymentStatus.paid);
    });
  });

  group('PaymentCheckException', () {
    test('toString mengandung message', () {
      final e = PaymentCheckException('network down');
      expect(e.toString(), contains('network down'));
      expect(e.toString(), startsWith('PaymentCheckException'));
    });
  });
}
