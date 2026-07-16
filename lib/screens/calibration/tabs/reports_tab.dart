import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../models/calibration_data.dart';
import '../report_pdf.dart';

class ReportsTab extends StatefulWidget {
  final List<CalParam> params;
  final List<ComponentTest> tests;
  final String? deviceModel;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? hwVersion;
  final String? workshopName;

  const ReportsTab({
    super.key,
    required this.params,
    required this.tests,
    this.deviceModel,
    this.serialNumber,
    this.firmwareVersion,
    this.hwVersion,
    this.workshopName,
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary header
                _ReportSummaryCard(plate: values['Plaka (VRN)']!, hasFailure: hasFailure, anyTestRan: anyTestRan),
                const SizedBox(height: 14),

                // Calibration parameters
                _SectionHeader(title: 'Kalibrasyon Parametreleri', icon: Icons.settings_input_component),
                const SizedBox(height: 8),
                _ParamGrid(items: [
                  for (final e in values.entries) _GridItem(e.key, e.value),
                ]),
                const SizedBox(height: 14),

                // Test results
                _SectionHeader(title: 'Test Sonuçları', icon: Icons.fact_check_outlined),
                const SizedBox(height: 8),
                _TestResultsCard(tests: tests),
                const SizedBox(height: 14),

                // Hardware & workshop info (in a row)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _HardwareCard(
                      deviceModel: widget.deviceModel,
                      serialNumber: widget.serialNumber,
                      firmwareVersion: widget.firmwareVersion,
                      hwVersion: widget.hwVersion,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _WorkshopCard(workshopName: widget.workshopName)),
                  ],
                ),
                const SizedBox(height: 14),

                // Operator notes
                _SectionHeader(title: 'Operatör Notları', icon: Icons.description_outlined),
                const SizedBox(height: 8),
                _OperatorNotes(controller: _notesController),
                const SizedBox(height: 20),

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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────

class _ReportSummaryCard extends StatelessWidget {
  final String plate;
  final bool hasFailure;
  final bool anyTestRan;

  const _ReportSummaryCard({required this.plate, required this.hasFailure, required this.anyTestRan});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plate, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: CalColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Oluşturuldu: $dateStr',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(badgeIcon, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(badgeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
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
        Icon(icon, color: CalColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.primary)),
      ],
    );
  }
}

class _GridItem {
  final String label;
  final String value;

  const _GridItem(this.label, this.value);
}

class _ParamGrid extends StatelessWidget {
  final List<_GridItem> items;

  const _ParamGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 14,
        children: items.map((item) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 80) / 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(item.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          );
        }).toList(),
      ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: doneTests.isEmpty
          ? Padding(
              padding: EdgeInsets.all(20),
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

class _HardwareCard extends StatelessWidget {
  final String? deviceModel;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? hwVersion;

  const _HardwareCard({
    this.deviceModel,
    this.serialNumber,
    this.firmwareVersion,
    this.hwVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering_outlined, color: CalColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Donanım', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          _HwRow('Takograf', deviceModel ?? '—'),
          _HwRow('Seri No', serialNumber ?? '—'),
          _HwRow('FW', firmwareVersion ?? '—'),
          _HwRow('HW Rev', hwVersion ?? '—'),
        ],
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final String? workshopName;

  const _WorkshopCard({this.workshopName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_outlined, color: CalColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Servis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          _HwRow('Servis', workshopName ?? '—'),
        ],
      ),
    );
  }
}

class _HwRow extends StatelessWidget {
  final String label;
  final String value;

  const _HwRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: CalColors.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
        ],
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
        borderRadius: BorderRadius.circular(12),
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
