/// Centralized payment status type used across the payment flow.
///
/// Security note (PV-1/PV-2/PV-5): payment success must only ever be derived
/// from a server-verified status, never from client-side signals such as
/// WebView URLs or Duitku `resultCode`. The [PaymentStatus.unknown] value is
/// intentional so that unrecognized/garbled responses are treated as
/// non-authoritative (fail-closed) instead of silently mapped to pending.
enum PaymentStatus { pending, paid, failed, cancelled, expired, unknown }

/// Maps a raw status string (from the backend) to a [PaymentStatus].
///
/// Anything not explicitly recognized maps to [PaymentStatus.unknown] so the
/// caller can decide to fail closed rather than assume a benign state.
PaymentStatus paymentStatusFromString(String? raw) {
  switch (raw?.toUpperCase().trim()) {
    case 'PAID':
    case 'SUCCESS':
      return PaymentStatus.paid;
    case 'FAILED':
    case 'FAIL':
      return PaymentStatus.failed;
    case 'CANCELLED':
    case 'CANCELED':
      return PaymentStatus.cancelled;
    case 'EXPIRED':
      return PaymentStatus.expired;
    case 'PENDING':
    case 'PROCESS':
    case 'PROCESSING':
      return PaymentStatus.pending;
    default:
      return PaymentStatus.unknown;
  }
}

/// Thrown when a payment status check cannot be completed or returns a
/// non-authoritative result. Callers must NOT treat this as a paid/pending
/// outcome; it signals "unknown — retry or verify manually".
class PaymentCheckException implements Exception {
  final String message;
  PaymentCheckException(this.message);

  @override
  String toString() => 'PaymentCheckException: $message';
}
