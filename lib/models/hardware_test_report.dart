// Donanım Testi — sonuç modeli. Bkz. lib/kline/hardware_test_runner.dart

enum HwTestItemCategory {
  calParamRead,
  calParamWriteVerify,
  optionalSettingRead,
  dtcCountRead,
  dtcCodesRead,
  componentAutoResult, // Hardware/Battery/DataMemory/SwIntegrity — cihaz kendi sonuçlandırır
  componentVisualConfirm, // Display/LcdNeg/Printer/CardReader — operatör F1/F4 onayı gerekir
  componentNoResult, // Keypad/Buzzer — gözlemlenemez, sadece iletişim kontrolü
}

// pass/fail dışında bilinçli ara durumlar var — bkz. CLAUDE.md/SPRINT_BACKLOG.md K4/H5:
// sahte "Geçti" üretmemek için operatör onayı gereken veya sonucu doğrulanamayan
// testler ayrı durumlarla raporlanır.
enum HwTestStatus { pass, fail, visualConfirmRequired, skipped, commsOkResultUnverified }

extension HwTestStatusLabel on HwTestStatus {
  String get label => switch (this) {
        HwTestStatus.pass => 'Geçti',
        HwTestStatus.fail => 'Başarısız',
        HwTestStatus.visualConfirmRequired => 'Görsel Onay Gerekli',
        HwTestStatus.skipped => 'Atlandı',
        HwTestStatus.commsOkResultUnverified => 'İletişim OK',
      };
}

class HardwareTestItemResult {
  final String id;
  final String label;
  final HwTestItemCategory category;
  final int? recordId;
  final int? routineId;
  final HwTestStatus status;
  final String detail;
  final Duration duration;
  final DateTime timestamp;

  const HardwareTestItemResult({
    required this.id,
    required this.label,
    required this.category,
    this.recordId,
    this.routineId,
    required this.status,
    required this.detail,
    required this.duration,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'category': category.name,
        'recordId': recordId,
        'routineId': routineId,
        'status': status.name,
        'detail': detail,
        'durationMs': duration.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HardwareTestItemResult.fromJson(Map<String, dynamic> json) => HardwareTestItemResult(
        id: json['id'] as String,
        label: json['label'] as String,
        category: HwTestItemCategory.values.byName(json['category'] as String),
        recordId: json['recordId'] as int?,
        routineId: json['routineId'] as int?,
        status: HwTestStatus.values.byName(json['status'] as String),
        detail: json['detail'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class HardwareTestReport {
  final String id;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool pinAuthenticatedDuringRun;
  final String? deviceModel;
  final String? deviceSerial;
  final String? deviceFwVersion;
  final String? deviceHwVersion;
  final List<HardwareTestItemResult> items;

  const HardwareTestReport({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.pinAuthenticatedDuringRun,
    this.deviceModel,
    this.deviceSerial,
    this.deviceFwVersion,
    this.deviceHwVersion,
    required this.items,
  });

  int get passCount => items.where((i) => i.status == HwTestStatus.pass).length;
  int get failCount => items.where((i) => i.status == HwTestStatus.fail).length;
  int get visualConfirmCount =>
      items.where((i) => i.status == HwTestStatus.visualConfirmRequired).length;
  int get skippedCount => items.where((i) => i.status == HwTestStatus.skipped).length;
  int get commsOkUnverifiedCount =>
      items.where((i) => i.status == HwTestStatus.commsOkResultUnverified).length;
  bool get hasFailure => failCount > 0;

  String toLogText() {
    final buf = StringBuffer()
      ..writeln('Donanım Testi Raporu — $id')
      ..writeln('Başlangıç: ${startedAt.toIso8601String()}')
      ..writeln('Bitiş: ${finishedAt.toIso8601String()}')
      ..writeln('PIN Doğrulaması: ${pinAuthenticatedDuringRun ? "Doğrulandı" : "Doğrulanmadı"}')
      ..writeln('Cihaz: ${deviceModel ?? "—"}  Seri: ${deviceSerial ?? "—"}  '
          'FW: ${deviceFwVersion ?? "—"}  HW: ${deviceHwVersion ?? "—"}')
      ..writeln('Geçti: $passCount  Başarısız: $failCount  Görsel Onay: $visualConfirmCount  '
          'İletişim OK: $commsOkUnverifiedCount  Atlandı: $skippedCount')
      ..writeln('---');
    for (final item in items) {
      buf.writeln('[${item.timestamp.toIso8601String()}] '
          '${item.status.label.padRight(16)} ${item.label} — ${item.detail} '
          '(${item.duration.inMilliseconds}ms)');
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'pinAuthenticatedDuringRun': pinAuthenticatedDuringRun,
        'deviceModel': deviceModel,
        'deviceSerial': deviceSerial,
        'deviceFwVersion': deviceFwVersion,
        'deviceHwVersion': deviceHwVersion,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory HardwareTestReport.fromJson(Map<String, dynamic> json) => HardwareTestReport(
        id: json['id'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: DateTime.parse(json['finishedAt'] as String),
        pinAuthenticatedDuringRun: json['pinAuthenticatedDuringRun'] as bool,
        deviceModel: json['deviceModel'] as String?,
        deviceSerial: json['deviceSerial'] as String?,
        deviceFwVersion: json['deviceFwVersion'] as String?,
        deviceHwVersion: json['deviceHwVersion'] as String?,
        items: (json['items'] as List<dynamic>)
            .map((e) => HardwareTestItemResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
