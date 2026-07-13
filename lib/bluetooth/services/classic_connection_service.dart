import 'dart:async';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../../core/bt_utils.dart';
import '../../core/exceptions/ble_characteristic_exception.dart';
import '../../core/exceptions/ble_connection_exception.dart';
import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart' as repo;

class ClassicBluetoothConnectionService implements repo.BleConnectionRepository {
  final _bt = FlutterClassicBluetooth();
  BtcConnection? _connection;

  final _stateController =
      StreamController<repo.BleConnectionState>.broadcast();
  final _logController = StreamController<LogEntry>.broadcast();
  final _notifyController = StreamController<List<int>>.broadcast();

  StreamSubscription<BtcConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _inputSub;

  @override
  Stream<repo.BleConnectionState> get connectionState =>
      _stateController.stream;

  @override
  Stream<LogEntry> get logs => _logController.stream;

  // ─── Bağlantı ─────────────────────────────────────────────────────────────

  @override
  Future<void> connect(String deviceId) async {
    _log('$deviceId cihazına bağlanılıyor (SPP)...', LogLevel.info);
    _stateController.add(repo.BleConnectionState.connecting);

    try {
      _connection = await _bt.connect(
        address: deviceId,
        uuid: BtcUuid.spp,
        timeout: const Duration(seconds: 10),
      );

      _connStateSub = _connection!.stateStream.listen((s) {
        _stateController.add(_mapState(s));
        if (s == BtcConnectionState.disconnected) {
          _log('Connection dropped by remote.', LogLevel.info);
        }
      });

      _stateController.add(repo.BleConnectionState.connected);
      _log('SPP connection established.', LogLevel.success);
    } on BtcTimeoutException catch (e) {
      _stateController.add(repo.BleConnectionState.disconnected);
      _log('Connection timed out.', LogLevel.error);
      throw BleConnectionException(
          message: 'Connection timed out.', cause: e);
    } on BtcConnectionException catch (e) {
      _stateController.add(repo.BleConnectionState.disconnected);
      _log('Connection failed: ${e.message}', LogLevel.error);
      throw BleConnectionException(
          message: 'SPP connection failed.', cause: e);
    } catch (e) {
      _stateController.add(repo.BleConnectionState.disconnected);
      _log('Connection failed: $e', LogLevel.error);
      throw BleConnectionException(
          message: 'Unexpected connection error.', cause: e);
    }
  }

  @override
  Future<void> disconnect() async {
    _log('Disconnecting...', LogLevel.info);
    _stateController.add(repo.BleConnectionState.disconnecting);

    await _inputSub?.cancel();
    _inputSub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;

    await _connection?.finish();
    _connection?.dispose();
    _connection = null;

    _stateController.add(repo.BleConnectionState.disconnected);
    _log('Disconnected.', LogLevel.info);
  }

  // ─── Servis Keşfi (SPP stub) ──────────────────────────────────────────────

  @override
  Future<List<BleGattService>> discoverServices() async {
    _log('SPP mode service discovery — returning fixed profile.',
        LogLevel.info);
    _log('Service: SPP', LogLevel.info);
    _log('  └─ SPP_DATA [Read, Write, Notify]', LogLevel.info);

    return const [
      BleGattService(
        uuid: 'SPP',
        characteristics: [
          BleGattCharacteristic(
            uuid: 'SPP_DATA',
            canRead: true,
            canWrite: true,
            canNotify: true,
          ),
        ],
      ),
    ];
  }

  // ─── Yazma ────────────────────────────────────────────────────────────────

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    _ensureConnected();
    try {
      await _connection!.output.writeBytes(data);
      _log('→ Sent [SPP]: ${bytesToHex(data)}', LogLevel.outgoing);
    } catch (e) {
      throw BleCharacteristicException(
          message: 'SPP write failed.', cause: e);
    }
  }

  // ─── Okuma ────────────────────────────────────────────────────────────────

  @override
  Future<List<int>> readCharacteristic(String charUuid) async {
    _ensureConnected();
    try {
      final bytes = await _notifyController.stream.first
          .timeout(const Duration(seconds: 5));
      _log('← Read [SPP]: ${bytesToHex(bytes)}', LogLevel.incoming);
      return bytes;
    } on TimeoutException {
      throw const BleCharacteristicException(message: 'SPP read timed out.');
    } catch (e) {
      throw BleCharacteristicException(
          message: 'SPP read failed.', cause: e);
    }
  }

  // ─── Notify ───────────────────────────────────────────────────────────────

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {
    _ensureConnected();

    if (enable) {
      await _inputSub?.cancel();
      _inputSub = _connection!.input.listen((bytes) {
        if (bytes.isNotEmpty) {
          final intList = List<int>.from(bytes);
          _log('← Notify [SPP]: ${bytesToHex(intList)}', LogLevel.incoming);
          _notifyController.add(intList);
        }
      });
      _log('SPP data listening active.', LogLevel.info);
    } else {
      await _inputSub?.cancel();
      _inputSub = null;
      _log('SPP data listening stopped.', LogLevel.info);
    }
  }

  @override
  Stream<List<int>> notifyStream(String charUuid) => _notifyController.stream;

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _logController.close();
    await _notifyController.close();
  }

  // ─── Yardımcılar ──────────────────────────────────────────────────────────

  void _ensureConnected() {
    if (_connection == null || !_connection!.isConnected) {
      throw const BleConnectionException(
          message: 'Connect first before attempting operation.');
    }
  }

  repo.BleConnectionState _mapState(BtcConnectionState s) => switch (s) {
        BtcConnectionState.connected => repo.BleConnectionState.connected,
        BtcConnectionState.connecting => repo.BleConnectionState.connecting,
        BtcConnectionState.disconnecting =>
          repo.BleConnectionState.disconnecting,
        BtcConnectionState.disconnected => repo.BleConnectionState.disconnected,
      };

  void _log(String message, LogLevel level) {
    _logController.add(LogEntry(message: message, level: level));
  }

}
