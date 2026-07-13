import 'dart:async';

import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';
import '../repositories/ble_connection_repository.dart';

class SimulatedConnectionService implements BleConnectionRepository {
  final _stateCtrl  = StreamController<BleConnectionState>.broadcast();
  final _logCtrl    = StreamController<LogEntry>.broadcast();
  final _sppDataCtrl = StreamController<List<int>>.broadcast();

  // WriteDataByIdentifier ile yazılan değerleri tutar; sonraki
  // ReadDataByIdentifier çağrıları gerçek cihaz gibi bu değeri geri döner.
  final Map<int, List<int>> _writtenValues = {};

  @override
  Stream<BleConnectionState> get connectionState => _stateCtrl.stream;

  @override
  Stream<LogEntry> get logs => _logCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    _emit(BleConnectionState.connecting);
    _log('Simülasyon bağlantısı başlatılıyor...', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 400));
    _log('Cihaz keşfedildi: $deviceId', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 500));
    _log('GATT kanalı açıldı', LogLevel.info);
    await Future.delayed(const Duration(milliseconds: 300));
    _emit(BleConnectionState.connected);
    _log('Bağlantı başarılı ✓  [SİMÜLASYON MODU]', LogLevel.success);
  }

  @override
  Future<void> disconnect() async {
    _emit(BleConnectionState.disconnecting);
    await Future.delayed(const Duration(milliseconds: 200));
    _emit(BleConnectionState.disconnected);
    _log('Simülasyon bağlantısı kesildi', LogLevel.info);
  }

  @override
  Future<List<BleGattService>> discoverServices() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _log('Servis keşfi tamamlandı (simüle)', LogLevel.info);
    return const [
      BleGattService(
        uuid: 'SIM-SERVICE-0001',
        characteristics: [
          BleGattCharacteristic(uuid: 'SPP_DATA', canRead: true, canWrite: true, canNotify: true),
        ],
      ),
    ];
  }

  @override
  Future<List<int>> readCharacteristic(String charUuid) async => [];

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
    _log(hex, LogLevel.outgoing);
    await Future.delayed(const Duration(milliseconds: 60));

    if (charUuid == 'SPP_DATA') {
      final response = _buildKLineResponse(data);
      if (response != null) {
        final respHex = response.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
        _log(respHex, LogLevel.incoming);
        _sppDataCtrl.add(response);
      }
    }
  }

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {}

  @override
  Stream<List<int>> notifyStream(String charUuid) {
    if (charUuid == 'SPP_DATA') return _sppDataCtrl.stream;
    return const Stream.empty();
  }

  @override
  void dispose() {
    _stateCtrl.close();
    _logCtrl.close();
    _sppDataCtrl.close();
  }

  // ── K-LINE frame parser & response builder ───────────────────────────────

  List<int>? _buildKLineResponse(List<int> req) {
    if (req.isEmpty) return null;
    final fmt = req[0];

    // Wakeup byte (0x00) — no response
    if (fmt == 0x00) return null;

    // Fast-init StartCommunication: 81 EE F0 81 CS
    if (fmt == 0x81) return _fastInitResp(0x81);

    // Standard frame: 80 EE F0 LEN SID DATA... CS
    if (fmt == 0x80 && req.length >= 5) {
      final sid  = req[4];
      final data = req.length > 6 ? req.sublist(5, req.length - 1) : <int>[];
      return _handleSid(sid, data);
    }

    return null;
  }

  List<int>? _handleSid(int sid, List<int> data) {
    switch (sid) {
      case 0x82: // StopCommunication → C2
        return _stdResp(0xC2, []);

      case 0x10: // StartDiagnosticSession → 50 <sessionType>
        return _stdResp(0x50, data.isNotEmpty ? [data[0]] : []);

      case 0x3E: // TesterPresent
        // sub-function 0x02 = suppress response
        if (data.isNotEmpty && data[0] == 0x02) return null;
        return _stdResp(0x7E, [data.isNotEmpty ? data[0] : 0x01]);

      case 0x27: // SecurityAccess
        if (data.isEmpty) return null;
        if (data[0] == 0x7D) {
          // RequestSeed → return mock seed bytes
          return _stdResp(0x67, [0x7D, 0xA3, 0xF7, 0x2C, 0x51]);
        }
        if (data[0] == 0x7E) {
          // SendKey → always succeed in simulation
          return _stdResp(0x67, [0x7E]);
        }
        return null;

      case 0x22: // ReadDataByIdentifier
        if (data.length < 2) return null;
        final rid     = (data[0] << 8) | data[1];
        final payload = _writtenValues[rid] ?? _getMockRdbiData(rid);
        if (payload == null) {
          // Negative: requestOutOfRange
          return _stdResp(0x7F, [0x22, 0x31]);
        }
        return _stdResp(0x62, [data[0], data[1], ...payload]);

      case 0x2E: // WriteDataByIdentifier → store value, echo back the record ID
        if (data.length < 2) return null;
        final wRid = (data[0] << 8) | data[1];
        _writtenValues[wRid] = data.sublist(2);
        return _stdResp(0x6E, [data[0], data[1]]);

      case 0x31: // RoutineControl
        if (data.length < 3) return null;
        final sub  = data[0];
        final ridH = data[1];
        final ridL = data[2];
        if (sub == 0x03) {
          // requestRoutineResults → result=0x01 (success/paired)
          return _stdResp(0x71, [sub, ridH, ridL, 0x01]);
        }
        return _stdResp(0x71, [sub, ridH, ridL]);

      case 0x19: // ReadDTCInformation
        if (data.isEmpty) return null;
        return _handleReadDtc(data[0]);

      case 0x14: // ClearDiagnosticInformation
        return _stdResp(0x54, []);

      case 0x2F: // IOControlByIdentifier
        if (data.length < 2) return null;
        return _stdResp(0x6F, [data[0], data[1]]);

      default:
        return null;
    }
  }

  List<int>? _handleReadDtc(int sub) {
    if (sub == 0x01) {
      // reportNumberOfDTCByStatusMask → 2 mock DTCs
      return _stdResp(0x59, [0x00, 0x02]);
    }
    if (sub == 0x02) {
      // reportDTCByStatusMask → 2 × (3-byte code + 1-byte status)
      return _stdResp(0x59, [
        // DTC 1: 0x001301 status=0x08 (stored fault)
        0x00, 0x13, 0x01, 0x08,
        // DTC 2: 0x002005 status=0x01 (pending fault)
        0x00, 0x20, 0x05, 0x01,
      ]);
    }
    return null;
  }

  // ── Mock RDBI data table ──────────────────────────────────────────────────

  List<int>? _getMockRdbiData(int rid) {
    switch (rid) {
      case 0xF190: // VIN — 17 bytes ASCII
        return _ascii('WVWZZZ1JZ3W000001', 17);
      case 0xF97E: // VRN — 14 bytes ASCII, space-padded
        return _ascii('34ABC1234', 14);
      case 0xF97D: // Member State — 3 bytes ASCII
        return _ascii('TUR', 3);
      case 0xF97F: // Vehicle Registration Date — 8 bytes (2020-03-10)
        return [0x00, 0x00, 0x00, 3, 4 * (10 - 1) + 2, 20, 0x7D, 0x7D];
      case 0xF912: // Odometer — 4 bytes BE (125 430 km)
        return _u32(125430);
      case 0xF918: // K-Constant — 2 bytes BE (6 000 imp/km)
        return _u16(6000);
      case 0xF91C: // Tyre Circumference — 2 bytes (value × 8, 2 885 mm)
        return _u16(2885 * 8);
      case 0xF91D: // W-Constant — 2 bytes BE (6 000 imp/km)
        return _u16(6000);
      case 0xF921: // Tyre Size — 15 bytes ASCII, space-padded
        return _ascii('295/80R22.5H', 15);
      case 0xF922: // Next Calibration Date — [Month, 4*(Day-1)+2, Year%100]
        return [6, 4 * (15 - 1) + 2, 27]; // 2027-06-15
      case 0xF92C: // Speed Limit — [speed, 0x00]
        return [90, 0x00];
      case 0xF90B: // CurrentDateTime — 8 bytes
        final now = DateTime.now();
        return [
          0x00,
          now.minute,
          now.hour,
          now.month,
          4 * (now.day - 1) + 2,
          now.year % 100,
          0x80, // UTC+3 hour offset: (3/1)+0x7D = 0x80
          0x7D, // UTC+0 minute offset
        ];
      case 0xF902: // VehicleSpeed — 0 km/h (speed × 256)
        return [0x00, 0x00];
      case 0xF18C: // Serial Number
        return _ascii('SN-2026-000123', 14);
      case 0xF192: // HW Number
        return _ascii('STC8250-02', 11);
      case 0xF193: // HW Version Number
        return _ascii('01.05', 5);
      case 0xF195: // SW Version Number
        return _ascii('02.13', 5);
      case 0xF990: return [90]; // Download Period Card
      case 0xF991: return [30]; // Download Period VU
      case 0xF994: return [14]; // Prewarning Card1
      case 0xF995: return [14]; // Prewarning Tacho
      case 0xF996: return [30]; // Prewarning Calibration
      default:
        return null;
    }
  }

  // ── Frame helpers ─────────────────────────────────────────────────────────

  // Standard KWP2000 response: [0x80, 0xF0, 0xEE, LEN, SID, payload..., CS]
  static List<int> _stdResp(int sid, List<int> payload) {
    final len   = 1 + payload.length;
    final frame = [0x80, 0xF0, 0xEE, len, sid, ...payload];
    final cs    = frame.fold(0, (s, b) => s + b) & 0xFF;
    return [...frame, cs];
  }

  // Fast-init response: [0xC1, 0xF0, 0xEE, SID, CS]
  static List<int> _fastInitResp(int sid) {
    final frame = [0xC1, 0xF0, 0xEE, sid];
    final cs    = frame.fold(0, (s, b) => s + b) & 0xFF;
    return [...frame, cs];
  }

  // ASCII bytes, space-padded to [len]
  static List<int> _ascii(String s, int len) {
    final bytes = List<int>.filled(len, 0x20);
    for (int i = 0; i < s.length && i < len; i++) {
      bytes[i] = s.codeUnitAt(i);
    }
    return bytes;
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];

  static List<int> _u32(int v) => [
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8)  & 0xFF,
        v         & 0xFF,
      ];

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _emit(BleConnectionState s) => _stateCtrl.add(s);
  void _log(String msg, LogLevel lvl) =>
      _logCtrl.add(LogEntry(message: msg, level: lvl));
}
