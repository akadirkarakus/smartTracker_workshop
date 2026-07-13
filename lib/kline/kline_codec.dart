// K-LINE parametre encode / decode — CalibrationMessages.md Section 8
// Tüm decode fonksiyonları null döndürebilir (eksik/hatalı veri için).

class KLineCodec {
  KLineCodec._();

  // ── VIN (0xF190) — 17 bytes ASCII ─────────────────────────────────────────
  static List<int> encodeVin(String vin) =>
      _asciiPad(vin.toUpperCase(), 17);

  static String? decodeVin(List<int> bytes) {
    if (bytes.length < 17) return null;
    return _decodeAscii(bytes.sublist(0, 17));
  }

  // ── VRN (0xF97E) — 14 bytes ASCII (space-padded) ──────────────────────────
  // Takograf VRN alanının ilk baytını ekranında göstermiyor; içerik byte 2'den
  // başlayarak görünüyor. Bu nedenle encode sırasında başa 1 boşluk ekliyoruz.
  static List<int> encodeVrn(String vrn) =>
      _asciiPad(' ${vrn.toUpperCase()}', 14);

  static String? decodeVrn(List<int> bytes) {
    if (bytes.length < 14) return null;
    return _decodeAscii(bytes.sublist(0, 14)).trim();
  }

  // ── Odometer (0xF912) — 4 bytes BE (32-bit, m cinsinden × 1000 değil, km) ─
  static List<int> encodeOdometer(int km) => _uint32Be(km);

  static int? decodeOdometer(List<int> bytes) {
    if (bytes.length < 4) return null;
    return _readUint32Be(bytes, 0);
  }

  // ── K-Constant (0xF918) — 2 bytes BE ──────────────────────────────────────
  static List<int> encodeKConstant(int value) => _uint16Be(value);

  static int? decodeKConstant(List<int> bytes) {
    if (bytes.length < 2) return null;
    return _readUint16Be(bytes, 0);
  }

  // ── W-Constant (0xF91D) — 2 bytes BE ──────────────────────────────────────
  static List<int> encodeWConstant(int value) => _uint16Be(value);

  static int? decodeWConstant(List<int> bytes) {
    if (bytes.length < 2) return null;
    return _readUint16Be(bytes, 0);
  }

  // ── Tyre Circumference (0xF91C) — 2 bytes: value × 8 ─────────────────────
  static List<int> encodeTyreCircumference(int mm) => _uint16Be(mm * 8);

  static int? decodeTyreCircumference(List<int> bytes) {
    if (bytes.length < 2) return null;
    return _readUint16Be(bytes, 0) ~/ 8;
  }

  // ── Tyre Size (0xF921) — 15 bytes ASCII (space-padded) ───────────────────
  static List<int> encodeTyreSize(String size) => _asciiPad(size, 15);

  static String? decodeTyreSize(List<int> bytes) {
    if (bytes.length < 15) return null;
    return _decodeAscii(bytes.sublist(0, 15)).trim();
  }

  // ── Next Calibration Date (0xF922) — 3 bytes: [Month, 4*(Day-1)+2, Year] ─
  static List<int> encodeNextCalDate(DateTime date) =>
      _encodeDate3(date.month, date.day, date.year % 100);

  static DateTime? decodeNextCalDate(List<int> bytes) {
    if (bytes.length < 3) return null;
    return _decodeDate3(bytes[0], bytes[1], bytes[2]);
  }

  // ── DateTime (0xF90B) — 8 bytes ───────────────────────────────────────────
  // [0x00, Min, Hour, Month, 4*(Day-1)+2, Year, LocalMinOffset, LocalHourOffset]
  static List<int> encodeDateTime(
    DateTime dt,
    int utcHourOffset,
    int utcMinOffset,
  ) {
    final year = dt.year % 100;
    return [
      0x00,
      dt.minute,
      dt.hour,
      dt.month,
      4 * (dt.day - 1) + 2,
      year,
      _encodeUtcMinuteByte(utcMinOffset),
      _encodeUtcHourByte(utcHourOffset),
    ];
  }

  static DateTime? decodeDateTime(List<int> bytes) {
    if (bytes.length < 8) return null;
    final min   = bytes[1];
    final hour  = bytes[2];
    final month = bytes[3];
    final day   = (bytes[4] - 2) ~/ 4 + 1;
    final year  = 2000 + bytes[5];
    if (!_validDate(year, month, day)) return null;
    return DateTime(year, month, day, hour, min);
  }

