import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengatur orientasi layar ke landscape khusus untuk test.
Future<void> setTabletOrientation() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
