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

  // ClearDiagnosticInformation sonrası true olur; DTC listesi boşalır.
  bool _dtcsCleared = false;

  @override
  Stream<BleConnectionState> get connectionState => _stateCtrl.stream;

  @override
  Stream<LogEntry> get logs => _logCtrl.stream;

  @override
  Future<void> connect(String deviceId) async {
    _dtcsCleared = false;
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
  Future<void> dispose() async {
    await disconnect();
    await _stateCtrl.close();
    await _logCtrl.close();
    await _sppDataCtrl.close();
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
        _dtcsCleared = true;
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
      // reportNumberOfDTCByStatusMask
      return _stdResp(0x59, [0x00, _dtcsCleared ? 0x00 : 0x02]);
    }
    if (sub == 0x02) {
      // reportDTCByStatusMask → 2 × (3-byte code + 1-byte status).
      // Kodlar kline_dtc_mapper.dart'taki _descriptions tablosuyla eşleşir ki
      // Tanılama sekmesi anlamlı bir açıklama/modül gösterebilsin.
      if (_dtcsCleared) return _stdResp(0x59, []);
      return _stdResp(0x59, [
        // DTC 1: Hareket sensörü sinyal yok — status=0x08 → saklı (bit0=0 → pasif)
        0x01, 0x00, 0x01, 0x08,
        // DTC 2: Sürücü kartı okuyucu arızası — status=0x01 → aktif (bit0=1)
        0x02, 0x00, 0x01, 0x01,
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

      // ── Dashboard / Cihaz Bilgisi ──────────────────────────────────────────
      case 0xF18A: // System Supplier Identifier
        return _ascii('STONERIDGE-TR', 15);
      case 0xF194: // SW Number
        return _ascii('SW-STC-0213', 11);
      case 0xF196: // Exhaust Reg / Type Approval Number
        return _ascii('E1*2016/1230*00001', 20);

      // ── Kalibrasyon Parametreleri sekmesi — Sistem ve Lastik grupları ──────
      case 0xF19D: // ECU Install Date — 3 byte BCD (2020-03-15)
        return [0x20, 0x03, 0x15];
      case 0xF90C: // Reset Heartbeat — 0x00=Disabled, 0x01=Enabled
        return [0x01];
      case 0xF90D: // UTC Minute Offset byte (UTC+3 ile eşleşir, bkz. 0xF90B)
        return [0x7D];
      case 0xF90E: // UTC Hour Offset byte (UTC+3 ile eşleşir, bkz. 0xF90B)
        return [0x8C];
      case 0xF90F: // TCO1 Priority — 0x00=Highest
        return [0x00];
      case 0xF913: // Trip Distance — 4 byte BE (1 520 km)
        return _u32(1520);
      case 0xF91A: // Teeth Count
        return [60];
      case 0xF91E: // PPROOS — 2 byte BE
        return _u16(4000);
      case 0xF920: // TCO1 Repetition Rate — 0x00=20ms
        return [0x00];

      // ── Opsiyonel Ayarlar (0xFDxx) — STC8250 aralığı (FD00–FD19) ───────────
      // Simüle edilen hwNumber "STC8250-02" olduğundan Opsiyonel Ayarlar
      // ekranı isStc8255=false modunda okur; bu blok o yolu besler. FD10–FD19
      // aralığı STC8255 varyantında farklı alanlara denk gelir (bkz.
      // kline_records.dart) ama uygulama o RID'leri yalnızca isStc8255=true
      // iken sorguladığından burada çakışma oluşmaz.
      case 0xFD00: return _u16(8000); // Speedometer Factor
      case 0xFD01: return [0x01]; // B7 Recognize
      case 0xFD02: return [200, 180, 150, 200, 200]; // Card Expiry Dates
      case 0xFD03: return _u16(1); // CAN C On/Off (2 byte)
      case 0xFD04: return [0x00]; // Military Dimmer
      case 0xFD05: return [0xFF, 0x32 | 0x80]; // CAN C TCO1
      case 0xFD06: return [5]; // Overspeed Prewarning Time (s)
      case 0xFD07: return [0x01, 0x00, 0x01, 0x00]; // Ignition Options — Sürücü
      case 0xFD08: return [1, 5]; // CAN A Baudrate — 250 kbps
      case 0xFD09: return [2, 5]; // CAN C Baudrate — 500 kbps
      case 0xFD0A: return [5, 0x01]; // Backlight & Battery — 24V
      case 0xFD0B: return [0x01]; // Distance Unit — km
      case 0xFD0C: return [0x02]; // Language Change — Karttan
      case 0xFD0D: return [2]; // Overspeed Output — Buzzer
      case 0xFD0E: return [0x01]; // Buzzer Overspeed Control
      case 0xFD0F: return [0x01]; // IMS Source — CAN A
      case 0xFD10: return [0x01]; // Overspeed TCO1
      case 0xFD11: return [0x01]; // Tripmeter Reset
      case 0xFD12: return [0x01]; // Output Shaft Speed Enable
      case 0xFD13: return [1]; // TCO1 Handling Info — Kart
      case 0xFD14: return [5]; // CAN A Sample Point
      case 0xFD15: return [2]; // CAN A Sync Jump
      case 0xFD16: return [5]; // CAN C Sample Point
      case 0xFD17: return [2]; // CAN C Sync Jump
      case 0xFD18: return [0x00]; // IMS CAN PGN — 65215
      case 0xFD19: return _u16(1); // CAN A On/Off (2 byte)

      // ── Opsiyonel Ayarlar — STC8255'e özgü aralık (FD1A ve üzeri) ──────────
      case 0xFD1A: return [5]; // Overspeed Prewarning Time
      case 0xFD1B: return [2]; // Overspeed Output — Buzzer
      case 0xFD1C: return [0x01]; // B7 Recognize
      case 0xFD1D: return [0x01, 0x00]; // D1/D2 State Enable
      case 0xFD1E: return [0x01]; // Distance Unit — km
      case 0xFD1F: return [0x01]; // Buzzer Overspeed Control
      case 0xFD22: return [200, 180, 150, 200, 200]; // Card Expiry Dates
      case 0xFD23: return [1]; // Engine Speed Source — CAN-A
      case 0xFD30: return [1, 2]; // CAN Protocols P1/P2
      case 0xFD31: return [0x01]; // CAN A On/Off
      case 0xFD32: return [1, 5]; // CAN A Baudrate — 250 kbps
      case 0xFD33: return [2]; // CAN A Sync Jump
      case 0xFD34: return [0x01]; // CAN C On/Off
      case 0xFD35: return [2, 5]; // CAN C Baudrate — 500 kbps
      case 0xFD36: return [2]; // CAN C Sync Jump
      case 0xFD3A: return [0x01]; // Overspeed TCO1
      case 0xFD3B: return [0x01]; // Tripmeter Reset
      case 0xFD3C: return [1]; // TCO1 Handling Info — Kart
      case 0xFD3D: return [0x01, 0x01]; // CAN A/C Termination
      case 0xFD3E: return [0x00]; // RDDW in Sleep
      case 0xFD41: return [0x01]; // Periodic DAGS
      case 0xFD50: return [0x01]; // DAGS Buzzer Control
      case 0xFD51: return [0x01]; // Card Existence Warning
      case 0xFD53: return [0x00]; // GNSS Antenna — İç

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
