// K-LINE frame oluşturma, checksum hesabı ve yanıt ayrıştırma
// Protokol: KWP2000 / ISO 14230 — CalibrationMessages.md Frame Format

import '../bluetooth/models/log_entry.dart';
import '../core/app_logger.dart';
import 'kline_records.dart';

// ── Frame sabitleri ────────────────────────────────────────────────────────
const int _fmtStandard    = 0x80; // Standart format (LEN ayrı byte)
const int _fmtFastInit    = 0x81; // FastInit format (StartCommunication TX)
const int _fmtFastResp   = 0xC1; // FastInit format (StartCommunication RX)
const int _tAddr          = 0xEE; // Target: Tachograph ECU
const int _sAddr          = 0xF0; // Source: Calibration device

// ── Checksum ───────────────────────────────────────────────────────────────
int _cs(List<int> bytes) => bytes.fold(0, (sum, b) => sum + b) & 0xFF;

// ── Frame oluşturucu ───────────────────────────────────────────────────────
class KLineFrame {
  KLineFrame._();

  // Wakeup: 0x00 byte (adaptör bu byte'ı alınca K-LINE wakeup sekansını başlatır)
  static List<int> wakeup() => [0x00];

  // StartCommunication — fast-init format: 81 EE F0 81 E0
  static List<int> startCommunication() {
    const frame = [_fmtFastInit, _tAddr, _sAddr, KLineSid.startComm];
    return [...frame, _cs(frame)];
  }

  // StopCommunication: 80 EE F0 01 82 E1
  static List<int> stopCommunication() =>
      build(KLineSid.stopComm, const []);

  // StartDiagnosticSession: 80 EE F0 02 10 <sessionType> <CS>
  static List<int> startDiagnosticSession(int sessionType) =>
      build(KLineSid.sessionCtrl, [sessionType]);

  // TesterPresent (no response): 80 EE F0 02 3E 02 A0
  static List<int> testerPresentNoResponse() =>
      build(KLineSid.testerPresent, const [0x02]);

  // TesterPresent (response required): 80 EE F0 02 3E 01 9F
  static List<int> testerPresentWithResponse() =>
      build(KLineSid.testerPresent, const [0x01]);

  // SecurityAccess RequestSeed: 80 EE F0 02 27 7D 04
  static List<int> securityAccessRequestSeed() =>
      build(KLineSid.secAccess, const [0x7D]);

  // SecurityAccess SendKey: 80 EE F0 <PIN_len+2> 27 7E <PIN ASCII...> <CS>
  static List<int> securityAccessSendKey(List<int> pinAscii) =>
      build(KLineSid.secAccess, [0x7E, ...pinAscii]);

  // ReadDataByIdentifier: 80 EE F0 03 22 <RID_H> <RID_L> <CS>
  static List<int> readDataByIdentifier(int recordId) =>
      build(KLineSid.rdbi, [(recordId >> 8) & 0xFF, recordId & 0xFF]);

  // WriteDataByIdentifier: 80 EE F0 <len> 2E <RID_H> <RID_L> <data...> <CS>
  static List<int> writeDataByIdentifier(int recordId, List<int> data) =>
      build(KLineSid.wdbi, [(recordId >> 8) & 0xFF, recordId & 0xFF, ...data]);

  // RoutineControl (no extra param): 80 EE F0 04 31 <select> <RID_H> <RID_L> <CS>
  static List<int> routineControl(int select, int routineId) => build(
        KLineSid.routineCtrl,
        [select, (routineId >> 8) & 0xFF, routineId & 0xFF],
      );

  // RoutineControl with result/slot: 80 EE F0 05 31 <select> <RID_H> <RID_L> <extra> <CS>
  static List<int> routineControlWithExtra(int select, int routineId, int extra) =>
      build(
        KLineSid.routineCtrl,
        [select, (routineId >> 8) & 0xFF, routineId & 0xFF, extra],
      );

