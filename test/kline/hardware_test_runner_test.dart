import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takograpp_d1/bluetooth/models/ble_gatt_service.dart';
import 'package:takograpp_d1/bluetooth/models/log_entry.dart';
import 'package:takograpp_d1/bluetooth/repositories/ble_connection_repository.dart';
import 'package:takograpp_d1/kline/hardware_test_runner.dart';
import 'package:takograpp_d1/kline/kline_records.dart';
import 'package:takograpp_d1/kline/kline_service.dart';
import 'package:takograpp_d1/models/hardware_test_report.dart';
import 'package:takograpp_d1/services/hardware_test_report_store.dart';

int _cs(List<int> bytes) => bytes.fold(0, (sum, b) => sum + b) & 0xFF;

List<int> _stdResp(int sid, List<int> data) {
  final payload = [sid, ...data];
  // Response addressing is SADDR/TADDR reversed vs. the request (F0 EE, not EE F0)
  // per CalibrationMessages.md / STKC ground truth — matters now that KLineService
  // strips self-echo by matching against the exact request bytes it just sent.
  final header = [0x80, 0xF0, 0xEE, payload.length];
  final frame = [...header, ...payload];
  return [...frame, _cs(frame)];
}

List<int> _negResp(int originalSid, int nrc) => _stdResp(0x7F, [originalSid, nrc]);

// Her yazma/okuma isteğini SID'e göre anında ve tutarlı biçimde otomatik
// yanıtlayan sahte transport. RDBI/WDBI çağrıları record ID başına bir
// değer haritasında saklanır — bu sayede writeParameter()'ın "yaz sonra
// geri oku, eşleşiyor mu?" doğrulaması gerçekçi şekilde çalışır (yazılan
// değer, sonraki okumada aynen geri döner).
class _AutoAckTransport implements BleConnectionRepository {
  final List<List<int>> writtenFrames = [];
  final Map<int, List<int>> recordValues = {};
  final Set<int> failRdbiRecordIds = {};
  final Set<int> failWdbiRecordIds = {};
  final Set<int> failRoutineStartIds = {};
  final _notifyController = StreamController<List<int>>.broadcast();
  final _stateController = StreamController<BleConnectionState>.broadcast();

  // KLineService now writes each frame one byte at a time (ISO 14230 P4min
  // pacing, see kline_service.dart::_write) instead of one bulk write per
  // frame. Reassemble the incoming bytes into full logical frames — mirroring
  // how a real K-LINE receiver buffers until it has a complete frame — before
  // deciding on a response, exactly like the production KLineFrameBuffer does.
  final List<int> _incoming = [];

  List<int>? _tryExtractFrame() {
    if (_incoming.isEmpty) return null;
    if (_incoming[0] == 0x00) {
      return [_incoming.removeAt(0)];
    }
    if (_incoming[0] == 0x81) {
      if (_incoming.length < 5) return null;
      final frame = _incoming.sublist(0, 5);
      _incoming.removeRange(0, 5);
      return frame;
    }
    if (_incoming[0] == 0x80) {
      if (_incoming.length < 4) return null;
      final total = 4 + _incoming[3] + 1;
      if (_incoming.length < total) return null;
      final frame = _incoming.sublist(0, total);
      _incoming.removeRange(0, total);
      return frame;
    }
    _incoming.removeAt(0); // unexpected leading byte — shouldn't happen in these tests
    return null;
  }

  @override
  Stream<BleConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<LogEntry> get logs => const Stream.empty();

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<BleGattService>> discoverServices() async => [];

  @override
  Future<List<int>> readCharacteristic(String charUuid) async => [];

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {}

  @override
  Stream<List<int>> notifyStream(String charUuid) => _notifyController.stream;

  @override
  Future<void> dispose() async {
    await _notifyController.close();
    await _stateController.close();
  }

  @override
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    _incoming.addAll(data);
    final frame = _tryExtractFrame();
    if (frame == null) return;
    writtenFrames.add(frame);
    final resp = _respond(frame);
    if (resp != null) {
      // Per-byte pacing (ISO 14230 P4min, see KLineService._write) spreads
      // each request across several real event-loop turns now, so a response
      // scheduled for a frame that completes right as the test winds down can
      // fire after tearDown() has already closed the controller — guard it.
      scheduleMicrotask(() {
        if (!_notifyController.isClosed) _notifyController.add(resp);
      });
    }
  }

  List<int>? _respond(List<int> frame) {
    if (frame.isEmpty) return null;
    if (frame[0] == 0x00) return null; // wakeup — yanıt beklenmez
    if (frame[0] == 0x81) {
      // StartCommunication Positive Response — Regulation (EU) 2016/799,
      // Annex 1C App.8, Table 6: 80 <tt> EE 03 C1 <KB1=EA> <KB2=8F> <CS>.
      // It's a normal standard-format frame, not a distinct 5-byte format.
      return _stdResp(0xC1, const [0xEA, 0x8F]);
    }
    if (frame[0] != 0x80 || frame.length < 5) return null;

    final sid = frame[4];
    final payload = frame.sublist(4, frame.length - 1); // [sid, ...body]
    final body = payload.sublist(1);

    switch (sid) {
      case 0x82: // StopCommunication
        return _stdResp(0xC2, const []);
      case 0x10: // StartDiagnosticSession
        return _stdResp(0x50, [body[0]]);
      case 0x3E: // TesterPresent (no-response varyantı) — gerçek cihaz da yanıt vermez
        return null;
      case 0x22: // RDBI
        {
          final recordId = (body[0] << 8) | body[1];
          if (failRdbiRecordIds.contains(recordId)) {
            return _negResp(0x22, KLineNrc.conditionsNotCorrect);
          }
          final value = recordValues.putIfAbsent(recordId, () => const [0x01, 0x02]);
          return _stdResp(0x62, [body[0], body[1], ...value]);
        }
      case 0x2E: // WDBI
        {
          final recordId = (body[0] << 8) | body[1];
          if (failWdbiRecordIds.contains(recordId)) {
            return _negResp(0x2E, KLineNrc.conditionsNotCorrect);
          }
          recordValues[recordId] = body.sublist(2);
          return _stdResp(0x6E, [body[0], body[1]]);
        }
      case 0x31: // RoutineControl
        {
          final select = body[0];
          final routineId = (body[1] << 8) | body[2];
          if (select == KLineRoutineSelect.startRoutine && failRoutineStartIds.contains(routineId)) {
            return _negResp(0x31, KLineNrc.conditionsNotCorrect);
          }
          // requestRoutineResults (select==0x03) için "tamamlandı" anlamına gelen
          // dolu bir sonuç baytı döndür — pollRoutineCompletion() ilk denemede döner.
          final extra = select == KLineRoutineSelect.requestRoutineResults ? const [0x01] : const <int>[];
          return _stdResp(0x71, [select, body[1], body[2], ...extra]);
        }
      case 0x19: // ReadDtcInfo
        {
          final subFn = body[0];
          if (subFn == 0x01) return _stdResp(0x59, const [0x00, 0x00]); // count = 0
          return _stdResp(0x59, const []); // codes: yok
        }
      default:
        return null;
    }
  }
}

