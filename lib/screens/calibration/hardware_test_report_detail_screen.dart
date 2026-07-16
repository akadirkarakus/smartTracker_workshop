import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../models/calibration_data.dart';
import '../../models/hardware_test_report.dart';
import 'hardware_test_ui.dart';
import 'report_pdf.dart';

class HardwareTestReportDetailScreen extends StatelessWidget {
  const HardwareTestReportDetailScreen({super.key, required this.report});
  final HardwareTestReport report;

  Future<void> _share(BuildContext context) async {
    final bytes = await buildHardwareTestReportPdf(report);
    await Printing.sharePdf(bytes: bytes, filename: 'donanim_testi_${report.id}.pdf');
  }

  Future<void> _print(BuildContext context) async {
    final bytes = await buildHardwareTestReportPdf(report);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  void _copyLog(BuildContext context) {
    Clipboard.setData(ClipboardData(text: report.toLogText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rapor günlüğü panoya kopyalandı'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final byCategory = <HwTestItemCategory, List<HardwareTestItemResult>>{};
    for (final item in report.items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Rapor — ${_fmtDate(report.finishedAt)}',
            style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.copy_outlined, color: CalColors.primary),
            tooltip: 'Panoya kopyala',
            onPressed: () => _copyLog(context),
          ),
          IconButton(icon: Icon(Icons.print_outlined, color: CalColors.primary), onPressed: () => _print(context)),
          IconButton(icon: Icon(Icons.ios_share, color: CalColors.primary), onPressed: () => _share(context)),
        ],
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: report.hasFailure ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: report.hasFailure ? CalColors.error : const Color(0xFF16A34A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.hasFailure ? 'Bazı adımlar başarısız oldu' : 'Kritik hata yok',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: report.hasFailure ? CalColors.error : const Color(0xFF166534)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cihaz: ${report.deviceModel ?? '—'}  •  Seri: ${report.deviceSerial ?? '—'}  •  '
                  'PIN: ${report.pinAuthenticatedDuringRun ? 'Doğrulandı' : 'Doğrulanmadı'}',
                  style: TextStyle(fontSize: 11.5, color: CalColors.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  'Geçti: ${report.passCount}  ·  Başarısız: ${report.failCount}  ·  '
                  'Görsel Onay: ${report.visualConfirmCount}  ·  İletişim OK: ${report.commsOkUnverifiedCount}  ·  '
                  'Atlandı: ${report.skippedCount}',
                  style: TextStyle(fontSize: 11.5, color: CalColors.onSurface),
                ),
              ],
            ),
          ),
          for (final category in byCategory.keys) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                _categoryLabel(category).toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalColors.outline, letterSpacing: 0.6),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: CalColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CalColors.outlineVariant),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < byCategory[category]!.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: CalColors.outlineVariant),
                    HwTestItemTile(item: byCategory[category]![i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _categoryLabel(HwTestItemCategory category) {
    switch (category) {
      case HwTestItemCategory.calParamRead:
        return 'Kalibrasyon Parametreleri — Okuma';
      case HwTestItemCategory.calParamWriteVerify:
        return 'Kalibrasyon Parametreleri — Yaz-Doğrula';
      case HwTestItemCategory.optionalSettingRead:
        return 'Opsiyonel Ayarlar — Okuma';
      case HwTestItemCategory.dtcCountRead:
      case HwTestItemCategory.dtcCodesRead:
        return 'DTC Servisleri';
      case HwTestItemCategory.componentAutoResult:
        return 'Bileşen Testleri — Otomatik Sonuçlu';
      case HwTestItemCategory.componentVisualConfirm:
        return 'Bileşen Testleri — Görsel Onay Gerekli';
      case HwTestItemCategory.componentNoResult:
        return 'Bileşen Testleri — Gözlemlenemez';
    }
  }
}
