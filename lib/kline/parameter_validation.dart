// Kalibrasyon parametrelerinin takografa gönderilmeden önce doğrulanması.
// CalibrationMessages.md §8.2/§8.3'te belgelenen byte genişliği ve aralık
// kısıtlarını uygular; ilgili CalParam.type'a göre dallanır.

import '../models/calibration_data.dart';

class ParamValidationException implements Exception {
  final String message;
  ParamValidationException(this.message);

  @override
  String toString() => message;
}

class ParameterValidator {
  ParameterValidator._();

  // id -> (min, max) — CalibrationMessages.md §8.2 aralıkları.
  static const Map<String, (int, int)> _numericRanges = {
    'tyre_circ':       (1, 8191),        // mm×8 uint16'ya sığmalı (65535/8)
    'k_constant':      (1, 65535),
    'w_constant':      (1, 65535),
    'pproos':          (0, 64255),
    'teeth_count':     (0, 250),
    'speed_limit':     (0, 255),
    'odometer':        (0, 4294967295),
    'trip_distance':   (0, 4294967295),
    'prewarning_card1':     (0, 250),
    'prewarning_tacho':     (0, 250),
    'prewarning_cal':       (0, 250),
    'download_period_vu':   (0, 120),
    'download_period_card': (0, 250),
  };

  static final RegExp _integerPattern = RegExp(r'^[0-9]+$');
  static final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Verilen ham girdiyi `param.type`'a göre doğrular ve normalize edilmiş
  /// (trim edilmiş, gereksiz baştaki sıfırlar temizlenmiş) hâlini döner.
  /// Geçersizse [ParamValidationException] fırlatır.
  static String validate(CalParam param, String raw) {
    switch (param.type) {
      case ParamType.text:
        return _validateText(param, raw);
      case ParamType.number:
        return _validateNumber(param, raw);
      case ParamType.date:
        return _validateDate(raw);
      case ParamType.dateTime:
        return _validateDateTime(raw);
      case ParamType.selectOption:
        return _validateOption(param, raw);
      case ParamType.toggleBool:
        return _validateToggle(raw);
      case ParamType.tyreSize:
        return _validateTyreSize(param, raw);
    }
  }

  static String _validateText(CalParam param, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ParamValidationException('${param.label}: Bu alan boş bırakılamaz.');
    }
    if (param.maxLen != null && trimmed.length > param.maxLen!) {
      throw ParamValidationException(
        '${param.label}: En fazla ${param.maxLen} karakter girilebilir.',
      );
    }
    for (final unit in trimmed.codeUnits) {
      if (unit < 0x20 || unit > 0x7E) {
        throw ParamValidationException(
          '${param.label}: Sadece standart İngilizce harf, rakam ve temel semboller kullanılabilir.',
        );
      }
    }
    return trimmed;
  }

  static String _validateNumber(CalParam param, String raw) {
    final range = _numericRanges[param.id];
    final value = range != null
        ? validateNumberInRange(raw, label: param.label, min: range.$1, max: range.$2)
        : _parseInteger(raw, param.label);
    return value.toString();
  }

  /// Genel amaçlı tam sayı + aralık doğrulaması. `CalParam`'a bağlı olmayan
  /// çağıranlar (ör. Opsiyonel Ayarlar ekranı) için de kullanılabilir.
  /// Geçersizse [ParamValidationException] fırlatır.
  static int validateNumberInRange(
    String raw, {
    required String label,
    required int min,
    required int max,
  }) {
    final value = _parseInteger(raw, label);
    if (value < min || value > max) {
      throw ParamValidationException('$label: Değer $min–$max aralığında olmalıdır.');
    }
    return value;
  }

  static int _parseInteger(String raw, String label) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ParamValidationException('$label: Bu alan boş bırakılamaz.');
    }
    if (!_integerPattern.hasMatch(trimmed)) {
      throw ParamValidationException(
        '$label: Bu alan tam sayı olmalıdır (ondalık kabul edilmiyor).',
      );
    }
    return int.parse(trimmed);
  }

  static String _validateDate(String raw) {
    final trimmed = raw.trim();
    if (!_isoDatePattern.hasMatch(trimmed)) {
      throw ParamValidationException('Geçersiz tarih formatı.');
    }
    final parts = trimmed.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    if (year < 2000 || year > 2099) {
      throw ParamValidationException('Yıl 2000-2099 arasında olmalıdır.');
    }
    if (month < 1 || month > 12) {
      throw ParamValidationException('Ay 1-12 arasında olmalıdır.');
    }
    if (day < 1 || day > 31) {
      throw ParamValidationException('Gün 1-31 arasında olmalıdır.');
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw ParamValidationException('Geçersiz tarih.');
    }
    return trimmed;
  }

  static String _validateDateTime(String raw) {
    final trimmed = raw.trim();
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      throw ParamValidationException('Geçersiz tarih/saat formatı.');
    }
    return parsed.toIso8601String();
  }

  static String _validateOption(CalParam param, String raw) {
    final trimmed = raw.trim();
    if (param.options == null || !param.options!.contains(trimmed)) {
      throw ParamValidationException('${param.label}: Geçersiz seçenek.');
    }
    return trimmed;
  }

  static final RegExp _tyreSizePattern = RegExp(r'^\d{2,3}/\d{2}R\d{2}(\.5)?$');

  static String _validateTyreSize(CalParam param, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ParamValidationException('${param.label}: Bu alan boş bırakılamaz.');
    }
    if (!_tyreSizePattern.hasMatch(trimmed)) {
      throw ParamValidationException(
        '${param.label}: Geçersiz lastik ebadı formatı (örn. 295/80R22.5).',
      );
    }
    if (param.maxLen != null && trimmed.length > param.maxLen!) {
      throw ParamValidationException(
        '${param.label}: En fazla ${param.maxLen} karakter girilebilir.',
      );
    }
    return trimmed;
  }

  static String _validateToggle(String raw) {
    final trimmed = raw.trim();
    if (trimmed != 'ENABLED' && trimmed != 'DISABLED') {
      throw ParamValidationException('Geçersiz değer.');
    }
    return trimmed;
  }
}
