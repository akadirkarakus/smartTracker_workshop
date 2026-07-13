enum LogLevel { info, success, error, outgoing, incoming }

enum LogCategory { bluetooth, calibration, diagnostics, navigation, pinAuth, system }

extension LogCategoryLabel on LogCategory {
  String get displayName => switch (this) {
        LogCategory.bluetooth => 'BT',
        LogCategory.calibration => 'Kalibrasyon',
        LogCategory.diagnostics => 'Tanılama',
        LogCategory.navigation => 'Navigasyon',
        LogCategory.pinAuth => 'PIN',
        LogCategory.system => 'Sistem',
      };
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final LogCategory category;

  LogEntry({
    required this.message,
    required this.level,
    this.category = LogCategory.bluetooth,
  }) : timestamp = DateTime.now();

  String get prefix => switch (level) {
        LogLevel.info => 'BİLGİ',
        LogLevel.success => 'BAŞARI',
        LogLevel.error => 'HATA',
        LogLevel.outgoing => '→',
        LogLevel.incoming => '←',
      };
}
