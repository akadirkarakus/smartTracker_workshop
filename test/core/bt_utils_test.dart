import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/core/bt_utils.dart';

void main() {
  group('bytesToHex', () {
    test('formats bytes as space-separated uppercase hex with ASCII suffix', () {
      expect(bytesToHex([0x41, 0x42]), '41 42 ("AB")');
    });

    test('omits the ASCII suffix when no printable bytes are present', () {
      expect(bytesToHex([0x00, 0x01]), '00 01');
    });
  });

  group('isSecurityAccessSendKeyFrame', () {
    test('recognizes a well-formed SendKey frame', () {
      // 80 EE F0 06 27 7E 31 32 33 34 <CS> — SID 0x27, sub-fn 0x7E (SendKey), PIN "1234"
      const frame = [0x80, 0xEE, 0xF0, 0x06, 0x27, 0x7E, 0x31, 0x32, 0x33, 0x34, 0x00];
      expect(isSecurityAccessSendKeyFrame(frame), isTrue);
    });

    test('rejects a RequestSeed frame (same SID, different sub-function)', () {
      const frame = [0x80, 0xEE, 0xF0, 0x02, 0x27, 0x7D, 0x00];
      expect(isSecurityAccessSendKeyFrame(frame), isFalse);
    });

    test('rejects an unrelated frame (e.g. WDBI)', () {
      const frame = [0x80, 0xEE, 0xF0, 0x05, 0x2E, 0xF9, 0x18, 0x01, 0x02, 0x00];
      expect(isSecurityAccessSendKeyFrame(frame), isFalse);
    });

    test('rejects frames too short to contain a sub-function byte', () {
      expect(isSecurityAccessSendKeyFrame([0x80, 0xEE, 0xF0, 0x00, 0x27]), isFalse);
    });
  });

  group('bytesToHexRedacted', () {
    test('redacts the PIN payload of a SendKey frame', () {
      const frame = [0x80, 0xEE, 0xF0, 0x06, 0x27, 0x7E, 0x31, 0x32, 0x33, 0x34, 0x00];
      final result = bytesToHexRedacted(frame);
      expect(result, isNot(contains('31 32 33 34')));
      expect(result, isNot(contains('"1234"')));
      expect(result, contains('80 EE F0 06 27 7E'));
      expect(result, contains('PIN REDACTED'));
    });

    test('leaves non-SendKey frames unchanged (identical to bytesToHex)', () {
      const frame = [0x80, 0xEE, 0xF0, 0x05, 0x2E, 0xF9, 0x18, 0x01, 0x02, 0x00];
      expect(bytesToHexRedacted(frame), bytesToHex(frame));
    });
  });
}
