import 'package:flutter/material.dart';
import '../../models/calibration_data.dart';
import '../../models/hardware_test_report.dart';
import '../../services/hardware_test_report_store.dart';
import 'hardware_test_report_detail_screen.dart';

class HardwareTestReportsScreen extends StatefulWidget {
  const HardwareTestReportsScreen({super.key});

  @override
  State<HardwareTestReportsScreen> createState() => _HardwareTestReportsScreenState();
}

class _HardwareTestReportsScreenState extends State<HardwareTestReportsScreen> {
  List<HardwareTestReport>? _reports;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await HardwareTestReportStore.loadAll();
    if (!mounted) return;
    setState(() => _reports = reports);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Donanım Testi Raporları', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: _reports == null
          ? const Center(child: CircularProgressIndicator())
          : _reports!.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fact_check_outlined, size: 48, color: CalColors.outline),
                        const SizedBox(height: 12),
                        Text('Henüz kaydedilmiş bir donanım testi raporu yok.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: CalColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ReportCard(
                    report: _reports![i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HardwareTestReportDetailScreen(report: _reports![i])),
                    ),
                  ),
                ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final HardwareTestReport report;
  final VoidCallback onTap;

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final statusColor = report.hasFailure ? CalColors.error : const Color(0xFF16A34A);
    return Material(
      color: CalColors.surfaceLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CalColors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmtDate(report.finishedAt), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CalColors.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      report.deviceModel ?? 'Bilinmeyen cihaz',
                      style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Geçti: ${report.passCount}  ·  Başarısız: ${report.failCount}  ·  '
                      'Görsel Onay: ${report.visualConfirmCount}  ·  Atlandı: ${report.skippedCount}',
                      style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
