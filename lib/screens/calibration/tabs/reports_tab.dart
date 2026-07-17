import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../models/calibration_data.dart';
import '../report_pdf.dart';

const double _kCardRadius = 14;

String _formatDateTime(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class ReportsTab extends StatefulWidget {
  final List<CalParam> params;
  final List<ComponentTest> tests;
  final String? deviceModel;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? hwVersion;
  final String? workshopName;
  final bool isDeviceConnected;

  const ReportsTab({
    super.key,
    required this.params,
    required this.tests,
    this.deviceModel,
    this.serialNumber,
    this.firmwareVersion,
    this.hwVersion,
    this.workshopName,
    this.isDeviceConnected = false,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _notesController = TextEditingController();
  bool _isExporting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Map<String, String> _paramValues() {
    final paramMap = {for (final p in widget.params) p.id: p};
    String val(String id) => paramMap[id]?.value ?? '—';
    String valWithUnit(String id) {
      final p = paramMap[id];
      if (p == null) return '—';
      final v = p.value;
      if (v == null) return '—';
      return p.unit.isNotEmpty ? '$v ${p.unit}' : v;
    }
    return {
      'Plaka (VRN)': val('vrn'),
      'VIN': val('vin'),
      'Hız Limiti': valWithUnit('speed_limit'),
      'Kilometre': valWithUnit('odometer'),
      'Lastik Boyutu': val('tyre_size'),
      'Lastik Çevresi': valWithUnit('tyre_circ'),
      'K-Sabiti': valWithUnit('k_constant'),
      'W-Sabiti': valWithUnit('w_constant'),
      'Son. Kal. Tarihi': val('next_cal_date'),
    };
  }

  static const _paramIcons = <String, IconData>{
    'Plaka (VRN)': Icons.directions_car_filled_outlined,
    'VIN': Icons.qr_code_outlined,
    'Hız Limiti': Icons.speed,
    'Kilometre': Icons.route,
    'Lastik Boyutu': Icons.tire_repair,
    'Lastik Çevresi': Icons.all_out,
    'K-Sabiti': Icons.functions,
    'W-Sabiti': Icons.calculate_outlined,
    'Son. Kal. Tarihi': Icons.event_outlined,
  };

  Future<Uint8List> _buildPdf() {
    final hasFailure = widget.tests.any((t) => t.status == TestStatus.failed);
    final anyTestRan = widget.tests.any((t) => t.status != TestStatus.idle);
    return buildCalibrationReportPdf(ReportPdfData(
      plate: _paramValues()['Plaka (VRN)'] ?? '—',
      generatedAt: DateTime.now(),
      paramValues: _paramValues(),
      tests: widget.tests,
      deviceModel: widget.deviceModel,
      serialNumber: widget.serialNumber,
      firmwareVersion: widget.firmwareVersion,
      hwVersion: widget.hwVersion,
      workshopName: widget.workshopName,
      operatorNotes: _notesController.text,
      hasFailure: hasFailure,
      anyTestRan: anyTestRan,
    ));
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildPdf();
      final plate = _paramValues()['Plaka (VRN)'] ?? 'rapor';
      await Printing.sharePdf(bytes: bytes, filename: 'kalibrasyon_${plate.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulamadı: $e'), backgroundColor: CalColors.error),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yazdırma başlatılamadı: $e'), backgroundColor: CalColors.error),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = widget.tests;
    final values = _paramValues();
    final hasFailure = tests.any((t) => t.status == TestStatus.failed);
    final anyTestRan = tests.any((t) => t.status != TestStatus.idle);
    final dateStr = _formatDateTime(DateTime.now());

    final connected = widget.isDeviceConnected;
    final deviceServiceItems = [
      if (connected) ...[
        _GridItem('Takograf', widget.deviceModel ?? '—', icon: Icons.memory_outlined),
        _GridItem('Seri No', widget.serialNumber ?? '—', icon: Icons.confirmation_number_outlined),
        _GridItem('Firmware', widget.firmwareVersion ?? '—', icon: Icons.system_update_outlined),
        _GridItem('Donanım Rev.', widget.hwVersion ?? '—', icon: Icons.developer_board),
      ],
      _GridItem('Servis', widget.workshopName ?? '—', icon: Icons.business_outlined),
      _GridItem('Rapor Tarihi', dateStr, icon: Icons.event_outlined),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary header
                    _ReportSummaryCard(plate: values['Plaka (VRN)']!, hasFailure: hasFailure, anyTestRan: anyTestRan, dateStr: dateStr),
                    const SizedBox(height: 16),

                    if (!connected) ...[
                      _DisconnectedNotice(),
                      const SizedBox(height: 16),
                    ],

                    // Calibration parameters — only meaningful once read from the device
                    if (connected) ...[
                      _SectionHeader(title: 'Kalibrasyon Parametreleri', icon: Icons.settings_input_component),
                      const SizedBox(height: 10),
                      _InfoGrid(
                        maxColumns: 3,
                        items: [for (final e in values.entries) _GridItem(e.key, e.value, icon: _paramIcons[e.key])],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Test results
                    _SectionHeader(title: 'Test Sonuçları', icon: Icons.fact_check_outlined),
                    const SizedBox(height: 10),
                    _TestResultsCard(tests: tests),
                    const SizedBox(height: 16),

                    // Device & workshop info — single symmetric grid
                    _SectionHeader(title: connected ? 'Cihaz ve Servis Bilgileri' : 'Servis Bilgileri', icon: Icons.engineering_outlined),
                    const SizedBox(height: 10),
                    _InfoGrid(maxColumns: 2, items: deviceServiceItems),
                    const SizedBox(height: 16),

                    // Operator notes
                    _SectionHeader(title: 'Operatör Notları', icon: Icons.description_outlined),
                    const SizedBox(height: 10),
                    _OperatorNotes(controller: _notesController),
                    const SizedBox(height: 22),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportPdf,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CalColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kCardRadius)),
                                elevation: 0,
                              ),
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('PDF Dışa Aktar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isExporting ? null : _printPdf,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: CalColors.primary, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kCardRadius)),
                              ),
                              icon: Icon(Icons.print, size: 18, color: CalColors.primary),
                              label: Text('Yazdır', style: TextStyle(color: CalColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────

class _ReportSummaryCard extends StatelessWidget {
  final String plate;
  final bool hasFailure;
  final bool anyTestRan;
  final String dateStr;

  const _ReportSummaryCard({required this.plate, required this.hasFailure, required this.anyTestRan, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeLabel;
    if (hasFailure) {
      badgeColor = CalColors.error;
      badgeIcon = Icons.cancel;
      badgeLabel = 'BAŞARISIZ';
    } else if (anyTestRan) {
      badgeColor = CalColors.accent;
      badgeIcon = Icons.check_circle;
      badgeLabel = 'BAŞARILI';
    } else {
      badgeColor = CalColors.outline;
      badgeIcon = Icons.hourglass_empty;
      badgeLabel = 'TEST BEKLENİYOR';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CalColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_car_filled_outlined, color: CalColors.onPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plate, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: CalColors.onSurface, fontFeatures: [FontFeature.tabularFigures()]), overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: CalColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        dateStr,
                        style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Text(badgeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: CalColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: CalColors.onPrimary, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CalColors.onSurface, letterSpacing: 0.1)),
      ],
    );
  }
}

class _DisconnectedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CalColors.secondaryContainer,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: CalColors.onSecondaryContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bluetooth bağlı değil — kalibrasyon parametreleri ve cihaz bilgileri cihaza bağlanınca görünür.',
              style: TextStyle(fontSize: 12.5, color: CalColors.onSecondaryContainer, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridItem {
  final String label;
  final String value;
  final IconData? icon;

  const _GridItem(this.label, this.value, {this.icon});
}

/// A symmetric label/value grid: every cell is exactly 1/columns wide and
/// rows are separated by dividers, so the block never reads as lopsided
/// regardless of how many items it holds. `maxColumns` is reduced
/// automatically on narrow screens to keep values legible.
class _InfoGrid extends StatelessWidget {
  final List<_GridItem> items;
  final int maxColumns;

  const _InfoGrid({required this.items, this.maxColumns = 2});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const minCellWidth = 130.0;
      var columns = maxColumns;
      while (columns > 1 && constraints.maxWidth / columns < minCellWidth) {
        columns--;
      }

      final rows = <List<_GridItem?>>[];
      for (var i = 0; i < items.length; i += columns) {
        rows.add(List.generate(columns, (c) => i + c < items.length ? items[i + c] : null));
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CalColors.surfaceLowest,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: CalColors.outlineVariant),
        ),
        child: Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: CalColors.outlineVariant),
                const SizedBox(height: 14),
              ],
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) ...[
                        const SizedBox(width: 14),
                        VerticalDivider(width: 1, color: CalColors.outlineVariant),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: rows[r][c] == null ? const SizedBox.shrink() : _InfoCell(item: rows[r][c]!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _InfoCell extends StatelessWidget {
  final _GridItem item;

  const _InfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 12, color: CalColors.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                item.label,
                style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          item.value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()]),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

IconData _statusIcon(TestStatus status) {
  switch (status) {
    case TestStatus.passed: return Icons.check_circle;
    case TestStatus.failed: return Icons.cancel;
    case TestStatus.unsupported: return Icons.help_outline;
    case TestStatus.running: return Icons.hourglass_top;
    case TestStatus.idle: return Icons.circle_outlined;
  }
}

Color _statusColor(TestStatus status) {
  switch (status) {
    case TestStatus.passed: return CalColors.accent;
    case TestStatus.failed: return CalColors.error;
    case TestStatus.unsupported: return CalColors.onSecondaryContainer;
    case TestStatus.running: return CalColors.primary;
    case TestStatus.idle: return CalColors.outline;
  }
}

class _TestResultsCard extends StatelessWidget {
  final List<ComponentTest> tests;

  const _TestResultsCard({required this.tests});

  @override
  Widget build(BuildContext context) {
    final doneTests = tests.where((t) => t.status != TestStatus.idle).toList();
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: doneTests.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Henüz test çalıştırılmadı. Tanılama sekmesinden testleri başlatın.', style: TextStyle(color: CalColors.onSurfaceVariant, fontSize: 13), textAlign: TextAlign.center),
            )
          : Column(
              children: List.generate(doneTests.length, (i) {
                final t = doneTests[i];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: TextStyle(fontSize: 14, color: CalColors.onSurface),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(_statusIcon(t.status), color: _statusColor(t.status), size: 22),
                        ],
                      ),
                    ),
                    if (i < doneTests.length - 1) Divider(height: 1, indent: 14, color: CalColors.outlineVariant),
                  ],
                );
              }),
            ),
    );
  }
}

class _OperatorNotes extends StatelessWidget {
  final TextEditingController controller;

  const _OperatorNotes({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: CalColors.primary, width: 3)),
          color: CalColors.surfaceLow,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        child: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 3,
          style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant, height: 1.5),
          decoration: const InputDecoration(
            hintText: 'Yapılan işlem ve gözlemleri buraya yazın (rapora ve PDF çıktısına eklenir)...',
            hintStyle: TextStyle(fontStyle: FontStyle.italic),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
