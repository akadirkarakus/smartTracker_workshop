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
      // 0xAA standart formata (0x80) uymuyor.
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

  group('KLineFrameBuffer.expectEcho', () {
    test('a full echo of the last-sent frame is silently discarded, real response still parses', () {
      final buffer = KLineFrameBuffer();
      final sent = [0x81, 0xEE, 0xF0, 0x81, 0xE0]; // StartCommunication
      // StartCommunication Positive Response — Regulation (EU) 2016/799,
      // Annex 1C App.8, Table 6: 80 F0 EE 03 C1 EA 8F CS.
      final response = _buildStandardResponse(sid: 0xC1, data: const [0xEA, 0x8F]);

      buffer.expectEcho(sent);
      buffer.add(sent); // K-LINE half-duplex echo of our own transmission
      buffer.add(response);

      // Echo must not have produced a parseable (or garbage) frame on its own.
      final resp = buffer.tryParse();
      expect(resp, isNotNull);
      expect(resp!.sid, 0xC1);
    });

    test('echo split across multiple add() calls is still fully suppressed', () {
      final buffer = KLineFrameBuffer();
      final sent = [0x81, 0xEE, 0xF0, 0x81, 0xE0];
      // StartCommunication Positive Response — Regulation (EU) 2016/799,
      // Annex 1C App.8, Table 6: 80 F0 EE 03 C1 EA 8F CS.
      final response = _buildStandardResponse(sid: 0xC1, data: const [0xEA, 0x8F]);

      buffer.expectEcho(sent);
      for (final byte in sent) {
        buffer.add([byte]); // one byte per Bluetooth notify, worst case
      }
      buffer.add(response);

      final resp = buffer.tryParse();
      expect(resp, isNotNull);
      expect(resp!.sid, 0xC1);
    });

    test('bytes that only partially match the expected echo fall through to normal parsing', () {
      final buffer = KLineFrameBuffer();
      buffer.expectEcho([0x81, 0xEE, 0xF0, 0x81, 0xE0]);

      // Diverges after 2 matching bytes — not an echo, must not be swallowed.
      buffer.add(_buildStandardResponse(sid: 0x50, data: [0x81]));

      final resp = buffer.tryParse();
      expect(resp, isNotNull);
      expect(resp!.sid, 0x50);
    });

    test(
      'a genuine response sharing a leading byte with the request (both FMT=0x80) '
      'is not corrupted — the tentatively-matched prefix is restored, not dropped',
      () {
        final buffer = KLineFrameBuffer();
        // Request: 80 EE F0 03 22 F1 90 CS (RDBI). Response starts 80 F0 EE...
        // — byte[0] coincidentally matches the request's FMT byte.
        buffer.expectEcho([0x80, 0xEE, 0xF0, 0x03, 0x22, 0xF1, 0x90, 0x00]);
        buffer.add(_buildStandardResponse(sid: 0x62, data: [0xF1, 0x90, 0x41, 0x42]));

        final resp = buffer.tryParse();
        expect(resp, isNotNull);
        expect(resp!.sid, 0x62);
        expect(resp.recordId, 0xF190);
        expect(resp.data, [0x41, 0x42]);
      },
    );

    test('without expectEcho(), incoming bytes are handled exactly as before (no regression)', () {
      final buffer = KLineFrameBuffer();
      buffer.add(_buildStandardResponse(sid: 0x50, data: [0x81]));

      final resp = buffer.tryParse();
      expect(resp, isNotNull);
      expect(resp!.sid, 0x50);
    });
  });
}
