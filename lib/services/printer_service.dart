import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_classic_service.dart';

/// Unified printer service supporting both BLE and Classic Bluetooth.
class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // BLE
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _bleCharacteristic;

  // Classic
  final _classicService = BluetoothClassicService();

  String? _currentType; // 'ble' or 'classic'

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;

  bool get isConnected {
    if (_currentType == 'ble') {
      return _bleDevice != null && _bleCharacteristic != null;
    }
    if (_currentType == 'classic') {
      return _classicService.isConnected;
    }
    return false;
  }

  BluetoothDevice? get connectedBleDevice => _bleDevice;
  String? get connectedDeviceName {
    if (_currentType == 'ble') {
      return _bleDevice?.platformName;
    }
    if (_currentType == 'classic') {
      return null;
    }
    return null;
  }

  static const _prefsDeviceType = 'printer_device_type';
  static const _prefsDeviceId = 'printer_device_id';
  static const _prefsDeviceName = 'printer_device_name';

  Future<bool> isBluetoothOn() async {
    if (Platform.isAndroid) {
      return await _classicService.isEnabled();
    }
    return true;
  }

  Future<void> enableBluetooth() async {
    if (Platform.isAndroid) {
      await _classicService.enableBluetooth();
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      return statuses.values.every((s) => s.isGranted);
    }
    return true;
  }

  // ── Printer filter ──

  static final _printerKeywords = [
    'printer', 'pos', 'thermal', 'receipt', 'rpp', 'esc', 'bluetooth printer',
    'ticket', 'mini printer', '58mm', '80mm', 'print',
  ];

  bool isPrinterDevice(String name) {
    final lower = name.toLowerCase();
    return _printerKeywords.any((k) => lower.contains(k));
  }

  // ── Scan (unified: BLE + Classic) ──

  /// Returns bonded/paired devices immediately, then optionally scans for more.
  Future<List<Map<String, dynamic>>> getBondedDevices({bool filterPrinter = true}) async {
    final devices = <String, Map<String, dynamic>>{};

    // Classic bonded (most reliable for thermal printers)
    try {
      final classicBonded = await _classicService.getBondedDevices();
      for (final d in classicBonded) {
        if (filterPrinter && !isPrinterDevice(d.name)) continue;
        devices[d.id] = {
          'id': d.id,
          'name': d.name,
          'type': 'classic',
        };
      }
    } catch (_) {}

    // BLE bonded
    try {
      final bleBonded = await FlutterBluePlus.bondedDevices;
      for (final d in bleBonded) {
        final name = d.platformName.isNotEmpty ? d.platformName : 'Unknown';
        if (filterPrinter && !isPrinterDevice(name)) continue;
        final id = d.remoteId.str;
        if (!devices.containsKey(id)) {
          devices[id] = {
            'id': id,
            'name': name,
            'type': 'ble',
            'device': d,
          };
        }
      }
    } catch (_) {}

    return devices.values.toList();
  }

  /// Full scan: bonded + discovery (BLE + Classic).
  Future<List<Map<String, dynamic>>> scanAllDevices({Duration timeout = const Duration(seconds: 8), bool filterPrinter = true}) async {
    final devices = <String, Map<String, dynamic>>{};

    // 1. Start with bonded devices (always available)
    final bonded = await getBondedDevices(filterPrinter: filterPrinter);
    for (final d in bonded) {
      devices[d['id'] as String] = d;
    }

    // 2. BLE discovery (parallel)
    final bleFuture = _scanBle(timeout: timeout, filterPrinter: filterPrinter);

    // 3. Classic discovery (parallel)
    final classicFuture = _scanClassic(timeout: timeout, filterPrinter: filterPrinter);

    // Wait for both with timeout
    final results = await Future.wait([
      bleFuture.catchError((_) => <Map<String, dynamic>>[]),
      classicFuture.catchError((_) => <Map<String, dynamic>>[]),
    ]);

    for (final list in results) {
      for (final d in list) {
        final id = d['id'] as String;
        if (!devices.containsKey(id)) {
          devices[id] = d;
        }
      }
    }

    return devices.values.toList();
  }

  Future<List<Map<String, dynamic>>> _scanBle({required Duration timeout, bool filterPrinter = true}) async {
    final found = <Map<String, dynamic>>[];
    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: timeout);

      // Collect results until timeout
      await Future.delayed(timeout);
      final results = await FlutterBluePlus.scanResults.first;
      await FlutterBluePlus.stopScan();

      for (final r in results) {
        final name = r.device.platformName;
        if (name.isNotEmpty) {
          if (filterPrinter && !isPrinterDevice(name)) continue;
          found.add({
            'id': r.device.remoteId.str,
            'name': name,
            'type': 'ble',
            'device': r.device,
          });
        }
      }
    } catch (_) {}
    return found;
  }

  Future<List<Map<String, dynamic>>> _scanClassic({required Duration timeout, bool filterPrinter = true}) async {
    final found = <Map<String, dynamic>>[];
    try {
      final results = await _classicService.scanDevices(timeout: timeout);
      for (final d in results) {
        if (filterPrinter && !isPrinterDevice(d.name)) continue;
        found.add({
          'id': d.id,
          'name': d.name,
          'type': 'classic',
        });
      }
    } catch (_) {}
    return found;
  }

  Future<void> stopScan() async {
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    try { await _classicService.stopScan(); } catch (_) {}
  }

  // ── Connect ──

  Future<bool> connectBle(BluetoothDevice device) async {
    await disconnect();
    try {
      await device.connect(autoConnect: false, mtu: null);
      final services = await device.discoverServices();
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _bleCharacteristic = characteristic;
            break;
          }
        }
        if (_bleCharacteristic != null) break;
      }
      if (_bleCharacteristic != null) {
        _bleDevice = device;
        _currentType = 'ble';
        _connectionStateController.add(true);
        await _saveDevice('ble', device.remoteId.str, device.platformName);
        return true;
      } else {
        await device.disconnect();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectClassic(String address, String name) async {
    await disconnect();
    final ok = await _classicService.connect(address);
    if (ok) {
      _currentType = 'classic';
      _connectionStateController.add(true);
      await _saveDevice('classic', address, name);
      return true;
    }
    return false;
  }

  Future<void> disconnect() async {
    if (_bleDevice != null) {
      try { await _bleDevice!.disconnect(); } catch (_) {}
      _bleDevice = null;
      _bleCharacteristic = null;
    }
    await _classicService.disconnect();
    _currentType = null;
    _connectionStateController.add(false);
  }

  // ── Send ──

  Future<void> sendBytes(List<int> bytes) async {
    if (_currentType == 'ble' && _bleCharacteristic != null) {
      final chunkSize = 512;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = Uint8List.fromList(bytes.sublist(i, end));
        if (_bleCharacteristic!.properties.writeWithoutResponse) {
          await _bleCharacteristic!.write(chunk, withoutResponse: true);
        } else {
          await _bleCharacteristic!.write(chunk);
        }
        await Future.delayed(const Duration(milliseconds: 20));
      }
    } else if (_currentType == 'classic') {
      await _classicService.sendBytes(bytes);
    } else {
      throw Exception('Printer tidak terhubung');
    }
  }

  // ── Saved device ──

  Future<void> _saveDevice(String type, String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDeviceType, type);
    await prefs.setString(_prefsDeviceId, id);
    await prefs.setString(_prefsDeviceName, name);
  }

  Future<void> clearSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDeviceType);
    await prefs.remove(_prefsDeviceId);
    await prefs.remove(_prefsDeviceName);
    await _classicService.clearSavedDevice();
  }

  Future<Map<String, String?>> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'type': prefs.getString(_prefsDeviceType),
      'id': prefs.getString(_prefsDeviceId),
      'name': prefs.getString(_prefsDeviceName),
    };
  }

  Future<bool> reconnectToSaved() async {
    final saved = await getSavedDevice();
    final type = saved['type'];
    final id = saved['id'];
    if (id == null || type == null) return false;

    if (type == 'classic') {
      return await connectClassic(id, saved['name'] ?? 'Unknown');
    }

    // BLE: try bonded then scan
    final bonded = await FlutterBluePlus.bondedDevices;
    for (final d in bonded) {
      if (d.remoteId.str == id) {
        return await connectBle(d);
      }
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    await Future.delayed(const Duration(seconds: 3));
    final results = await FlutterBluePlus.scanResults.first;
    await FlutterBluePlus.stopScan();

    for (final r in results) {
      if (r.device.remoteId.str == id) {
        return await connectBle(r.device);
      }
    }
    return false;
  }

  void dispose() {
    _connectionStateController.close();
    _classicService.dispose();
  }
}
