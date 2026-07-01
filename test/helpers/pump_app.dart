// test/helpers/pump_app.dart
// Helper untuk pump MaterialApp dengan ProviderScope

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'test_provider.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    createTestScope(
      overrides: overrides,
      child: MaterialApp(
        home: widget,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
