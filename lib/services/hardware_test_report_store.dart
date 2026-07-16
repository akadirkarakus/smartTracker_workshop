// Donanım Testi raporlarının kalıcılığı — ServiceSettings'in kullandığı aynı
// SharedPreferences mekanizması (bkz. calibration_screen.dart:_loadSettings/_saveSettings).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hardware_test_report.dart';

class HardwareTestReportStore {
  HardwareTestReportStore._();

  static const _prefsKey = 'hardware_test_reports';
  static const _maxStored = 20;

  static Future<List<HardwareTestReport>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HardwareTestReport.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(HardwareTestReport report) async {
    final existing = await loadAll();
    final updated = [report, ...existing].take(_maxStored).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(updated.map((r) => r.toJson()).toList()),
    );
  }
}
