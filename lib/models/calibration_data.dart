import 'package:flutter/material.dart';

// ──────────────────────────────────────────────
// Colors (Material Design 3 – TachoCal palette)
// ──────────────────────────────────────────────
class CalColors {
  static const primary = Color(0xFF00475E);
  static const primaryContainer = Color(0xFF1A5F7A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8F9FF);
  static const surface = Color(0xFFF8F9FF);
  static const onSurface = Color(0xFF0D1C2F);
  static const onSurfaceVariant = Color(0xFF40484D);
  static const outline = Color(0xFF70787D);
  static const outlineVariant = Color(0xFFC0C8CD);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceHigh = Color(0xFFDDE9FF);
  static const surfaceHighest = Color(0xFFD5E3FD);
  static const tertiary = Color(0xFF004A43);
  static const tertiaryContainer = Color(0xFF00645A);
  static const onTertiaryContainer = Color(0xFF75E2D2);
  static const tertiaryFixed = Color(0xFF89F5E5);
  static const tertiaryFixedDim = Color(0xFF6CD8C9);
  static const accent = Color(0xFF57C5B6);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
  static const secondaryContainer = Color(0xFFD6E2E6);
  static const onSecondaryContainer = Color(0xFF596568);
}

// ──────────────────────────────────────────────
// Calibration Parameters
// ──────────────────────────────────────────────
enum CalSection { vehicle, tyre, time, system }

enum ParamType { text, number, date, dateTime, selectOption, toggleBool }

class CalParam {
  final String id;
  final String label;
  final CalSection section;
  final ParamType type;
  String? value;
  final String unit;
  final List<String>? options;
  final int? maxLen;

  CalParam({
    required this.id,
    required this.label,
    required this.section,
    required this.type,
    this.value,
    this.unit = '',
    this.options,
    this.maxLen,
  });
}

