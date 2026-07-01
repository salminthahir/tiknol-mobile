// test/widget/auth/login_screen_test.dart
// Widget tests untuk LoginScreen (AUTH-01, AUTH-02)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:tiknol_reserve_mobile/screens/login_screen.dart';
import 'package:tiknol_reserve_mobile/providers/auth_provider.dart';
import 'package:tiknol_reserve_mobile/services/auth_service.dart';
import 'package:tiknol_reserve_mobile/core/api_client.dart';
import '../../helpers/mock_services.dart';
import '../../helpers/tablet_viewport.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = _MockAuthService();
    when(() => mockAuthService.hasSession()).thenAnswer((_) async => false);
    when(() => mockAuthService.getSavedSession()).thenAnswer((_) async => {});
  });

  Widget createLoginScreen() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/pos', builder: (context, state) => const Scaffold(body: Text('POS'))),
      ],
    );
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => mockAuthService),
        apiClientProvider.overrideWithValue(MockApiClient()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('AUTH-01: LoginScreen render & valid login', () {
    testWidgets('render form fields dan login button', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('EMPLOYEE ID'), findsOneWidget);
      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('LOGIN TO POS'), findsOneWidget);
    });

    testWidgets('tap login dengan valid credentials memanggil auth service', (tester) async {
      setTabletViewport(tester);

      when(() => mockAuthService.login(any(), any())).thenAnswer((_) async => {
        'userId': 'U1',
        'name': 'Budi',
        'role': 'STAFF',
        'branchId': 'B1',
        'branchName': 'HQ',
      });

      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'EMP001');
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.pump();

      // Tap login
      await tester.tap(find.text('LOGIN TO POS'));
      await tester.pump();
      await tester.pump();

      // Verify login was called
      verify(() => mockAuthService.login('EMP001', '1234')).called(1);
    });
  });

  group('AUTH-02: LoginScreen error states', () {
    testWidgets('empty fields show validation error', (tester) async {
      setTabletViewport(tester);
      await tester.pumpWidget(createLoginScreen());
      await tester.pumpAndSettle();

      // Tap login without entering anything
      await tester.tap(find.text('LOGIN TO POS'));
      await tester.pump();

      // Form validation should show errors
      expect(find.text('Masukkan Employee ID'), findsOneWidget);
    });
  });
}
