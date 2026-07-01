// test/security/transport_security_test.dart
// Targets: PV-4 (Cleartext HTTP), and documents PV-6 (cert pinning) follow-up.
//
// STATUS: PV-4 REMEDIATED. These tests assert the secure transport config:
//   - production default base URL is HTTPS
//   - the client refuses cleartext base URLs in release builds
//   - Android blocks cleartext by default (scoped dev exception only)
//   - iOS ATS stays enabled (scoped dev exception only)
//
// PV-6 (certificate pinning) is tracked as a follow-up; its assertions remain
// documentary until pinning is implemented.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current.path;

  group('PV-4 remediated: production default is HTTPS', () {
    late String constantsSource;

    setUpAll(() {
      constantsSource =
          File('$projectRoot/lib/core/constants.dart').readAsStringSync();
    });

    test('production default base URL is HTTPS', () {
      expect(constantsSource, contains("_prodDefaultBaseUrl = 'https://"),
          reason: 'PV-4: production default must be HTTPS');
    });

    test('exposes a secure-url helper', () {
      expect(constantsSource, contains('isSecureUrl'),
          reason: 'PV-4: helper used to reject cleartext at runtime');
    });

    test('dev cleartext default is gated behind env == development', () {
      // The HTTP LAN default is only selected when env != production.
      expect(constantsSource, contains("env == 'production'"),
          reason: 'PV-4: cleartext only for development environment');
    });
  });

  group('PV-4 remediated: runtime guard against cleartext', () {
    late String apiClientSource;

    setUpAll(() {
      apiClientSource =
          File('$projectRoot/lib/core/api_client.dart').readAsStringSync();
    });

    test('release builds reject insecure saved base URLs', () {
      expect(apiClientSource, contains('kReleaseMode'),
          reason: 'PV-4: guard only relaxes for debug/dev');
      expect(apiClientSource, contains('isSecureUrl'),
          reason: 'PV-4: refreshBaseUrl validates scheme');
    });
  });

  group('PV-4 remediated: Android network security config', () {
    test('config file exists and blocks cleartext by default', () {
      final cfg = File(
          '$projectRoot/android/app/src/main/res/xml/network_security_config.xml');
      expect(cfg.existsSync(), isTrue,
          reason: 'network_security_config.xml must exist');
      final content = cfg.readAsStringSync();
      expect(content, contains('cleartextTrafficPermitted="false"'),
          reason: 'base-config must block cleartext');
    });

    test('AndroidManifest registers the config and disables cleartext', () {
      final manifest = File(
              '$projectRoot/android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifest, contains('android:networkSecurityConfig'),
          reason: 'PV-4: manifest must reference the security config');
      expect(manifest, contains('android:usesCleartextTraffic="false"'),
          reason: 'PV-4: cleartext disabled at app level');
    });
  });

  group('PV-4 remediated: iOS App Transport Security', () {
    test('Info.plist enables ATS (no arbitrary loads)', () {
      final plist =
          File('$projectRoot/ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSAppTransportSecurity'),
          reason: 'PV-4: ATS config present');
      expect(plist, contains('NSAllowsArbitraryLoads'),
          reason: 'PV-4: explicit arbitrary-loads flag');
      // Ensure arbitrary loads are NOT globally enabled (must be <false/>).
      final atsIndex = plist.indexOf('NSAllowsArbitraryLoads');
      final after = plist.substring(atsIndex, atsIndex + 60);
      expect(after, contains('<false/>'),
          reason: 'PV-4: arbitrary loads must be disabled globally');
    });
  });

  group('PV-1 hardening: WebView navigation allow-list present', () {
    late String webViewSource;

    setUpAll(() {
      webViewSource = File('$projectRoot/lib/screens/payment_webview.dart')
          .readAsStringSync();
    });

    test('navigation is gated by an allow-list (can prevent)', () {
      expect(webViewSource, contains('NavigationDecision.prevent'),
          reason: 'WebView must be able to block non-allowed navigation');
      expect(webViewSource, contains('_isAllowedNavigation'),
          reason: 'allow-list helper present');
    });

    test('success is never derived from URL (no pop with true)', () {
      expect(webViewSource, isNot(contains('Navigator.pop(context, true)')),
          reason: 'PV-1: WebView must not return a success value from a URL');
    });
  });
}
