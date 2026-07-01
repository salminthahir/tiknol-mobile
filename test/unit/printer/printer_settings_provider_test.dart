// test/unit/printer/printer_settings_provider_test.dart
// Unit tests untuk PrinterDirtyNotifier & PrinterService utilities

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiknol_reserve_mobile/providers/printer_settings_provider.dart';
import 'package:tiknol_reserve_mobile/services/printer_service.dart';

void main() {
  group('PrinterDirtyNotifier', () {
    test('default state: false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(printerDirtyProvider);
      expect(state, false);
    });

    test('setValue(true) mengubah state ke true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerDirtyProvider.notifier);
      notifier.setValue(true);

      expect(container.read(printerDirtyProvider), true);
    });

    test('setValue(false) mengubah state ke false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerDirtyProvider.notifier);
      notifier.setValue(true);
      notifier.setValue(false);

      expect(container.read(printerDirtyProvider), false);
    });

    test('toggle dari true → false → true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(printerDirtyProvider.notifier);
      expect(container.read(printerDirtyProvider), false);

      notifier.setValue(true);
      expect(container.read(printerDirtyProvider), true);

      notifier.setValue(false);
      expect(container.read(printerDirtyProvider), false);
    });
  });

  group('PrinterService.isPrinterDevice', () {
    final service = PrinterService();

    test('PRNT-07: nama mengandung "printer" → true', () {
      expect(service.isPrinterDevice('Bluetooth Printer'), true);
      expect(service.isPrinterDevice('MY PRINTER'), true);
    });

    test('PRNT-07: nama mengandung "thermal" → true', () {
      expect(service.isPrinterDevice('Thermal Printer 58mm'), true);
    });

    test('PRNT-07: nama mengandung "POS" → true', () {
      expect(service.isPrinterDevice('POS-80'), true);
    });

    test('PRNT-07: nama mengandung "58mm" → true', () {
      expect(service.isPrinterDevice('Mini 58mm'), true);
    });

    test('PRNT-07: nama mengandung "ticket" → true', () {
      expect(service.isPrinterDevice('Ticket Printer'), true);
    });

    test('PRNT-07: nama tidak mengandung keyword → false', () {
      expect(service.isPrinterDevice('iPhone Budi'), false);
      expect(service.isPrinterDevice('Samsung Galaxy'), false);
      expect(service.isPrinterDevice('JBL Speaker'), false);
    });

    test('PRNT-07: case-insensitive', () {
      expect(service.isPrinterDevice('THERMAL PRINTER'), true);
      expect(service.isPrinterDevice('pos printer'), true);
      expect(service.isPrinterDevice('RpP02'), true); // contains 'rpp'
    });
  });

  group('PrinterService singleton', () {
    test('PrinterService() selalu return instance yang sama', () {
      final a = PrinterService();
      final b = PrinterService();
      expect(identical(a, b), true);
    });
  });
}
