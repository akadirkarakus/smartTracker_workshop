import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/kline/kline_frame.dart';

// Standart yanıt frame'i oluşturur: 80 F0 EE LEN SID DATA... CS
List<int> _buildStandardResponse({required int sid, required List<int> data}) {
  final payload = [sid, ...data];
  final header = [0x80, 0xF0, 0xEE, payload.length];
  final frame = [...header, ...payload];
  final cs = frame.fold(0, (sum, b) => sum + b) & 0xFF;
  return [...frame, cs];
}

void main() {
  group('KLineFrameBuffer.tryParse', () {
    test('parses a valid standard response frame', () {
      final buffer = KLineFrameBuffer();
      buffer.add(_buildStandardResponse(sid: 0x50, data: [0x81]));

      final resp = buffer.tryParse();

      expect(resp, isNotNull);
      expect(resp!.sid, 0x50);
      expect(resp.data, [0x81]);
      expect(resp.isNegative, false);
    });

    test('parses a negative response frame with its NRC', () {
      final buffer = KLineFrameBuffer();
      // 7F <originalSID=0x27> <NRC=0x35 invalidKey>
      buffer.add(_buildStandardResponse(sid: 0x7F, data: [0x27, 0x35]));

      final resp = buffer.tryParse()!;

      expect(resp.isNegative, true);
      expect(resp.sid, 0x27);
      expect(resp.nrc, 0x35);
    });

    test('parses an RDBI response and extracts the record ID', () {
      final buffer = KLineFrameBuffer();
      buffer.add(_buildStandardResponse(sid: 0x62, data: [0xF1, 0x90, 0x41, 0x42]));

      final resp = buffer.tryParse()!;

      expect(resp.recordId, 0xF190);
      expect(resp.data, [0x41, 0x42]);
    });

    test('waits for more bytes when the frame is not yet complete', () {
      final buffer = KLineFrameBuffer();
      final frame = _buildStandardResponse(sid: 0x50, data: [0x81]);
      buffer.add(frame.sublist(0, frame.length - 2));

      expect(buffer.tryParse(), isNull);

      buffer.add(frame.sublist(frame.length - 2));
      final resp = buffer.tryParse();
      expect(resp, isNotNull);
      expect(resp!.sid, 0x50);
    });

    test('checksum error drops one byte and resyncs on the next valid frame', () {
      final buffer = KLineFrameBuffer();
      final good = _buildStandardResponse(sid: 0x50, data: [0x81]);
      final corrupted = [...good];
      corrupted[corrupted.length - 1] ^= 0xFF; // checksum baytını boz

      buffer.add(corrupted);
      buffer.add(good);

      KLineResponse? recovered;
      for (var i = 0; i < corrupted.length + good.length; i++) {
        recovered = buffer.tryParse();
        if (recovered != null) break;
      }

      expect(recovered, isNotNull);
      expect(recovered!.sid, 0x50);
      expect(recovered.data, [0x81]);
    });

    test('unrecognized format bytes are skipped one at a time until resync', () {
      final buffer = KLineFrameBuffer();
      // 0xAA ne standart (0x80) ne fast-init yanıt (0xC1) formatına uyuyor.
      buffer.add(List<int>.filled(20, 0xAA));
      buffer.add(_buildStandardResponse(sid: 0x50, data: [0x81]));

      KLineResponse? resp;
      for (var i = 0; i < 40; i++) {
        resp = buffer.tryParse();
        if (resp != null) break;
      }

      expect(resp, isNotNull);
      expect(resp!.sid, 0x50);
    });

    test(
      'buffer growth is capped — a valid frame appended after a large '
      'garbage burst is still eventually parsed',
      () {
        final buffer = KLineFrameBuffer();
        // Kapasitenin (512) çok üzerinde bir gürültü patlaması ekle.
        buffer.add(List<int>.filled(1000, 0xAA));
        buffer.add(_buildStandardResponse(sid: 0x50, data: [0x81]));

        KLineResponse? resp;
        for (var i = 0; i < 2000 && resp == null; i++) {
          resp = buffer.tryParse();
        }

        expect(resp, isNotNull);
        expect(resp!.sid, 0x50);
        expect(resp.data, [0x81]);
      },
    );
  });
}
