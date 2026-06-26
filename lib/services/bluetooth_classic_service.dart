import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothDeviceInfo {
  final String id;
  final String name;
  final String type; // 'classic' or 'ble'

  const BluetoothDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
  });
}

class BluetoothClassicService {
  static final BluetoothClassicService _instance = BluetoothClassicService._internal();
  factory BluetoothClassicService() => _instance;
  BluetoothClassicService._internal();

  classic.BluetoothConnection? _connection;
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;

  bool get isConnected => _connection != null && _connection!.isConnected;

  static const _prefsDeviceAddress = 'printer_classic_address';
  static const _prefsDeviceName = 'printer_classic_name';

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<bool> isEnabled() async {
    return await classic.FlutterBluetoothSerial.instance.isEnabled ?? false;
  }

  Future<void> enableBluetooth() async {
    await classic.FlutterBluetoothSerial.instance.requestEnable();
  }

  Future<List<BluetoothDeviceInfo>> getBondedDevices() async {
    try {
      final bonded = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      return bonded
          .where((d) => d.name != null && d.name!.isNotEmpty)
          .map((d) => BluetoothDeviceInfo(
                id: d.address,
                name: d.name!,
                type: 'classic',
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Discovery returns devices found during scan + bonded devices.
  Future<List<BluetoothDeviceInfo>> scanDevices({Duration timeout = const Duration(seconds: 10)}) async {
    final discovered = <String, BluetoothDeviceInfo>{};

    // 1. Always include bonded devices first
    final bonded = await getBondedDevices();
    for (final d in bonded) {
      discovered[d.id] = d;
    }

    // 2. Discovery scan (Android 12+ requires BLUETOOTH_SCAN permission)
    try {
      final completer = Completer<List<BluetoothDeviceInfo>>();
      final subscription = classic.FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) {
          if (result.device.name != null && result.device.name!.isNotEmpty) {
            final info = BluetoothDeviceInfo(
              id: result.device.address,
              name: result.device.name!,
              type: 'classic',
            );
            discovered[info.id] = info;
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(discovered.values.toList());
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.complete(discovered.values.toList());
          }
        },
      );

      // Timeout fallback
      Future.delayed(timeout, () async {
        await subscription.cancel();
        await classic.FlutterBluetoothSerial.instance.cancelDiscovery();
        if (!completer.isCompleted) {
          completer.complete(discovered.values.toList());
        }
      });

      return await completer.future;
    } catch (e) {
      // Discovery failed — return bonded devices at least
      return discovered.values.toList();
    }
  }

  Future<void> stopScan() async {
    try {
      await classic.FlutterBluetoothSerial.instance.cancelDiscovery();
    } catch (_) {}
  }

  Future<bool> connect(String address) async {
    try {
      await disconnect();
      final connection = await classic.BluetoothConnection.toAddress(address);
      if (connection.isConnected) {
        _connection = connection;
        _connectionStateController.add(true);
        await _saveDevice(address);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {}
    }
    _connection = null;
    _connectionStateController.add(false);
  }

  Future<void> sendBytes(List<int> bytes) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Printer tidak terhubung');
    }
    final data = Uint8List.fromList(bytes);
    _connection!.output.add(data);
    await _connection!.output.allSent;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _saveDevice(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsDeviceAddress, address);
  }

  Future<void> clearSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsDeviceAddress);
    await prefs.remove(_prefsDeviceName);
  }

  Future<Map<String, String?>> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'address': prefs.getString(_prefsDeviceAddress),
      'name': prefs.getString(_prefsDeviceName),
    };
  }

  Future<bool> reconnectToSaved() async {
    final saved = await getSavedDevice();
    final address = saved['address'];
    if (address == null) return false;
    return await connect(address);
  }

  void dispose() {
    _connectionStateController.close();
  }
}
