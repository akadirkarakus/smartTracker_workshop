import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/bluetooth/models/ble_gatt_service.dart';
import 'package:takograpp_d1/bluetooth/models/log_entry.dart';
import 'package:takograpp_d1/bluetooth/repositories/ble_connection_repository.dart';
import 'package:takograpp_d1/kline/kline_records.dart';
import 'package:takograpp_d1/kline/kline_service.dart';

// 80 F0 EE LEN SID DATA... CS
List<int> _standardResponse({required int sid, List<int> data = const []}) {
  final payload = [sid, ...data];
  // Response addressing is SADDR/TADDR reversed vs. the request (F0 EE, not EE F0)
  // per Regulation (EU) 2016/799, Annex 1C App.8 (Tables 6/8) — matters now that
  // KLineService strips self-echo by matching against the exact request bytes it
  // just sent.
  final header = [0x80, 0xF0, 0xEE, payload.length];
  final frame = [...header, ...payload];
  final cs = frame.fold(0, (sum, b) => sum + b) & 0xFF;
  return [...frame, cs];
}

// StartCommunication Positive Response — Regulation (EU) 2016/799, Annex 1C
// App.8, Table 6: 80 <tt> EE 03 C1 <KB1=EA> <KB2=8F> <CS>. It's a normal
// standard-format frame (not a distinct "fast-init response" format).
List<int> _fastInitResponse() =>
    _standardResponse(sid: 0xC1, data: const [0xEA, 0x8F]);

List<int> _negativeResponse({required int originalSid, required int nrc}) =>
    _standardResponse(sid: KLineSid.negativeResp, data: [originalSid, nrc]);

/// In-memory [BleConnectionRepository] fake. Each call to
/// [writeCharacteristic] pops the next queued response (if any) and pushes
/// it onto the notify stream, letting KLineService's request/response
/// transactions be driven deterministically without real hardware.
class _FakeKLineTransport implements BleConnectionRepository {
  final List<List<int>> responseQueue = [];
  final List<List<int>> writtenFrames = [];
  final _notifyController = StreamController<List<int>>.broadcast();
  final _stateController = StreamController<BleConnectionState>.broadcast();

  // KLineService now writes each frame one byte at a time (ISO 14230 P4min
  // pacing, see kline_service.dart::_write). Reassemble into full logical
  // frames — mirroring a real K-LINE receiver — before popping a queued
  // response, so writtenFrames/responseQueue keep meaning "one entry per
  // request", not "one entry per byte".
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
  Future<void> writeCharacteristic(String charUuid, List<int> data) async {
    _incoming.addAll(data);
    final frame = _tryExtractFrame();
    if (frame == null) return;
    writtenFrames.add(frame);
    if (responseQueue.isNotEmpty) {
      final resp = responseQueue.removeAt(0);
      // Let KLineService reach its _waitResponse poll loop before delivering.
      // Per-byte pacing (ISO 14230 P4min, see KLineService._write) spreads
      // each request across several real event-loop turns, so a response for
      // a frame completed right as the test winds down can fire after
      // tearDown() has already closed the controller — guard it.
      scheduleMicrotask(() {
        if (!_notifyController.isClosed) _notifyController.add(resp);
      });
    }
  }

  @override
  Future<void> setNotify(String charUuid, {required bool enable}) async {}

  @override
  Stream<List<int>> notifyStream(String charUuid) => _notifyController.stream;

  @override
  Future<void> dispose() async {
    await _notifyController.close();
    await _stateController.close();
  }
}

