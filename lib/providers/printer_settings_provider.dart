import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether printer settings have unsaved changes.
/// Used by ShellScreen to show confirmation dialog before navigating away.
final printerDirtyProvider = NotifierProvider<PrinterDirtyNotifier, bool>(PrinterDirtyNotifier.new);

class PrinterDirtyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}
