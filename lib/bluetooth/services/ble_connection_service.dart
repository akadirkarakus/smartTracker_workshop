import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;

import '../../core/bt_utils.dart';
import '../../core/exceptions/ble_characteristic_exception.dart';
import '../../core/exceptions/ble_connection_exception.dart';
import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart'
    hide BleConnectionState;
import '../repositories/ble_connection_repository.dart' as repo;

class FlutterBluePlusConnectionService implements BleConnectionRepository {
  BluetoothDevice? _device;

  // Keşfedilen karakteristikler UUID → nesne
  final Map<String, BluetoothCharacteristic> _characteristics = {};

  // Notify stream'leri UUID → controller
  final Map<String, StreamController<List<int>>> _notifyControllers = {};
  final Map<String, StreamSubscription> _notifySubs = {};

  final _stateController =
      StreamController<repo.BleConnectionState>.broadcast();
  final _logController = StreamController<LogEntry>.broadcast();

  StreamSubscription? _connStateSub;

  @override
  Stream<repo.BleConnectionState> get connectionState =>
      _stateController.stream;

  @override
  Stream<LogEntry> get logs => _logController.stream;

  // ─── Bağlantı ─────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String deviceId) async {
    _log('${_deviceLabel(deviceId)} cihazına bağlanılıyor...', LogLevel.info);
    _stateController.add(repo.BleConnectionState.connecting);