  // IOControlByIdentifier: 80 EE F0 05 2F F9 60 <controlOption> <param> <CS>
  static List<int> ioControlByIdentifier(int controlOption, int param) => build(
        KLineSid.iocp,
        [
          (KLineRecords.iocpDataId >> 8) & 0xFF,
          KLineRecords.iocpDataId & 0xFF,
          controlOption,
          param,
        ],
      );

  // IOControlByIdentifier reset (no param): 80 EE F0 04 2F F9 60 01 EB
  static List<int> ioControlReset() => build(
        KLineSid.iocp,
        [
          (KLineRecords.iocpDataId >> 8) & 0xFF,
          KLineRecords.iocpDataId & 0xFF,
          KLineIocpControl.returnControlToEcu,
        ],
      );

  // ReadDTC NumberByStatusMask: 80 EE F0 03 19 01 09 84
  static List<int> readDtcNumberByStatusMask() =>
      build(KLineSid.readDtcInfo, const [0x01, 0x09]);

  // ReadDTC ByStatusMask: 80 EE F0 03 19 02 09 85
  static List<int> readDtcByStatusMask() =>
      build(KLineSid.readDtcInfo, const [0x02, 0x09]);

  // ClearDiagnosticInformation (all DTCs): 80 EE F0 04 14 FF FF FF 73
  static List<int> clearDiagnosticInformation() =>
      build(KLineSid.clearDtcInfo, const [0xFF, 0xFF, 0xFF]);

  // ── Genel frame builder ─────────────────────────────────────────────────
  // [0x80][0xEE][0xF0][LEN][SID][DATA...][CS]
  // LEN = 1 (SID) + data.length
  static List<int> build(int sid, List<int> data) {
    final len = 1 + data.length;
    final frame = [_fmtStandard, _tAddr, _sAddr, len, sid, ...data];
    return [...frame, _cs(frame)];
  }
}

// ── Yanıt modeli ───────────────────────────────────────────────────────────
class KLineResponse {
  const KLineResponse({
    required this.sid,
    required this.data,
    this.isNegative = false,
    this.nrc,
    this.ridHigh,
    this.ridLow,
  });

  final int sid;        // Pozitif: 0x62 (RDBI), 0x6E (WDBI), 0x50 (session), vs.
  final List<int> data; // SID + RID sonrası payload
  final bool isNegative;
  final int? nrc;       // Negative Response Code (0x78, 0x35, vs.)
  final int? ridHigh;   // RDBI/WDBI yanıtlarından ayrıştırılan Record ID high byte
  final int? ridLow;

  int? get recordId =>
      (ridHigh != null && ridLow != null) ? (ridHigh! << 8) | ridLow! : null;

  @override
  String toString() => isNegative
      ? 'KLineResponse(NEGATIVE nrc=0x${nrc?.toRadixString(16).toUpperCase()})'
      : 'KLineResponse(sid=0x${sid.toRadixString(16).toUpperCase()}, '
          'data=${data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')})';
}

// ── Frame buffer — SPP'den gelen chunked baytları birleştirip frame ayrıştırır
class KLineFrameBuffer {
  final List<int> _buf = [];

  void add(List<int> bytes) => _buf.addAll(bytes);

  void clear() => _buf.clear();