Future<HardwareTestReport> _runFull(
  KLineService service, {
  required bool pinAuthenticated,
  bool isStc8255 = false,
}) async {
  final runner = HardwareTestRunner(service);
  late HardwareTestReport report;
  await for (final p in runner.run(pinAuthenticated: pinAuthenticated, isStc8255: isStc8255)) {
    if (p.isDone) report = p.finalReport!;
  }
  return report;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HardwareTestRunner', () {
    test(
      'happy path: full sweep completes, K-Constant coupled to W-Constant, '
      'visual-confirm never reports pass, DTC clear never sent',
      () async {
        final transport = _AutoAckTransport();
        final service = KLineService(transport);
        addTearDown(transport.dispose);

        final report = await _runFull(service, pinAuthenticated: true);

        // Toplam adım sayısı: 30 okuma + 26 yaz-doğrula + 10 opsiyonel ayar (STC8250) + 2 DTC + 10 bileşen testi
        expect(report.items.length, 78);

        final wItem = report.items.firstWhere((i) => i.id == 'write_w_constant');
        expect(wItem.status, HwTestStatus.pass);

        final kItem = report.items.firstWhere((i) => i.id == 'write_k_constant');
        expect(kItem.status, HwTestStatus.skipped);
        expect(kItem.detail, contains('W-Sabiti'));

        final visualItems = report.items.where((i) => i.category == HwTestItemCategory.componentVisualConfirm);
        expect(visualItems, isNotEmpty);
        expect(visualItems.every((i) => i.status == HwTestStatus.visualConfirmRequired), isTrue);

        final autoItems = report.items.where((i) => i.category == HwTestItemCategory.componentAutoResult);
        expect(autoItems, isNotEmpty);
        expect(autoItems.every((i) => i.status == HwTestStatus.commsOkResultUnverified), isTrue);

        // clearDiagnosticInformation (SID 0x14) hiçbir zaman gönderilmemeli.
        final sentSids = transport.writtenFrames.where((f) => f.length >= 5 && f[0] == 0x80).map((f) => f[4]);
        expect(sentSids.contains(0x14), isFalse);

        // Rapor kalıcılığı — SharedPreferences round-trip.
        final stored = await HardwareTestReportStore.loadAll();
        expect(stored.any((r) => r.id == report.id), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'when PIN is not authenticated, every write-verify item is skipped',
      () async {
        final transport = _AutoAckTransport();
        final service = KLineService(transport);
        addTearDown(transport.dispose);

        final report = await _runFull(service, pinAuthenticated: false);

        final writeItems = report.items.where((i) => i.category == HwTestItemCategory.calParamWriteVerify);
        expect(writeItems, isNotEmpty);
        expect(writeItems.every((i) => i.status == HwTestStatus.skipped), isTrue);
        // K-Constant, W-Constant'a bağlı olduğu için kendi mesajında "PIN" yerine
        // W-Constant'ın atlandığını açıklar — diğer tüm parametreler PIN eksikliğini belirtir.
        final withoutKConstant = writeItems.where((i) => i.id != 'write_k_constant');
        expect(withoutKConstant.every((i) => i.detail.contains('PIN')), isTrue);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'a single failing RDBI mid-sweep does not abort the rest of the sweep',
      () async {
        final transport = _AutoAckTransport()..failRdbiRecordIds.add(KLineRecords.odometer);
        final service = KLineService(transport);
        addTearDown(transport.dispose);

        final report = await _runFull(service, pinAuthenticated: true);

        // Sweep tamamlandı, adım sayısı etkilenmedi.
        expect(report.items.length, 78);

        final odoRead = report.items.firstWhere((i) => i.id == 'read_odometer');
        expect(odoRead.status, HwTestStatus.fail);

        // Okunamayan değer için yazma testi de "değer bilinmiyor" diye atlanmalı.
        final odoWrite = report.items.firstWhere((i) => i.id == 'write_odometer');
        expect(odoWrite.status, HwTestStatus.skipped);

        // Diğer parametreler etkilenmeden geçmeye devam etmeli.
        final vinRead = report.items.firstWhere((i) => i.id == 'read_vin');
        expect(vinRead.status, HwTestStatus.pass);
        final vinWrite = report.items.firstWhere((i) => i.id == 'write_vin');
        expect(vinWrite.status, HwTestStatus.pass);
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