void main() {
  group('KLineService routine tests — real NRC checking (K4)', () {
    late _FakeKLineTransport transport;
    late KLineService service;

    setUp(() {
      transport = _FakeKLineTransport();
      service = KLineService(transport);
    });

    tearDown(() => transport.dispose());

    test('startRoutineTest completes normally on a positive response', () async {
      transport.responseQueue.addAll([
        <int>[], // wakeup() — no response awaited, placeholder to keep the queue aligned
        _fastInitResponse(), // StartCommunication ack
        _standardResponse(sid: 0x50, data: [0x87]), // StartDiagnosticSession ack
        _standardResponse(sid: KLineSid.routineCtrlResponse, data: [0x01, 0x00, 0x50]), // RoutineControl(start) ack
      ]);

      await expectLater(service.startRoutineTest(KLineRoutineIds.displayTest), completes);
    });

    test('startRoutineTest throws KLineException when the device NAKs the routine', () async {
      transport.responseQueue.addAll([
        <int>[], // wakeup() — no response awaited, placeholder to keep the queue aligned
        _fastInitResponse(), // StartCommunication ack
        _standardResponse(sid: 0x50, data: [0x87]), // StartDiagnosticSession ack
        _negativeResponse(originalSid: KLineSid.routineCtrl, nrc: KLineNrc.conditionsNotCorrect),
      ]);

      await expectLater(
        service.startRoutineTest(KLineRoutineIds.displayTest),
        throwsA(isA<KLineException>().having((e) => e.nrc, 'nrc', KLineNrc.conditionsNotCorrect)),
      );
    });

    test('stopRoutineTest throws KLineException on a negative response but still runs cleanup', () async {
      transport.responseQueue.addAll([
        _negativeResponse(originalSid: KLineSid.routineCtrl, nrc: KLineNrc.conditionsNotCorrect), // RoutineControl(stop) NAK
        _standardResponse(sid: 0x50, data: [0x81]), // StartDiagnosticSession(standard) ack
        _standardResponse(sid: 0xC2), // StopCommunication ack
      ]);

      await expectLater(
        service.stopRoutineTest(KLineRoutineIds.displayTest),
        throwsA(isA<KLineException>()),
      );

      // Cleanup (session restore + StopCommunication) must still have been sent.
      expect(transport.writtenFrames.length, 3);
    });

    test('stopRoutineTest completes normally on a positive response', () async {
      transport.responseQueue.addAll([
        _standardResponse(sid: KLineSid.routineCtrlResponse, data: [0x02, 0x00, 0x50]), // RoutineControl(stop) ack
        _standardResponse(sid: 0x50, data: [0x81]), // StartDiagnosticSession(standard) ack
        _standardResponse(sid: 0xC2), // StopCommunication ack
      ]);

      await expectLater(service.stopRoutineTest(KLineRoutineIds.displayTest), completes);
    });

    test(
      'stopRoutineTest throws KLineTimeoutException (not a plain NRC-carrying '
      'KLineException) when no response ever arrives — CalibrationMessages.md '
      'documents no RX for Flow 15/18-21 stopRoutine, so callers must be able '
      'to tell "no response" apart from a genuine device rejection',
      () async {
        // responseQueue boş bırakılıyor — device hiç yanıt vermeyecek, sadece
        // varsayılan 5 sn zaman aşımı gerçekleşecek.
        await expectLater(
          service.stopRoutineTest(KLineRoutineIds.batteryLevel),
          throwsA(isA<KLineTimeoutException>()),
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('KLineService.pairMotionSensor — NRC checking (O11)', () {
    late _FakeKLineTransport transport;
    late KLineService service;

    setUp(() {
      transport = _FakeKLineTransport();
      service = KLineService(transport);
    });

    tearDown(() => transport.dispose());

    test('yields routineNotSupported when the device NAKs startRoutine, without polling', () async {
      transport.responseQueue.addAll([
        <int>[], // wakeup() — no response awaited, placeholder to keep the queue aligned
        _fastInitResponse(), // StartCommunication ack
        _standardResponse(sid: 0x50, data: [0x87]), // StartDiagnosticSession(adjustment) ack
        _negativeResponse(originalSid: KLineSid.routineCtrl, nrc: KLineNrc.requestOutOfRange), // RoutineControl(start) NAK
        _standardResponse(sid: 0x50, data: [0x81]), // StartDiagnosticSession(standard) ack — cleanup
        _standardResponse(sid: 0xC2), // StopCommunication ack — cleanup
      ]);

      final statuses = await service.pairMotionSensor(KLineRoutineIds.motionSensorPairing).toList();

      expect(statuses, [MsPairingStatus.routineNotSupported]);
    });
  });
}
