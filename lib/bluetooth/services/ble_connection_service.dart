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

    _resolveSppDataAlias(rawServices);

    return services;
  }

  // KLineService, transporttan bağımsız olarak sabit 'SPP_DATA' kanal adını
  // kullanır (bkz. CLAUDE.md). Standart BT SIG servisleri (1800/1801/180A/...)
  // kısa UUID string'i döndürür; K-Line adaptörünün özel servisi her zaman
  // 128-bit (tire içeren) bir UUID'dir. Bu nedenle standart servisleri eleyip,
  // yazma+notify destekleyen ilk özel karakteristiği 'SPP_DATA' olarak
  // eşliyoruz. Birden fazla aday bulunursa hepsi loglanır — adaptör K-Line
  // wakeup'a yanıt vermezse, ilk adayın yanlış seçilmiş olabileceğini gösterir.
  void _resolveSppDataAlias(List<BluetoothService> rawServices) {
    final candidates = <BluetoothCharacteristic>[];
    for (final s in rawServices) {
      if (s.serviceUuid.str.length <= 4) continue; // standart BT SIG servisi
      for (final c in s.characteristics) {
        final canWrite = c.properties.write || c.properties.writeWithoutResponse;
        final canNotify = c.properties.notify || c.properties.indicate;
        if (canWrite && canNotify) candidates.add(c);
      }
    }

    if (candidates.isEmpty) {
      _log(
        'SPP_DATA alias çözülemedi: yazma+notify destekleyen özel karakteristik bulunamadı.',
        LogLevel.error,
      );
      return;
    }

    if (candidates.length > 1) {
      _log(
        'Birden fazla SPP_DATA adayı bulundu, ilki kullanılıyor. Adaylar: '
        '${candidates.map((c) => c.characteristicUuid.str.toUpperCase()).join(', ')}',
        LogLevel.info,
      );
    }

    final chosen = candidates.first;
    _characteristics['SPP_DATA'] = chosen;
    _log(
      'SPP_DATA → ${chosen.characteristicUuid.str.toUpperCase()} olarak eşlendi.',
      LogLevel.success,
    );
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
      // Teşhis: K-Line'ın bayt-arası zamanlaması (ISO 14230 P4, bkz.
      // KLineService._write()) yazılım tarafında eklenen sabit gecikmeye
      // dayanıyor — ama "with response" yazımda her bayt bir BLE ACK
      // round-trip'i bekliyor, bu da gerçek boşluğu öngörülemez şekilde
      // artırabilir. Hangi modun kullanıldığını burada logluyoruz ki
      // PossibleProblems.md #17'deki (her mesajda tekrarlayan FMT/TGT/SRC
      // check failure) teşhis gerçek donanımda doğrulanabilsin.
      final usingWithoutResponse = c.properties.writeWithoutResponse;
      if (usingWithoutResponse) {
        await c.write(data, withoutResponse: true);
      } else {
        await c.write(data);
      }
      _log(
        '→ Sent [${_shortUuid(charUuid)}] '
        '(${usingWithoutResponse ? "without response" : "ACK'li (with response)"}): '
        '${bytesToHexRedacted(data)}',
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
        // DİKKAT: c.lastValueStream KULLANMA — flutter_blue_plus'ta bu stream
        // hem gerçek gelen bildirimleri HEM DE bizim write() çağrılarımızın
        // yankısını (onCharacteristicWritten) yayınlar. K-Line request/response
        // aynı karakteristik üzerinden aktığı için bu, kendi giden byte'larımızı
        // gelen yanıt gibi buffer'a sokup her mesajı bozuyordu (bkz.
        // PossibleProblems.md). onValueReceived sadece read()/gerçek notify
        // olaylarını yayınlar — write() çağrılarını içermez.
        _notifySubs[charUuid] = c.onValueReceived.listen((bytes) {
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
