import 'dart:async';
import 'dart:collection';

import '../bluetooth/models/log_entry.dart';

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _capacity = 500;

  bool _testModeEnabled = false;
  bool get testModeEnabled => _testModeEnabled;

  final _entries = ListQueue<LogEntry>();
  List<LogEntry> get entries => List.unmodifiable(_entries);
  int get entryCount => _entries.length;

  final _streamController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get stream => _streamController.stream;

  final _changeController = StreamController<void>.broadcast();
  Stream<void> get changes => _changeController.stream;

  void setTestMode(bool enabled) {
    _testModeEnabled = enabled;
    if (!enabled) return;
    _addEntry(LogEntry(
      message: 'Test mode ACTIVATED',
      level: LogLevel.success,
      category: LogCategory.system,
    ));
  }

  void log(
    String message, {
    LogLevel level = LogLevel.info,
    LogCategory category = LogCategory.system,
  }) {
    if (!_testModeEnabled) return;
    _addEntry(LogEntry(message: message, level: level, category: category));
  }

  final List<StreamSubscription<LogEntry>> _bridges = [];

  void bridgeStream(Stream<LogEntry> source) {
    final sub = source.listen((entry) {
      if (!_testModeEnabled) return;
      _addEntry(LogEntry(
        message: entry.message,
        level: entry.level,
        category: LogCategory.bluetooth,
      ));
    });
    _bridges.add(sub);
  }

  void cancelBridges() {
    for (final sub in _bridges) {
      sub.cancel();
    }
    _bridges.clear();
  }

  void _addEntry(LogEntry entry) {
    if (_entries.length >= _capacity) _entries.removeFirst();
    _entries.addLast(entry);
    _streamController.add(entry);
    _changeController.add(null);
  }

  void clear() {
    _entries.clear();
    _changeController.add(null);
  }

  String exportText() {
    final buf = StringBuffer();
    buf.writeln('=== Tacho Test Log ===');
    buf.writeln('Date: ${DateTime.now()}');
    buf.writeln('Total entries: ${_entries.length}');
    buf.writeln('');
    for (final e in _entries) {
      final ts = e.timestamp;
      final time =
          '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
      buf.writeln('[$time] [${e.prefix}] [${e.category.displayName}] ${e.message}');
    }
    return buf.toString();
  }
}
