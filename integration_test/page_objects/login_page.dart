import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class LoginPage {
  final WidgetTester tester;
  LoginPage(this.tester);

  Future<void> enterCredentials(String employeeId, String pin) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), employeeId);
    await tester.enterText(fields.at(1), pin);
  }

  Future<void> tapLogin() async {
    await tester.tap(find.text('LOGIN TO POS'));
    await tester.pumpAndSettle();
  }

  Future<void> login(String employeeId, String pin) async {
    await enterCredentials(employeeId, pin);
    await tapLogin();
  }
}
