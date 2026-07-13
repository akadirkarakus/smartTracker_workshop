import 'dart:async';
import 'dart:io';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ble_device_result.dart';
import '../repositories/ble_scanner_repository.dart';
import '../../core/exceptions/ble_adapter_exception.dart';
import '../../core/exceptions/ble_permission_exception.dart';
import '../../core/exceptions/ble_scan_exception.dart';

class ClassicBluetoothScannerService implements BleScannerRepository {
  final _bt = FlutterClassicBluetooth();
  final _seen = <String, BleDeviceResult>{};
  final _resultsController =
      StreamController<List<BleDeviceResult>>.broadcast();

  StreamSubscription<BtcDevice>? _discoverySub;

  @override
  Stream<List<BleDeviceResult>> get scanResults => _resultsController.stream;

  @override
  Future<bool> isBluetoothOn() => _bt.isEnabled();

  @override
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (Platform.isAndroid) await _checkPermissions();
    await _checkAdapter();

    _seen.clear();
    _discoverySub?.cancel();
    _discoverySub = _bt.discoveryResults.listen(
      (device) {
        final result = _mapDevice(device);
        _seen[result.deviceId] = result;
        _resultsController.add(
          List.unmodifiable(_seen.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi))),
        );
      },
      onError: (Object e) => _resultsController.addError(
        BleScanException(message: 'Scan error: $e', cause: e),
      ),
    );

    try {
      await _bt.startDiscovery();
    } catch (e) {
      throw BleScanException(message: 'Failed to start scan.', cause: e);
    }

    await Future.delayed(timeout);
    await stopScan();
  }

  @override
  Future<void> stopScan() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _bt.stopDiscovery();
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _resultsController.close();
  }

  Future<void> _checkPermissions() async {
    // Android ≤30: BLUETOOTH + BLUETOOTH_ADMIN manifest'te maxSdkVersion="30" ile
    // tanımlandığından install-time izindir; permission_handler "granted" döner.
    // Android 31+: BLUETOOTH_SCAN neverForLocation ile tanımlandığından
    // konum izni gerekmez; yalnızca BLUETOOTH_SCAN ve BLUETOOTH_CONNECT istenir.
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();

    if (scan.isPermanentlyDenied || connect.isPermanentlyDenied) {
      throw const BlePermissionException(
        message: 'Bluetooth permission permanently denied. '
            'Enable Bluetooth permission in Phone Settings > App Permissions.',
      );
    }
    if (!scan.isGranted || !connect.isGranted) {
      throw const BlePermissionException(
        message: 'Bluetooth permission denied. Please tap "Allow" in the permission dialog.',
      );
    }
  }

  Future<void> _checkAdapter() async {
    if (!await isBluetoothOn()) {
      throw const BleAdapterException(
          message: 'Bluetooth is off. Please turn it on.');
    }
  }

  BleDeviceResult _mapDevice(BtcDevice device) => BleDeviceResult(
        deviceId: device.address,
        name: device.name ?? '',
        rssi: device.rssi ?? -100,
        isConnectable: true,
        serviceUuids: device.uuids,
        manufacturerInfo: null,
        lastSeen: DateTime.now(),
      );
}
