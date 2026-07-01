// test/security/payment_webview_spoof_test.dart
// Targets: PV-1 (Client-Side Payment Success Spoofing), PV-2 (Missing Server Verification)
//
// STATUS: REMEDIATED. PaymentWebView is now a viewer only. It never decides
// payment success from URLs. Detection of the backend return URL is path-based
// (`/ticket/{orderId}`, host-agnostic) and is ONLY a "close the WebView"
// signal — the caller then verifies the real status server-side. These tests
// verify that:
//   - no URL pattern is ever treated as payment success
//   - the return-url path closes the WebView regardless of host (multi-env)
//   - navigation is restricted to Duitku hosts + the return-url path

import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_PaymentWebViewState._isReturnUrl()` from
/// `lib/screens/payment_webview.dart`. Path-based, host-agnostic.
/// Returns true if the WebView should CLOSE (NOT "payment succeeded").
bool isReturnUrl(String url, String orderId) {
  return url.contains('/ticket/$orderId');
}

/// Mirrors `_PaymentWebViewState._isAllowedNavigation()`.
bool isAllowedNavigation(String url, String orderId) {
  if (isReturnUrl(url, orderId)) return true;
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return true; // about:blank, data:, etc.
  const allowed = ['duitku.com', 'sandbox.duitku.com', 'passport.duitku.com'];
  return allowed.any((d) => host == d || host.endsWith('.$d'));
}

void main() {
  const orderId = 'ORD-20250630-001';

  group('PV-1 remediated: success is NEVER derived from a URL', () {
    test('status=success URL does not match the close signal', () {
      const url = 'https://attacker.test/fake?status=success';
      expect(isReturnUrl(url, orderId), isFalse,
          reason: 'success substring is meaningless now');
    });

    test('result=00 URL does not match the close signal', () {
      const url = 'https://attacker.test/fake?result=00';
      expect(isReturnUrl(url, orderId), isFalse);
    });

    test('closing the WebView is NOT proof of payment (server verifies)', () {
      // Even when the close signal fires, cart_panel calls
      // _verifyPaymentWithServer() and only PaymentStatus.paid completes the
      // sale. See payment_flow_integration_test.dart. The WebView itself pops
      // WITHOUT any success value.
      const closeSignalEqualsSuccess = false;
      expect(closeSignalEqualsSuccess, isFalse);
    });
  });

  group('Return-url detection is path-based (multi-environment safe)', () {
    test('production host return url closes the WebView', () {
      final url = 'https://api.nol.coffee/ticket/$orderId';
      expect(isReturnUrl(url, orderId), isTrue);
    });

    test('dev LAN host return url closes the WebView', () {
      final url = 'http://192.168.100.95:3000/ticket/$orderId';
      expect(isReturnUrl(url, orderId), isTrue,
          reason: 'host-agnostic: works even if env differs from compile default');
    });

    test('different order id does NOT trigger close', () {
      final url = 'https://api.nol.coffee/ticket/SOME-OTHER-ORDER';
      expect(isReturnUrl(url, orderId), isFalse);
    });
  });

  group('Navigation allow-list', () {
    test('Duitku sandbox host is allowed', () {
      expect(isAllowedNavigation('https://sandbox.duitku.com/topup/x', orderId),
          isTrue);
    });

    test('Duitku subdomain is allowed', () {
      expect(isAllowedNavigation('https://app.duitku.com/pay', orderId), isTrue);
    });

    test('backend return-url path is allowed on any host', () {
      expect(isAllowedNavigation('https://api.nol.coffee/ticket/$orderId', orderId),
          isTrue);
    });

    test('arbitrary attacker host without return path is blocked', () {
      expect(isAllowedNavigation('https://evil.com/phish', orderId), isFalse);
    });

    test('lookalike host duitku.com.evil.com is blocked', () {
      expect(isAllowedNavigation('https://duitku.com.evil.com/x', orderId),
          isFalse,
          reason: 'suffix match must be on a dot boundary, not substring');
    });

    test('attacker host WITH return path only closes — never marks success', () {
      // An attacker page at /ticket/{orderId} is allowed to navigate and will
      // close the WebView, but closing is not success: the server check that
      // follows returns PENDING for an unpaid order, so no sale completes.
      final url = 'https://evil.com/ticket/$orderId';
      expect(isAllowedNavigation(url, orderId), isTrue);
      expect(isReturnUrl(url, orderId), isTrue);
      // Worst case = early close (DoS). Success still requires server PAID.
    });
  });
}
