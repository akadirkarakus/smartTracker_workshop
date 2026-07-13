import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/exceptions/ble_adapter_exception.dart';
import '../../core/exceptions/ble_permission_exception.dart';
import '../../core/exceptions/ble_scan_exception.dart';
import '../models/ble_device_result.dart';
import '../repositories/ble_scanner_repository.dart';

class FlutterBluePlusScannerService implements BleScannerRepository {
  final _resultsController = StreamController<List<BleDeviceResult>>.broadcast();
  StreamSubscription? _scanSub;

  // Taranan cihazları ID'ye göre tutarız; aynı cihaz tekrar gelince RSSI güncellenir
  final Map<String, BleDeviceResult> _seen = {};

  @override
  Stream<List<BleDeviceResult>> get scanResults => _resultsController.stream;

  @override
  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 30)}) async {
    await _checkPermissions();
    await _checkAdapter();

    _seen.clear();

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      throw BleScanException(
        message: 'Failed to start scan.',
        cause: e,
      );
    }

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final r in results) {
          final device = _mapResult(r);
          _seen[device.deviceId] = device;
        }
        _resultsController.add(_seen.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi)));
      },
      onError: (Object e) {
        _resultsController.addError(
          BleScanException(message: 'Scan stream error.', cause: e),
        );
      },
    );
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _resultsController.close();
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────────

  Future<void> _checkPermissions() async {
    if (Platform.isIOS) return; // iOS izinleri Info.plist ile yönetilir

    // BLUETOOTH_SCAN neverForLocation ile tanımlandığından Android 12+'da
    // konum izni gerekmez.
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
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      throw BleAdapterException(
        message: 'Bluetooth adapter is off or unavailable (state: $state). '
            'Please turn on Bluetooth.',
      );
    }
  }

  BleDeviceResult _mapResult(ScanResult r) {
    final mfr = r.advertisementData.manufacturerData;
    String? mfrInfo;
    if (mfr.isNotEmpty) {
      final entry = mfr.entries.first;
      mfrInfo = 'ID:0x${entry.key.toRadixString(16).toUpperCase().padLeft(4, '0')} '
          '[${entry.value.length} bayt]';
    }

    return BleDeviceResult(
      deviceId: r.device.remoteId.str,
      name: r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : r.device.platformName,
      rssi: r.rssi,
      isConnectable: r.advertisementData.connectable,
      serviceUuids: r.advertisementData.serviceUuids
          .map((u) => u.str.toUpperCase())
          .toList(),
      manufacturerInfo: mfrInfo,
      lastSeen: DateTime.now(),
    );
  }
}