  // Tamponda tam bir yanıt frame'i varsa ayrıştırır, yoksa null döner.
  // Ayrıştırılan baytlar tampondan çıkarılır.
  KLineResponse? tryParse() {
    if (_buf.isEmpty) return null;

    final fmt = _buf[0];

    // Fast-init response: C1 EE F0 <SID> <CS> (5 byte)
    if (fmt == _fmtFastResp) {
      if (_buf.length < 5) return null;
      final frame = _buf.sublist(0, 5);
      final result = _parseFastInitResponse(frame);
      if (result == null) {
        // Checksum tutmadı — muhtemel desync. Tüm frame'i atıp olası
        // sonraki gerçek yanıtı kaybetmek yerine tek bayt atlayıp
        // bir sonraki header adayıyla yeniden senkronize olmayı dene.
        _buf.removeAt(0);
        return null;
      }
      _buf.removeRange(0, 5);
      return result;
    }

    // Standard response: 80 F0 EE LEN SID [DATA...] CS
    if (fmt == _fmtStandard) {
      if (_buf.length < 5) return null; // En az header+LEN+SID+CS
      final len = _buf[3];
      final totalLen = 4 + len + 1; // FMT+TADDR+SADDR+LEN + payload + CS
      if (_buf.length < totalLen) return null;
      final frame = _buf.sublist(0, totalLen);
      final result = _parseStandardResponse(frame);
      if (result == null) {
        // Checksum tutmadı — LEN baytı bozuk/desync olabilir. Tüm dilimi
        // atmak yerine tek bayt atlayıp yeniden senkronize olmayı dene;
        // böylece asıl yanıt bu "frame" içinde gömülüyse kaybolmaz.
        _buf.removeAt(0);
        return null;
      }
      _buf.removeRange(0, totalLen);
      return result;
    }

    // Unknown format — skip byte
    AppLogger.instance.log(
      'Unknown frame format: 0x${fmt.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
      'skipped 1 byte from buffer head (buffer size: ${_buf.length} bytes)',
      level: LogLevel.error,
      category: LogCategory.bluetooth,
    );
    _buf.removeAt(0);
    return null;
  }

  KLineResponse? _parseFastInitResponse(List<int> frame) {
    // C1 F0 EE <SID> <CS>
    final expectedCs = _cs(frame.sublist(0, 4));
    if (frame[4] != expectedCs) {
      AppLogger.instance.log(
        'FastInit checksum error: '
        'expected 0x${expectedCs.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
        'received 0x${frame[4].toRadixString(16).padLeft(2, '0').toUpperCase()}',
        level: LogLevel.error,
        category: LogCategory.bluetooth,
      );
      return null;
    }
    return KLineResponse(sid: frame[3], data: const []);
  }

  KLineResponse? _parseStandardResponse(List<int> frame) {
    // 80 F0 EE LEN [SID] [DATA...] CS
    final payload = frame.sublist(4, frame.length - 1);
    final receivedCs = frame.last;
    final expectedCs = _cs(frame.sublist(0, frame.length - 1));
    if (receivedCs != expectedCs) {
      AppLogger.instance.log(
        'Standard frame checksum error: '
        'expected 0x${expectedCs.toRadixString(16).padLeft(2, '0').toUpperCase()}, '
        'received 0x${receivedCs.toRadixString(16).padLeft(2, '0').toUpperCase()}',
        level: LogLevel.error,
        category: LogCategory.bluetooth,
      );
      return null;
    }

    if (payload.isEmpty) return null;
    final sid = payload[0];

    // Negatif yanıt: 7F <originalSID> <NRC>
    if (sid == KLineSid.negativeResp && payload.length >= 3) {
      return KLineResponse(
        sid: payload[1],
        data: const [],
        isNegative: true,
        nrc: payload[2],
      );
    }

    // RDBI / WDBI yanıtı — RID bytes çıkar
    // RDBI pozitif: 0x62; WDBI pozitif: 0x6E
    if ((sid == 0x62 || sid == 0x6E) && payload.length >= 3) {
      return KLineResponse(
        sid: sid,
        ridHigh: payload[1],
        ridLow: payload[2],
        data: payload.sublist(3),
      );
    }

    // RoutineControl pozitif: 0x71 — RID bytes çıkar
    if (sid == 0x71 && payload.length >= 4) {
      return KLineResponse(
        sid: sid,
        ridHigh: payload[2],
        ridLow: payload[3],
        data: payload.sublist(4),
      );
    }

    // Diğer pozitif yanıtlar (0x50 session, 0x67 secAccess, vs.)
    return KLineResponse(sid: sid, data: payload.sublist(1));
  }
}