List<CalParam> defaultCalParams() => [
      // ── Araç Kimliği ───────────────────────────
      CalParam(id: 'vrn',          label: 'Plaka (VRN)',              section: CalSection.vehicle, type: ParamType.text,         maxLen: 13),
      CalParam(id: 'vin',          label: 'VIN',                      section: CalSection.vehicle, type: ParamType.text,         maxLen: 17),
      CalParam(id: 'member_state', label: 'Kayıt Ülkesi',             section: CalSection.vehicle, type: ParamType.selectOption,
        options: ['TUR', 'ENG', 'DEU', 'FRA', 'POL', 'ESP', 'UKR', 'NLD', 'BEL']),
      CalParam(id: 'reg_date',     label: 'Araç Tescil Tarihi',       section: CalSection.vehicle, type: ParamType.date),
      // ── Lastik & Hareket ───────────────────────
      CalParam(id: 'tyre_size',    label: 'Lastik Boyutu',            section: CalSection.tyre,    type: ParamType.text,         maxLen: 15),
      CalParam(id: 'tyre_circ',    label: 'Lastik Çevresi',           section: CalSection.tyre,    type: ParamType.number,       unit: 'mm'),
      CalParam(id: 'k_constant',   label: 'K-Sabiti',                 section: CalSection.tyre,    type: ParamType.number,       unit: 'imp/km'),
      CalParam(id: 'w_constant',   label: 'W-Sabiti',                 section: CalSection.tyre,    type: ParamType.number,       unit: 'imp/km'),
      CalParam(id: 'pproos',       label: 'Çıkış Mili Hızı (PPROOS)',section: CalSection.tyre,    type: ParamType.number,       unit: 'imp/dev'),
      CalParam(id: 'teeth_count',  label: 'Diş Sayısı',              section: CalSection.tyre,    type: ParamType.number,       unit: 'adet'),
      CalParam(id: 'speed_limit',  label: 'Hız Limiti',               section: CalSection.tyre,    type: ParamType.number,       unit: 'km/h'),
      CalParam(id: 'odometer',     label: 'Kilometre Sayacı',         section: CalSection.tyre,    type: ParamType.number,       unit: 'km'),
      CalParam(id: 'trip_distance',label: 'Seyahat Mesafesi',         section: CalSection.tyre,    type: ParamType.number,       unit: 'km'),
      // ── Zaman & Bölge ──────────────────────────
      CalParam(id: 'datetime',     label: 'Tarih ve Saat',            section: CalSection.time,    type: ParamType.dateTime),
      CalParam(id: 'utc_offset',   label: 'UTC Farkı',                section: CalSection.time,    type: ParamType.selectOption,
        options: ['-12:00', '-11:00', '-10:00', '-09:00', '-08:00', '-07:00',
                  '-06:00', '-05:00', '-04:00', '-03:00', '-02:00', '-01:00',
                  '+00:00', '+01:00', '+02:00', '+03:00', '+04:00', '+05:00',
                  '+06:00', '+07:00', '+08:00', '+09:00', '+10:00', '+11:00', '+12:00']),
      // ── Sistem & Bakım ─────────────────────────
      CalParam(id: 'heartbeat',       label: 'Kalp Atışı Sıfırlama',        section: CalSection.system, type: ParamType.toggleBool),
      CalParam(id: 'tco1_priority',   label: 'TCO1 Önceliği',               section: CalSection.system, type: ParamType.selectOption,
        options: ['0', '1', '2', '3', '4', '5', '6', '7']),
      CalParam(id: 'tco1_rate',       label: 'TCO1 Tekrar Hızı',            section: CalSection.system, type: ParamType.selectOption,
        options: ['20 ms', '50 ms']),
      CalParam(id: 'ecu_install_date',label: 'ECU Kurulum Tarihi',           section: CalSection.system, type: ParamType.date),
      CalParam(id: 'next_cal_date',   label: 'Sonraki Kalibrasyon Tarihi',   section: CalSection.system, type: ParamType.date),
      CalParam(id: 'prewarning_card1',        label: 'Kart 1 Ön Uyarı Süresi (STC8255)',        section: CalSection.system, type: ParamType.number, unit: 'gün'),
      CalParam(id: 'prewarning_tacho',        label: 'Takograf Ön Uyarı Süresi (STC8255)',      section: CalSection.system, type: ParamType.number, unit: 'gün'),
      CalParam(id: 'prewarning_cal',          label: 'Kalibrasyon Ön Uyarı Süresi (STC8255)',   section: CalSection.system, type: ParamType.number, unit: 'gün'),
      CalParam(id: 'download_period_vu',      label: 'İndirme Periyodu - VU (STC8255)',         section: CalSection.system, type: ParamType.number, unit: 'gün'),
      CalParam(id: 'download_period_card',    label: 'İndirme Periyodu - Kart (STC8255)',       section: CalSection.system, type: ParamType.number, unit: 'gün'),
    ];

// ──────────────────────────────────────────────
// DTC Codes
// ──────────────────────────────────────────────
class DtcCode {
  final String code;
  final String description;
  final String module;
  final bool isActive;

  const DtcCode({
    required this.code,
    required this.description,
    required this.module,
    required this.isActive,
  });
}

List<DtcCode> defaultDtcCodes() => [];

// ──────────────────────────────────────────────
// Component Tests
// ──────────────────────────────────────────────
enum TestStatus { idle, running, passed, failed }

class ComponentTest {
  final String id;
  final String name;
  final String description;
  final String menuSection; // 'COMPONENT' | 'SYSTEM'
  TestStatus status;
  int progress;

  ComponentTest({
    required this.id,
    required this.name,
    required this.description,
    required this.menuSection,
    this.status = TestStatus.idle,
    this.progress = 0,
  });
}

