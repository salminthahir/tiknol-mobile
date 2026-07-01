// test/helpers/tablet_viewport.dart
// Helper to simulate 10" Android tablet landscape for all widget tests

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

/// Sets the tester viewport to a 10" tablet landscape (2400x1600 @ 2x DPI).
/// Call this before pumpWidget in every tablet-targeted widget test.
void setTabletViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
