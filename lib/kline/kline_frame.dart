// K-LINE frame oluşturma, checksum hesabı ve yanıt ayrıştırma
// Protokol: KWP2000 / ISO 14230 — Regulation (EU) 2016/799, Annex 1C,
// Appendix 8 "Calibration Protocol" (CELEX 02016R0799) — Tables 4-6.

import '../bluetooth/models/log_entry.dart';
import '../core/app_logger.dart';
import 'kline_records.dart';

// ── Frame sabitleri ────────────────────────────────────────────────────────
const int _fmtStandard    = 0x80; // Standart format (LEN ayrı byte)
const int _fmtFastInit    = 0x81; // FastInit format (StartCommunication TX — Table 5)
const int _tAddr          = 0xEE; // Target: Tachograph ECU
const int _sAddr          = 0xF0; // Source: Calibration device ("tt" — Regülasyon herhangi bir tester adresini kabul edileceğini belirtiyor)

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
  // Protokolün tek baytlık LEN alanının teorik maksimumunun (255) güvenli
  // bir üst payı — bozuk/gürültülü veri altında sınırsız büyümeyi engeller.
  static const int _maxBufferSize = 512;

  final List<int> _buf = [];

  // K-LINE fiziksel olarak tek telli (half-duplex) bir hat: gönderdiğimiz her
  // bayt, STKC referans donanımının da (Kline_Port.c::Send_KLINE_Package_
  // Receive_Response) her bayttan sonra bilerek okuyup attığı şekilde, aynı
  // hat üzerinden bize yankı olarak geri dönebilir (köprü adaptörü ham K-LINE
  // geçişi yapıyorsa). expectEcho() ile işaretlenen frame, gelen baytlarla
  // eşleştiği sürece _buf'a hiç girmeden sessizce tüketilir; ilk uyuşmazlıkta
  // eşleştirme bırakılır ve baytlar normal parse/hata akışına döner.
  List<int>? _pendingEcho;
  int _echoMatched = 0;

  void expectEcho(List<int> frame) {
    _pendingEcho = frame;
    _echoMatched = 0;
  }

  void add(List<int> bytes) {
    var start = 0;
    final echo = _pendingEcho;
    if (echo != null) {
      while (start < bytes.length && _echoMatched < echo.length) {
        if (bytes[start] != echo[_echoMatched]) {
          // Not actually an echo — e.g. a genuine response can legitimately
          // share a leading byte with the request (both use FMT=0x80). The
          // bytes tentatively matched so far belong to that real frame, so
          // put them back ahead of the rest of this chunk instead of
          // dropping them.
          _buf.addAll(echo.sublist(0, _echoMatched));
          _pendingEcho = null;
          break;
        }
        _echoMatched++;
        start++;
      }
      if (_pendingEcho != null && _echoMatched == echo.length) {
        _pendingEcho = null; // fully matched — genuine echo, discard silently
      }
    }
    if (start >= bytes.length) return;

    final remaining = start == 0 ? bytes : bytes.sublist(start);
    _buf.addAll(remaining);
    if (_buf.length > _maxBufferSize) {
      final overflow = _buf.length - _maxBufferSize;
      _buf.removeRange(0, overflow);
      AppLogger.instance.log(
        'Frame buffer overflow ($overflow byte atıldı, boyut: ${_buf.length})',
        level: LogLevel.error,
        category: LogCategory.bluetooth,
      );
    }
  }

  void clear() {
    _buf.clear();
    _pendingEcho = null;
    _echoMatched = 0;
  }

  // Tamponda tam bir yanıt frame'i varsa ayrıştırır, yoksa null döner.
  // Ayrıştırılan baytlar tampondan çıkarılır.
  KLineResponse? tryParse() {
    if (_buf.isEmpty) return null;

    final fmt = _buf[0];

    // StartCommunication'ın yanıtı da dahil olmak üzere TÜM yanıtlar standart
    // formatta gelir (Regulation (EU) 2016/799, Annex 1C App.8, Table 6:
    // StartCommunication Positive Response = 80 <tt> EE 03 C1 <KB1> <KB2> <CS>,
    // yani 8 baytlık normal bir standart frame — ayrı bir "fast-init yanıt"
    // formatı yok). Önceki kod burada olmayan özel bir "C1 EE F0 SID CS" (5
    // bayt) formatı varsayıyordu; bu hem regülasyonla hem STKC referans
    // firmware'iyle (Kline_Port.c::Send_KLINE_Package_Receive_Response, her
    // yanıtı tek tip 0x80 formatında bekliyor) çelişiyordu.

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
    if ((sid == KLineSid.rdbiResponse || sid == KLineSid.wdbiResponse) &&
        payload.length >= 3) {
      return KLineResponse(
        sid: sid,
        ridHigh: payload[1],
        ridLow: payload[2],
        data: payload.sublist(3),
      );
    }

    // RoutineControl pozitif — RID bytes çıkar
    if (sid == KLineSid.routineCtrlResponse && payload.length >= 4) {
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