List<ComponentTest> defaultTests() => [
      ComponentTest(id: 'display', name: 'Ekran Testi', description: 'Piksel ve arka ışık bütünlük testi', menuSection: 'COMPONENT'),
      ComponentTest(id: 'lcd_neg', name: 'LCD Negatif Modu', description: 'Negatif görüntü kalite testi', menuSection: 'COMPONENT'),
      ComponentTest(id: 'printer', name: 'Yazıcı Testi', description: 'Termal kafa ve kağıt besleme testi', menuSection: 'COMPONENT'),
      ComponentTest(id: 'card_reader', name: 'Kart Okuyucu Testi', description: 'Akıllı kart okuyucu doğrulaması', menuSection: 'COMPONENT'),
      ComponentTest(id: 'keypad', name: 'Tuş Takımı Testi', description: 'Tüm tuşların işlevsellik kontrolü', menuSection: 'COMPONENT'),
      ComponentTest(id: 'buzzer_test', name: 'Zil Testi', description: 'Buzzer ses çıkışı testi', menuSection: 'COMPONENT'),
      ComponentTest(id: 'clock', name: 'Saat Testi', description: 'RTC kristali ve sürüklenme doğrulaması', menuSection: 'SYSTEM'),
      ComponentTest(id: 'speed_odo', name: 'Hız & Kilometre Testi', description: 'Otomatik darbe çıkışı ile doğrulama', menuSection: 'SYSTEM'),
      ComponentTest(id: 'hardware', name: 'Donanım Testi', description: 'Genel donanım öz testi', menuSection: 'SYSTEM'),
      ComponentTest(id: 'battery', name: 'Batarya Seviye Testi', description: 'Akü gerilim ölçümü', menuSection: 'SYSTEM'),
      ComponentTest(id: 'data_memory', name: 'Veri Bellek Bütünlüğü', description: 'Flash bellek doğrulama testi', menuSection: 'SYSTEM'),
      ComponentTest(id: 'sw_integrity', name: 'Yazılım Bütünlüğü', description: 'Yazılım imza doğrulaması', menuSection: 'SYSTEM'),
    ];

// ──────────────────────────────────────────────
// Recent Reports
// ──────────────────────────────────────────────
class RecentReport {
  final String vehicleName;
  final String plate;
  final String time;
  final bool isSuccess;
  final String statusLabel;

  const RecentReport({
    required this.vehicleName,
    required this.plate,
    required this.time,
    required this.isSuccess,
    required this.statusLabel,
  });
}

List<RecentReport> defaultReports() => [];

// ──────────────────────────────────────────────
// Service Device Settings
// ──────────────────────────────────────────────
class ServiceSettings {
  String photoSensor; // 'Sensor' | 'Matt' | 'Lontex'
  String language;
  bool darkThemeEnabled;
  String workshopName;
  bool testModeEnabled;

  ServiceSettings({
    this.photoSensor = 'Sensor',
    this.language = 'Türkçe',
    this.darkThemeEnabled = false,
    this.workshopName = 'SmartTrack Servis A.Ş.',
    this.testModeEnabled = false,
  });

  Map<String, dynamic> toMap() => {
        'photoSensor': photoSensor,
        'language': language,
        'darkThemeEnabled': darkThemeEnabled,
        'workshopName': workshopName,
        'testModeEnabled': testModeEnabled,
      };

  factory ServiceSettings.fromMap(Map<String, dynamic> map) => ServiceSettings(
        photoSensor: map['photoSensor'] as String? ?? 'Sensor',
        language: map['language'] as String? ?? 'Türkçe',
        darkThemeEnabled: map['darkThemeEnabled'] as bool? ?? false,
        workshopName: map['workshopName'] as String? ?? 'SmartTrack Servis A.Ş.',
        testModeEnabled: map['testModeEnabled'] as bool? ?? false,
      );
}

// ──────────────────────────────────────────────
// Optional Hardware Settings
// ──────────────────────────────────────────────
class OptionalSettings {
  // Common
  String? speedometerFactor;
  bool? b7Recognize;
  bool? militaryDimmer;
  int? overspeedPrewarningTime;
  String? ignitionOption; // 'Sürücü' | 'Ko-Pilot'
  String? distanceUnit;   // 'km' | 'Mil'
  bool? tripMeterReset;
  String? imsSource;      // 'CAN A' | 'CAN C' | 'Devre Dışı'
  String? canABaudrate;
  String? canCBaudrate;

  // STC8255 only
  String? gnssAntenna;    // 'İç' | 'Dış'
  bool? periodicDags;
  bool? cardExistenceWarning;

  OptionalSettings();
}