    _device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));

    _connStateSub?.cancel();
    _connStateSub = _device!.connectionState.listen((state) {
      final mapped = _mapState(state);
      _stateController.add(mapped);
    });

    try {
      await _device!.connect(timeout: const Duration(seconds: 10));
      _log('GATT bağlantısı kuruldu.', LogLevel.success);
    } on FlutterBluePlusException catch (e) {
      _log('Connection failed: ${e.description}', LogLevel.error);
      throw BleConnectionException(
        message: 'Could not connect to device: ${e.description}',
        cause: e,
      );
    } catch (e) {
      _log('Connection failed: $e', LogLevel.error);
      throw BleConnectionException(
        message: 'Unexpected connection error.',
        cause: e,
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _log('Disconnecting...', LogLevel.info);
    _stateController.add(repo.BleConnectionState.disconnecting);

    for (final sub in _notifySubs.values) {
      await sub.cancel();
    }
    for (final ctrl in _notifyControllers.values) {
      await ctrl.close();
    }
    _notifySubs.clear();
    _notifyControllers.clear();
    _characteristics.clear();

    await _device?.disconnect();
    _log('Disconnected.', LogLevel.info);
  }

  // ─── Servis Keşfi ─────────────────────────────────────────────────────────

  @override
  Future<List<BleGattService>> discoverServices() async {
    _log('Discovering services...', LogLevel.info);

    if (_device == null) {
      throw const BleConnectionException(
          message: 'Connect first before discovering services.');
    }

    late List<BluetoothService> rawServices;
    try {
      rawServices = await _device!.discoverServices();
    } catch (e) {
      _log('Service discovery failed: $e', LogLevel.error);
      throw BleConnectionException(
          message: 'Could not discover services.', cause: e);
    }

    final services = <BleGattService>[];
    int totalChars = 0;

    for (final s in rawServices) {
      final chars = <BleGattCharacteristic>[];
      for (final c in s.characteristics) {
        final uuid = c.characteristicUuid.str.toUpperCase();
        _characteristics[uuid] = c;
        chars.add(BleGattCharacteristic(
          uuid: uuid,
          canRead: c.properties.read,
          canWrite: c.properties.write || c.properties.writeWithoutResponse,
          canNotify: c.properties.notify || c.properties.indicate,
        ));
        totalChars++;
      }
      services.add(BleGattService(
        uuid: s.serviceUuid.str.toUpperCase(),
        characteristics: chars,
      ));
    }

    _log(
      '${services.length} services, $totalChars characteristics found.',
      LogLevel.success,
    );

    for (final svc in services) {
      _log('Service: ${svc.uuid}', LogLevel.info);
      for (int i = 0; i < svc.characteristics.length; i++) {
        final c = svc.characteristics[i];
        final prefix = i == svc.characteristics.length - 1 ? '└─' : '├─';
        _log('  $prefix ${_shortUuid(c.uuid)} [${c.propertiesLabel}]',
            LogLevel.info);
      }
    }

    return services;
  }

  // ─── Okuma / Yazma / Notify ───────────────────────────────────────────────

  @override
  Future<List<int>> readCharacteristic(String charUuid) async {
    final c = _findChar(charUuid);
    try {
      final value = await c.read();
      _log(
        '← Read [${_shortUuid(charUuid)}]: ${bytesToHex(value)}',
        LogLevel.incoming,
      );
      return value;
    } catch (e) {
      throw BleCharacteristicException(
          message: 'Read failed: $charUuid', cause: e);
    }
  }

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    final c = _findChar(charUuid);
    try {
      if (c.properties.writeWithoutResponse) {
        await c.write(data, withoutResponse: true);
      } else {
        await c.write(data);
      }
      _log(
        '→ Sent [${_shortUuid(charUuid)}]: ${bytesToHex(data)}',
        LogLevel.outgoing,
      );
    } catch (e) {
      throw BleCharacteristicException(
          message: 'Write failed: $charUuid', cause: e);
    }
  }

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {
    final c = _findChar(charUuid);
    try {
      await c.setNotifyValue(enable);
      _log(
        'Notify ${enable ? "enabled" : "disabled"}: ${_shortUuid(charUuid)}',
        LogLevel.info,
      );

      if (enable) {
        final ctrl = StreamController<List<int>>.broadcast();
        _notifyControllers[charUuid] = ctrl;
        _notifySubs[charUuid] = c.lastValueStream.listen((bytes) {
          if (bytes.isNotEmpty) {
            _log(
              '← Notify [${_shortUuid(charUuid)}]: ${bytesToHex(bytes)}',
              LogLevel.incoming,
            );
            ctrl.add(bytes);
          }
        });
      } else {
        await _notifySubs[charUuid]?.cancel();
        await _notifyControllers[charUuid]?.close();
        _notifySubs.remove(charUuid);
        _notifyControllers.remove(charUuid);
      }
    } catch (e) {
      throw BleCharacteristicException(
          message: 'Failed to set notify: $charUuid', cause: e);
    }
  }

  @override
  Stream<List<int>> notifyStream(String charUuid) {
    final ctrl = _notifyControllers[charUuid];
    if (ctrl == null) {
      throw BleCharacteristicException(
          message: 'Notify not active: $charUuid');
    }
    return ctrl.stream;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connStateSub?.cancel();
    for (final sub in _notifySubs.values) {
      await sub.cancel();
    }
    for (final ctrl in _notifyControllers.values) {
      await ctrl.close();
    }
    await _stateController.close();
    await _logController.close();
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────────

  BluetoothCharacteristic _findChar(String charUuid) {
    final key = charUuid.toUpperCase();
    final c = _characteristics[key];
    if (c == null) {
      throw BleCharacteristicException(
          message: 'Characteristic not found: $charUuid. '
              'Available: ${_characteristics.keys.join(', ')}');
    }
    return c;
  }

  void _log(String message, LogLevel level) {
    _logController.add(LogEntry(message: message, level: level));
  }

  repo.BleConnectionState _mapState(BluetoothConnectionState s) =>
      switch (s) {
        BluetoothConnectionState.connected => repo.BleConnectionState.connected,
        BluetoothConnectionState.disconnected =>
          repo.BleConnectionState.disconnected,
        _ => repo.BleConnectionState.disconnected,
      };

  String _deviceLabel(String id) => id.length > 8 ? id.substring(0, 8) : id;

  String _shortUuid(String uuid) =>
      uuid.length > 8 ? '${uuid.substring(0, 8)}…' : uuid;

}
