import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/kline/kline_codec.dart';

void main() {
  group('VIN (0xF190)', () {
    test('round-trips a 17-character VIN', () {
      const vin = 'WVWZZZ1KZAW123456';
      final encoded = KLineCodec.encodeVin(vin);
      expect(encoded.length, 17);
      expect(KLineCodec.decodeVin(encoded), vin);
    });

    test('short VIN is space-padded and decode keeps the trailing spaces', () {
      final encoded = KLineCodec.encodeVin('ABC');
      expect(encoded.length, 17);
      expect(KLineCodec.decodeVin(encoded), 'ABC${' ' * 14}');
    });

    test('over-length VIN is silently truncated to 17 chars on encode', () {
      final encoded = KLineCodec.encodeVin('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(encoded.length, 17);
      expect(KLineCodec.decodeVin(encoded), 'ABCDEFGHIJKLMNOPQ');
    });

    test('decode returns null for short byte input', () {
      expect(KLineCodec.decodeVin(List.filled(16, 0x20)), isNull);
    });
  });

  group('VRN (0xF97E)', () {
    test('round-trips a VRN (leading marker space trimmed on decode)', () {
      const vrn = '34ABC123';
      final encoded = KLineCodec.encodeVrn(vrn);
      expect(encoded.length, 14);
      expect(KLineCodec.decodeVrn(encoded), vrn);
    });

    test('lowercase input is normalized to uppercase', () {
      final encoded = KLineCodec.encodeVrn('34abc123');
      expect(KLineCodec.decodeVrn(encoded), '34ABC123');
    });

    test('over-length VRN is silently truncated', () {
      // leading space + 13 chars fits; 14th char of the plate is dropped.
      final encoded = KLineCodec.encodeVrn('ABCDEFGHIJKLMN');
      expect(encoded.length, 14);
      expect(KLineCodec.decodeVrn(encoded), 'ABCDEFGHIJKLM');
    });

    test('decode returns null for short byte input', () {
      expect(KLineCodec.decodeVrn(List.filled(13, 0x20)), isNull);
    });
  });

  group('Tyre Size (0xF921)', () {
    test('round-trips and trims padding', () {
      const size = '295/80R22.5';
      final encoded = KLineCodec.encodeTyreSize(size);
      expect(encoded.length, 15);
      expect(KLineCodec.decodeTyreSize(encoded), size);
    });
  });

  group('Member State (0xF97D)', () {
    test('round-trips a 3-letter code', () {
      final encoded = KLineCodec.encodeMemberState('tr');
      expect(KLineCodec.decodeMemberState(encoded), 'TR');
    });
  });

  group('numeric fields with clamp', () {
    test('PPROOS clamps to 0..64255', () {
      expect(KLineCodec.decodePproos(KLineCodec.encodePproos(1000)), 1000);
      expect(KLineCodec.decodePproos(KLineCodec.encodePproos(-5)), 0);
      expect(KLineCodec.decodePproos(KLineCodec.encodePproos(70000)), 64255);
    });

    test('Teeth Count clamps to 0..250', () {
      expect(KLineCodec.decodeTeethCount(KLineCodec.encodeTeethCount(120)), 120);
      expect(KLineCodec.decodeTeethCount(KLineCodec.encodeTeethCount(-1)), 0);
      expect(KLineCodec.decodeTeethCount(KLineCodec.encodeTeethCount(300)), 250);
    });

    test('Prewarning Days clamps to 0..250', () {
      expect(
        KLineCodec.decodePrewarningDays(KLineCodec.encodePrewarningDays(30)),
        30,
      );
      expect(
        KLineCodec.decodePrewarningDays(KLineCodec.encodePrewarningDays(-1)),
        0,
      );
      expect(
        KLineCodec.decodePrewarningDays(KLineCodec.encodePrewarningDays(500)),
        250,
      );
    });

    test('Tco1 Priority clamps to 0..7', () {
      expect(
        KLineCodec.decodeTco1Priority(KLineCodec.encodeTco1Priority(3)),
        3,
      );
      expect(
        KLineCodec.decodeTco1Priority(KLineCodec.encodeTco1Priority(-1)),
        0,
      );
      expect(
        KLineCodec.decodeTco1Priority(KLineCodec.encodeTco1Priority(9)),
        7,
      );
    });

    test('Speedometer Factor clamps to 1..60000', () {
      expect(
        KLineCodec.decodeSpeedometerFactor(
          KLineCodec.encodeSpeedometerFactor(8000),
        ),
        8000,
      );
      expect(
        KLineCodec.decodeSpeedometerFactor(
          KLineCodec.encodeSpeedometerFactor(0),
        ),
        1,
      );
      expect(
        KLineCodec.decodeSpeedometerFactor(
          KLineCodec.encodeSpeedometerFactor(70000),
        ),
        60000,
      );
    });

    test('Overspeed Prewarning Seconds clamps to 0..60', () {
      expect(
        KLineCodec.decodeOverspeedPrewarningSeconds(
          KLineCodec.encodeOverspeedPrewarningSeconds(30),
        ),
        30,
      );
      expect(
        KLineCodec.decodeOverspeedPrewarningSeconds(
          KLineCodec.encodeOverspeedPrewarningSeconds(-1),
        ),
        0,
      );
      expect(
        KLineCodec.decodeOverspeedPrewarningSeconds(
          KLineCodec.encodeOverspeedPrewarningSeconds(90),
        ),
        60,
      );
    });
  });

  group('numeric fields without clamp (documented silent-truncation risk)', () {
    test('Odometer round-trips within uint32 range', () {
      expect(
        KLineCodec.decodeOdometer(KLineCodec.encodeOdometer(123456)),
        123456,
      );
      expect(
        KLineCodec.decodeOdometer(KLineCodec.encodeOdometer(0xFFFFFFFF)),
        0xFFFFFFFF,
      );
    });

    test('Odometer beyond uint32 silently wraps instead of clamping', () {
      final encoded = KLineCodec.encodeOdometer(0x100000005);
      expect(KLineCodec.decodeOdometer(encoded), 5);
    });

    test('K-Constant / W-Constant round-trip within uint16 range', () {
      expect(
        KLineCodec.decodeKConstant(KLineCodec.encodeKConstant(12000)),
        12000,
      );
      expect(
        KLineCodec.decodeWConstant(KLineCodec.encodeWConstant(12000)),
        12000,
      );
    });

    test('K-Constant beyond uint16 silently wraps instead of clamping', () {
      final encoded = KLineCodec.encodeKConstant(0x10005);
      expect(KLineCodec.decodeKConstant(encoded), 5);
    });

    test('Trip Distance round-trips within uint32 range', () {
      expect(
        KLineCodec.decodeTripDistance(KLineCodec.encodeTripDistance(500)),
        500,
      );
    });

    test('Speed Limit round-trips a typical value', () {
      expect(KLineCodec.decodeSpeedLimit(KLineCodec.encodeSpeedLimit(90)), 90);
    });

    test('Download Period is not byte-masked at the codec level', () {
      // The codec keeps the raw int in the List<int>; only a real byte
      // transport (Uint8List) would truncate it to 8 bits mod 256.
      final encoded = KLineCodec.encodeDownloadPeriod(300);
      expect(KLineCodec.decodeDownloadPeriod(encoded), 300);
      final asRealBytes = Uint8List.fromList(encoded);
      expect(KLineCodec.decodeDownloadPeriod(asRealBytes), 300 % 256);
    });
  });

  group('Tyre Circumference (0xF91C, value x8)', () {
    test('round-trips a typical circumference', () {
      expect(
        KLineCodec.decodeTyreCircumference(
          KLineCodec.encodeTyreCircumference(628),
        ),
        628,
      );
    });

    test('mm beyond 8191 silently wraps (mm*8 overflows uint16)', () {
      final encoded = KLineCodec.encodeTyreCircumference(8192);
      expect(KLineCodec.decodeTyreCircumference(encoded), 0);
    });
  });

  group('UTC Offset (0xF90D / 0xF90E)', () {
    test('round-trips a positive offset (+180 min / UTC+3)', () {
      final encoded = KLineCodec.encodeUtcOffset(180);
      expect(
        KLineCodec.decodeUtcOffset([encoded[0]], [encoded[1]]),
        180,
      );
    });

    test('round-trips a negative offset (-60 min / UTC-1)', () {
      final encoded = KLineCodec.encodeUtcOffset(-60);
      expect(
        KLineCodec.decodeUtcOffset([encoded[0]], [encoded[1]]),
        -60,
      );
    });

    test('decode returns null for empty byte input', () {
      expect(KLineCodec.decodeUtcOffset([], [0x8C]), isNull);
      expect(KLineCodec.decodeUtcOffset([0x7D], []), isNull);
    });
  });

  group('dates — valid round-trips', () {
    test('Next Calibration Date round-trips', () {
      final date = DateTime(2026, 7, 13);
      final encoded = KLineCodec.encodeNextCalDate(date);
      expect(KLineCodec.decodeNextCalDate(encoded), date);
    });

    test('DateTime round-trips date and time (UTC offset bytes ignored on decode)', () {
      final dt = DateTime(2026, 7, 13, 14, 32);
      final encoded = KLineCodec.encodeDateTime(dt, 0, 0);
      expect(encoded.length, 8);
      expect(KLineCodec.decodeDateTime(encoded), dt);
    });

    test('ECU Install Date (BCD) round-trips', () {
      final date = DateTime(2024, 2, 29); // leap year, valid
      final encoded = KLineCodec.encodeEcuInstallDate(date);
      expect(KLineCodec.decodeEcuInstallDate(encoded), date);
    });

    test('Vehicle Registration Date round-trips', () {
      final date = DateTime(2026, 4, 30); // last valid day of April
      final encoded = KLineCodec.encodeVehicleRegDate(date);
      expect(KLineCodec.decodeVehicleRegDate(encoded), date);
    });
  });

  group('dates — _validDate now rejects impossible day/month combinations', () {
    test('31 April is rejected (April has only 30 days)', () {
      // day byte for day=31 is 4*(31-1)+2 = 122
      final bytes = [0x00, 0, 0, 4, 122, 26, 0x7D, 0x7D];
      expect(KLineCodec.decodeDateTime(bytes), isNull);
    });

    test('30 February is rejected in a non-leap year', () {
      // _bcd(25)=0x25, _bcd(2)=0x02, _bcd(30)=0x30
      expect(
        KLineCodec.decodeEcuInstallDate([0x25, 0x02, 0x30]),
        isNull,
      );
    });

    test('29 February is rejected in a non-leap year (2025)', () {
      expect(
        KLineCodec.decodeEcuInstallDate([0x25, 0x02, 0x29]),
        isNull,
      );
    });

    test('29 February is accepted in a leap year (2024)', () {
      expect(
        KLineCodec.decodeEcuInstallDate([0x24, 0x02, 0x29]),
        DateTime(2024, 2, 29),
      );
    });

    test('31 April is rejected for Vehicle Registration Date too', () {
      final bytes = [0x00, 0x00, 0x00, 4, 122, 26, 0x7D, 0x7D];
      expect(KLineCodec.decodeVehicleRegDate(bytes), isNull);
    });
  });

  group('bool fields', () {
    test('Heartbeat round-trips and only treats 0x01 as true', () {
      expect(
        KLineCodec.decodeHeartbeat(KLineCodec.encodeHeartbeat(true)),
        true,
      );
      expect(
        KLineCodec.decodeHeartbeat(KLineCodec.encodeHeartbeat(false)),
        false,
      );
      expect(KLineCodec.decodeHeartbeat([0x02]), false);
    });

    test('Tco1 Repetition Rate round-trips and only treats 0x01 as true', () {
      expect(
        KLineCodec.decodeTco1RepRate(KLineCodec.encodeTco1RepRate(true)),
        true,
      );
      expect(KLineCodec.decodeTco1RepRate([0x02]), false);
    });

    test('Enabled Byte round-trips and only treats 0x01 as true', () {
      expect(
        KLineCodec.decodeEnabledByte(KLineCodec.encodeEnabledByte(true)),
        true,
      );
      expect(KLineCodec.decodeEnabledByte([0x02]), false);
    });

    test(
      'Military Dimmer round-trips but treats ANY non-zero byte as true '
      '(inconsistent with Heartbeat/EnabledByte, which require exactly 0x01)',
      () {
        expect(
          KLineCodec.decodeMilitaryDimmer(KLineCodec.encodeMilitaryDimmer(true)),
          true,
        );
        expect(KLineCodec.decodeMilitaryDimmer([0x02]), true);
      },
    );

    test(
      'Card Existence Warning also treats ANY non-zero byte as true',
      () {
        expect(
          KLineCodec.decodeCardExistenceWarning(
            KLineCodec.encodeCardExistenceWarning(true),
          ),
          true,
        );
        expect(KLineCodec.decodeCardExistenceWarning([0x02]), true);
      },
    );
  });

  group('enum/string fields', () {
    test('Ignition Option round-trips known values', () {
      expect(
        KLineCodec.decodeIgnitionOption(
          KLineCodec.encodeIgnitionOption('Ko-Pilot'),
        ),
        'Ko-Pilot',
      );
      expect(
        KLineCodec.decodeIgnitionOption(
          KLineCodec.encodeIgnitionOption('Sürücü'),
        ),
        'Sürücü',
      );
    });

    test('Ignition Option silently defaults unknown input to Sürücü bytes', () {
      expect(
        KLineCodec.encodeIgnitionOption('gibberish'),
        KLineCodec.encodeIgnitionOption('Sürücü'),
      );
    });

    test('Distance Unit round-trips km/Mil', () {
      expect(
        KLineCodec.decodeDistanceUnit(KLineCodec.encodeDistanceUnit('km')),
        'km',
      );
      expect(
        KLineCodec.decodeDistanceUnit(KLineCodec.encodeDistanceUnit('Mil')),
        'Mil',
      );
    });

    test('Distance Unit silently defaults unknown input to Mil', () {
      expect(
        KLineCodec.encodeDistanceUnit('gibberish'),
        KLineCodec.encodeDistanceUnit('Mil'),
      );
    });

    test('IMS Source round-trips known values', () {
      for (final source in ['CAN A', 'CAN C', 'Devre Dışı']) {
        expect(
          KLineCodec.decodeImsSource(KLineCodec.encodeImsSource(source)),
          source,
        );
      }
    });

    test('CAN Baudrate round-trips known labels', () {
      for (final label in ['125 kbps', '250 kbps', '500 kbps', '1 Mbps']) {
        expect(
          KLineCodec.decodeCanBaudrate(KLineCodec.encodeCanBaudrate(label)),
          label,
        );
      }
    });

    test('CAN Baudrate silently defaults unknown label to 250 kbps', () {
      expect(
        KLineCodec.encodeCanBaudrate('gibberish'),
        KLineCodec.encodeCanBaudrate('250 kbps'),
      );
    });

    test('CAN Baudrate decode returns null for out-of-range index', () {
      expect(KLineCodec.decodeCanBaudrate([99, 5]), isNull);
    });

    test('GNSS Antenna round-trips İç/Dış', () {
      expect(
        KLineCodec.decodeGnssAntenna(KLineCodec.encodeGnssAntenna('İç')),
        'İç',
      );
      expect(
        KLineCodec.decodeGnssAntenna(KLineCodec.encodeGnssAntenna('Dış')),
        'Dış',
      );
    });
  });

  group('one-way helpers', () {
    test('decodeSeedHex renders bytes as uppercase hex', () {
      expect(KLineCodec.decodeSeedHex([0xAB, 0xCD, 0x01]), 'ABCD01');
    });

    test('encodePinAscii keeps printable ASCII and drops control chars', () {
      expect(KLineCodec.encodePinAscii('AB12'), [65, 66, 49, 50]);
      expect(
        KLineCodec.encodePinAscii('A${String.fromCharCode(1)}B'),
        [65, 66],
      );
    });

    test('decodeAsciiTrimmed trims surrounding padding', () {
      final bytes = [0x20, 0x41, 0x42, 0x20, 0x20];
      expect(KLineCodec.decodeAsciiTrimmed(bytes), 'AB');
      expect(KLineCodec.decodeAsciiTrimmed([]), isNull);
    });
  });
}