  // ── Speed Limit (0xF92C) — 2 bytes: [SpeedLimit, 0x00] ───────────────────
  static List<int> encodeSpeedLimit(int kmh) => [kmh, 0x00];

  static int? decodeSpeedLimit(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // ── Member State (0xF97D) — 3 bytes ASCII ─────────────────────────────────
  static List<int> encodeMemberState(String code) =>
      _asciiPad(code.toUpperCase(), 3);

  static String? decodeMemberState(List<int> bytes) {
    if (bytes.length < 3) return null;
    return _decodeAscii(bytes.sublist(0, 3)).trim();
  }

  // ── UTC Minute Offset (0xF90D) — 1 byte: (counter % 2) * 30 + 0x7D ──────
  // counter: UTC offset in half-hours (örn. +03:00 → counter = 6)
  static int encodeUtcMinuteByte(int utcHalfHourCounter) =>
      _encodeUtcMinuteByte(utcHalfHourCounter);

  static int _encodeUtcMinuteByte(int counter) =>
      (counter % 2) * 30 + 0x7D;

  // ── UTC Hour Offset (0xF90E) — 1 byte: (counter / 2) + 0x7D ──────────────
  static int encodeUtcHourByte(int utcHalfHourCounter) =>
      _encodeUtcHourByte(utcHalfHourCounter);

  static int _encodeUtcHourByte(int counter) =>
      (counter ~/ 2) + 0x7D;

  // UTC offset (toplam dakika) → KWP2000 "counter" değeri.
  // Protokol: counter=0 → UTC-12:00, her adım 30 dk; counter=24 → UTC+0.
  static int utcOffsetCounter(int totalMinutes) => (totalMinutes ~/ 30) + 24;

  // UTC offset'i toplam dakika cinsinden alıp her iki byte'ı döner
  // totalMinutes: örn. +180 (UTC+3), -60 (UTC-1)
  static List<int> encodeUtcOffset(int totalMinutes) {
    final counter = utcOffsetCounter(totalMinutes);
    return [_encodeUtcMinuteByte(counter), _encodeUtcHourByte(counter)];
  }

  // minByte (0xF90D) ve hourByte (0xF90E) döner; toplam dakika cinsinden UTC farkını çözer.
  static int? decodeUtcOffset(List<int> minByte, List<int> hourByte) {
    if (minByte.isEmpty || hourByte.isEmpty) return null;
    final counter = (hourByte[0] - 0x7D) * 2 + ((minByte[0] - 0x7D) ~/ 30);
    return (counter - 24) * 30;
  }

  // ── ECU Install Date (0xF19D) — 3 bytes BCD: Year, Month, Day ─────────────
  static List<int> encodeEcuInstallDate(DateTime date) => [
        _bcd(date.year % 100),
        _bcd(date.month),
        _bcd(date.day),
      ];

  static DateTime? decodeEcuInstallDate(List<int> bytes) {
    if (bytes.length < 3) return null;
    final year  = 2000 + _fromBcd(bytes[0]);
    final month = _fromBcd(bytes[1]);
    final day   = _fromBcd(bytes[2]);
    if (!_validDate(year, month, day)) return null;
    return DateTime(year, month, day);
  }

  // ── Vehicle Registration Date (0xF97F) — 8 bytes ─────────────────────────
  // [0x00, 0x00, 0x00, Month, 4*(Day-1)+2, Year, 0x7D, 0x7D]
  static List<int> encodeVehicleRegDate(DateTime date) => [
        0x00, 0x00, 0x00,
        date.month,
        4 * (date.day - 1) + 2,
        date.year % 100,
        0x7D, 0x7D,
      ];

  static DateTime? decodeVehicleRegDate(List<int> bytes) {
    if (bytes.length < 6) return null;
    final month = bytes[3];
    final day   = (bytes[4] - 2) ~/ 4 + 1;
    final year  = 2000 + bytes[5];
    if (!_validDate(year, month, day)) return null;
    return DateTime(year, month, day);
  }

  // ── PPROOS (0xF91E) — 2 bytes BE (range 0–64255) ─────────────────────────
  static List<int> encodePproos(int value) => _uint16Be(value.clamp(0, 64255));

  static int? decodePproos(List<int> bytes) {
    if (bytes.length < 2) return null;
    return _readUint16Be(bytes, 0);
  }

  // ── Number of Teeth (0xF91A) — 1 byte (range 0–250) ──────────────────────
  static List<int> encodeTeethCount(int value) => [value.clamp(0, 250)];

  static int? decodeTeethCount(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // ── Prewarning fields — 1 byte each (days) ────────────────────────────────
  static List<int> encodePrewarningDays(int days) => [days.clamp(0, 250)];

  static int? decodePrewarningDays(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // ── Download Period — 1 byte (VU: 0–120, Card: 0–250) ────────────────────
  static List<int> encodeDownloadPeriod(int days) => [days];

  static int? decodeDownloadPeriod(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // ── Reset Heartbeat (0xF90C) — 1 byte ────────────────────────────────────
  // 0x00 = Disabled, 0x01 = Enabled
  static List<int> encodeHeartbeat(bool enabled) => [enabled ? 0x01 : 0x00];

  static bool? decodeHeartbeat(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01;
  }

  // ── TCO1 Priority (0xF90F) — 1 byte ──────────────────────────────────────
  // 0x00 = Highest, 0x01–0x06 = Priority 1–6, 0x07 = Lowest
  static List<int> encodeTco1Priority(int priority) =>
      [priority.clamp(0, 7)];

  static int? decodeTco1Priority(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // ── TCO1 Repetition Rate (0xF920) — 1 byte ───────────────────────────────
  // 0x00 = 20ms, 0x01 = 50ms
  static List<int> encodeTco1RepRate(bool is50ms) => [is50ms ? 0x01 : 0x00];

  static bool? decodeTco1RepRate(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01;
  }

  // ── Trip Distance (0xF913) — 4 bytes BE ──────────────────────────────────
  static List<int> encodeTripDistance(int km) => _uint32Be(km);

  static int? decodeTripDistance(List<int> bytes) {
    if (bytes.length < 4) return null;
    return _readUint32Be(bytes, 0);
  }

  // ── Opsiyonel Ayarlar (0xFD??) — Section 8.3 ─────────────────────────────

  // Genel açma/kapama bayrağı — B7 Tanıma, Tripmetre Sıfırlama, Periyodik DAGS
  static List<int> encodeEnabledByte(bool enabled) => [enabled ? 0x01 : 0x00];

  static bool? decodeEnabledByte(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01;
  }

  // Speedometer Factor (0xFD00 / 0xFD11) — 2 bytes BE, 1–60000
  static List<int> encodeSpeedometerFactor(int value) =>
      _uint16Be(value.clamp(1, 60000));

  static int? decodeSpeedometerFactor(List<int> bytes) {
    if (bytes.length < 2) return null;
    return _readUint16Be(bytes, 0);
  }

  // Military Dimmer (0xFD04, yalnızca STC8250) — 0x00=Disabled, 0x01=CAN-A, 0x03=CAN-C
  static List<int> encodeMilitaryDimmer(bool enabled) => [enabled ? 0x01 : 0x00];

  static bool? decodeMilitaryDimmer(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] != 0x00;
  }

  // Overspeed Prewarning Time (0xFD06 / 0xFD1A) — 1 byte, saniye, 0–60
  static List<int> encodeOverspeedPrewarningSeconds(int seconds) =>
      [seconds.clamp(0, 60)];

  static int? decodeOverspeedPrewarningSeconds(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0];
  }

  // Ignition Options (0xFD07 / 0xFD18) — 4 bytes: DriverIgnOn, CoDriverIgnOn, DriverIgnOff, CoDriverIgnOff
  static List<int> encodeIgnitionOption(String option) =>
      option == 'Ko-Pilot' ? [0x00, 0x01, 0x00, 0x01] : [0x01, 0x00, 0x01, 0x00];

  static String? decodeIgnitionOption(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01 ? 'Sürücü' : 'Ko-Pilot';
  }

  // Distance Unit (0xFD0B / 0xFD1E) — 1 byte: 0x00=Mile, 0x01=km
  static List<int> encodeDistanceUnit(String unit) => [unit == 'km' ? 0x01 : 0x00];

  static String? decodeDistanceUnit(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01 ? 'km' : 'Mil';
  }

  // IMS Source (0xFD0F / 0xFD17) — 1 byte: 0x00=Disabled, 0x01=CAN-A, 0x02=CAN-C
  static List<int> encodeImsSource(String source) {
    switch (source) {
      case 'CAN A': return [0x01];
      case 'CAN C': return [0x02];
      default:      return [0x00];
    }
  }

  static String? decodeImsSource(List<int> bytes) {
    if (bytes.isEmpty) return null;
    switch (bytes[0]) {
      case 0x01: return 'CAN A';
      case 0x02: return 'CAN C';
      default:   return 'Devre Dışı';
    }
  }

  // CAN A/C Baudrate (0xFD08/0xFD09/0xFD32/0xFD35) — 2 bytes: baudrate idx, sampling point idx
  // Sampling point uygulamada gösterilmiyor; varsayılan (idx 5, ~80%) ile yazılır.
  static const int _defaultCanSamplingPointIdx = 5;

  static List<int> encodeCanBaudrate(String label) {
    const labels = ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'];
    final idx = labels.indexOf(label);
    return [idx == -1 ? 1 : idx, _defaultCanSamplingPointIdx];
  }

  static String? decodeCanBaudrate(List<int> bytes) {
    if (bytes.isEmpty) return null;
    const labels = ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'];
    if (bytes[0] < 0 || bytes[0] >= labels.length) return null;
    return labels[bytes[0]];
  }

  // GNSS Antenna (0xFD53, yalnızca STC8255) — 0x00=İç, 0x01=Dış
  static List<int> encodeGnssAntenna(String value) => [value == 'Dış' ? 0x01 : 0x00];

  static String? decodeGnssAntenna(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] == 0x01 ? 'Dış' : 'İç';
  }

  // Card Existence Warning (0xFD51, yalnızca STC8255) — 0x00=Disabled, 0x01=Display, 0x02=Display&Buzzer
  static List<int> encodeCardExistenceWarning(bool enabled) => [enabled ? 0x01 : 0x00];

  static bool? decodeCardExistenceWarning(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return bytes[0] != 0x00;
  }

  // ── SecurityAccess seed/key ────────────────────────────────────────────────
  // Seed, yanıt byte'larından ham hex string olarak döner
  static String decodeSeedHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();

  // PIN ASCII bytes — string'i ASCII byte listesine dönüştür
  static List<int> encodePinAscii(String pin) =>
      pin.codeUnits.where((c) => c >= 32 && c <= 126).toList();

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  static List<int> _uint16Be(int v) => [(v >> 8) & 0xFF, v & 0xFF];

  static List<int> _uint32Be(int v) => [
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ];

  static int _readUint16Be(List<int> bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  static int _readUint32Be(List<int> bytes, int offset) =>
      (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) | bytes[offset + 3];

  // ASCII string'i verilen uzunluğa space ile pad et
  static List<int> _asciiPad(String s, int length) {
    final bytes = s.codeUnits.take(length).toList();
    while (bytes.length < length) { bytes.add(0x20); }
    return bytes;
  }

  // Yazdırılabilir ASCII byte'lardan string oluştur
  static String _decodeAscii(List<int> bytes) =>
      String.fromCharCodes(bytes.where((b) => b >= 0x20 && b <= 0x7E));

  // Genel ASCII alan decode — HW/SW/Seri No gibi trim'lenmiş metin kayıtları için
  static String? decodeAsciiTrimmed(List<int> bytes) {
    if (bytes.isEmpty) return null;
    return _decodeAscii(bytes).trim();
  }

  // 3-byte tarih encode: [Month, 4*(Day-1)+2, Year%100]
  static List<int> _encodeDate3(int month, int day, int year2digit) =>
      [month, 4 * (day - 1) + 2, year2digit];

  // 3-byte tarih decode
  static DateTime? _decodeDate3(int month, int encoded, int year2digit) {
    final day  = (encoded - 2) ~/ 4 + 1;
    final year = 2000 + year2digit;
    if (!_validDate(year, month, day)) return null;
    return DateTime(year, month, day);
  }

  static bool _validDate(int year, int month, int day) {
    if (year < 2000 || month < 1 || month > 12 || day < 1) return false;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    return day <= daysInMonth;
  }

  static int _bcd(int v) => ((v ~/ 10) << 4) | (v % 10);
  static int _fromBcd(int bcd) => ((bcd >> 4) * 10) + (bcd & 0x0F);
}
