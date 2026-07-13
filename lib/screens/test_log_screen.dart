import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bluetooth/models/log_entry.dart';
import '../core/app_logger.dart';
import '../models/calibration_data.dart';

class TestLogScreen extends StatefulWidget {
  const TestLogScreen({super.key});

  @override
  State<TestLogScreen> createState() => _TestLogScreenState();
}

class _TestLogScreenState extends State<TestLogScreen> {
  final _scrollController = ScrollController();
  final _logs = <LogEntry>[];
  List<LogEntry> _filtered = [];
  StreamSubscription<LogEntry>? _sub;
  LogCategory? _filterCategory;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _logs.addAll(AppLogger.instance.entries);
    _filtered = List.of(_logs);
    _sub = AppLogger.instance.stream.listen((e) {
      if (mounted) {
        setState(() {
          _logs.add(e);
          if (_filterCategory == null || e.category == _filterCategory) {
            _filtered.add(e);
          }
        });
        if (_autoScroll) _scrollToBottom();
      }
    });
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 80;
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }


  void _copyAll() {
    Clipboard.setData(ClipboardData(text: AppLogger.instance.exportText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Günlük panoya kopyalandı'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Günlüğü Temizle',
            style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: const Text('Tüm kayıtlar silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: CalColors.error, foregroundColor: Colors.white),
            onPressed: () {
              AppLogger.instance.clear();
              setState(() { _logs.clear(); _filtered.clear(); });
              Navigator.pop(context);
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CalColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Test Günlüğü',
                style: TextStyle(
                    color: CalColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17)),
            Text(
              '${AppLogger.instance.entryCount} entries'
              '${AppLogger.instance.testModeEnabled ? '' : ' · Recording stopped'}',
              style: TextStyle(
                fontSize: 11,
                color: AppLogger.instance.testModeEnabled
                    ? CalColors.accent
                    : CalColors.outline,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all, color: CalColors.onSurfaceVariant),
            tooltip: 'Panoya kopyala',
            onPressed: _logs.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: CalColors.onSurfaceVariant),
            tooltip: 'Günlüğü temizle',
            onPressed: _logs.isEmpty ? null : _clearAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: CalColors.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          _CategoryFilterBar(
            selected: _filterCategory,
            onChanged: (cat) => setState(() {
              _filterCategory = cat;
              _filtered = cat == null
                  ? List.of(_logs)
                  : _logs.where((e) => e.category == cat).toList();
            }),
          ),
          if (!AppLogger.instance.testModeEnabled)
            _TestModeOffBanner(),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(testModeEnabled: AppLogger.instance.testModeEnabled)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _LogLine(entry: filtered[i]),
                  ),
          ),
          if (!_autoScroll)
            GestureDetector(
              onTap: () {
                setState(() => _autoScroll = true);
                _scrollToBottom();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: CalColors.primaryContainer,
                alignment: Alignment.center,
                child: const Text(
                  '↓ En alta git',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  final LogCategory? selected;
  final void Function(LogCategory?) onChanged;

  const _CategoryFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CalColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Tümü',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            const SizedBox(width: 6),
            ...LogCategory.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _FilterChip(
                    label: cat.displayName,
                    selected: selected == cat,
                    color: _categoryColor(cat),
                    onTap: () => onChanged(selected == cat ? null : cat),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(LogCategory cat) => switch (cat) {
        LogCategory.bluetooth => const Color(0xFF1A5F7A),
        LogCategory.calibration => const Color(0xFF6D28D9),
        LogCategory.diagnostics => const Color(0xFFD97706),
        LogCategory.navigation => const Color(0xFF4A7A8A),
        LogCategory.pinAuth => const Color(0xFFDC2626),
        LogCategory.system => const Color(0xFF16A34A),
      };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = CalColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : CalColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : CalColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : CalColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;

  const _LogLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ts = entry.timestamp;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6),
          children: [
            TextSpan(
              text: '[$time] ',
              style: const TextStyle(color: CalColors.onSurfaceVariant),
            ),
            TextSpan(
              text: '[${entry.prefix}] ',
              style: TextStyle(color: _levelColor, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: '[${entry.category.displayName}] ',
              style: TextStyle(
                color: _categoryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: entry.message,
              style: const TextStyle(color: CalColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Color get _levelColor => switch (entry.level) {
        LogLevel.success => const Color(0xFF16A34A),
        LogLevel.error => const Color(0xFFDC2626),
        LogLevel.outgoing => const Color(0xFF1A5F7A),
        LogLevel.incoming => const Color(0xFFD97706),
        LogLevel.info => CalColors.onSurfaceVariant,
      };

  Color get _categoryColor => switch (entry.category) {
        LogCategory.bluetooth => const Color(0xFF1A5F7A),
        LogCategory.calibration => const Color(0xFF6D28D9),
        LogCategory.diagnostics => const Color(0xFFD97706),
        LogCategory.navigation => const Color(0xFF4A7A8A),
        LogCategory.pinAuth => const Color(0xFFDC2626),
        LogCategory.system => const Color(0xFF16A34A),
      };
}

class _TestModeOffBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF3C7),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFF92400E)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Test modu kapalı — yeni kayıt alınmıyor',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool testModeEnabled;

  const _EmptyState({required this.testModeEnabled});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            testModeEnabled ? Icons.receipt_long_outlined : Icons.bug_report_outlined,
            color: CalColors.outline,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            testModeEnabled
                ? 'Test modu aktif.\nİşlem yaptıkça loglar burada görünecek.'
                : 'Test modu kapalı.\nAyarlar sekmesinden aktif edin.',
            style: const TextStyle(color: CalColors.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
