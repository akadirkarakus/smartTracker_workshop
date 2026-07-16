import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../../models/calibration_data.dart';
import '../../models/hardware_test_report.dart';

class ReportPdfData {
  final String plate;
  final DateTime generatedAt;
  final Map<String, String> paramValues; // label -> display value
  final List<ComponentTest> tests;
  final String? deviceModel;
  final String? serialNumber;
  final String? firmwareVersion;
  final String? hwVersion;
  final String? workshopName;
  final String operatorNotes;
  final bool hasFailure;
  final bool anyTestRan;

  const ReportPdfData({
    required this.plate,
    required this.generatedAt,
    required this.paramValues,
    required this.tests,
    required this.operatorNotes,
    required this.hasFailure,
    required this.anyTestRan,
    this.deviceModel,
    this.serialNumber,
    this.firmwareVersion,
    this.hwVersion,
    this.workshopName,
  });
}

Future<Uint8List> buildCalibrationReportPdf(ReportPdfData data) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

  final statusLabel = data.hasFailure
      ? 'BAŞARISIZ'
      : (data.anyTestRan ? 'BAŞARILI' : 'TEST BEKLENİYOR');
  final statusColor = data.hasFailure
      ? PdfColors.red700
      : (data.anyTestRan ? PdfColors.teal700 : PdfColors.grey600);

  final dateStr = '${data.generatedAt.day.toString().padLeft(2, '0')}/'
      '${data.generatedAt.month.toString().padLeft(2, '0')}/${data.generatedAt.year} '
      '${data.generatedAt.hour.toString().padLeft(2, '0')}:${data.generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(data.plate, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Oluşturuldu: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(color: statusColor, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(statusLabel, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        _sectionTitle('Kalibrasyon Parametreleri'),
        pw.SizedBox(height: 6),
        _paramTable(data.paramValues),
        pw.SizedBox(height: 16),

        _sectionTitle('Test Sonuçları'),
        pw.SizedBox(height: 6),
        _testResultsTable(data.tests),
        pw.SizedBox(height: 16),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _infoBox('Donanım', {
              'Takograf': data.deviceModel ?? '—',
              'Seri No': data.serialNumber ?? '—',
              'FW': data.firmwareVersion ?? '—',
              'HW Rev': data.hwVersion ?? '—',
            })),
            pw.SizedBox(width: 10),
            pw.Expanded(child: _infoBox('Servis', {
              'Servis': data.workshopName ?? '—',
            })),
          ],
        ),
        pw.SizedBox(height: 16),

        _sectionTitle('Operatör Notları'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: const pw.Border(left: pw.BorderSide(color: PdfColors.teal700, width: 3)),
            color: PdfColors.grey100,
          ),
          child: pw.Text(
            data.operatorNotes.trim().isEmpty ? '—' : data.operatorNotes.trim(),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _sectionTitle(String title) =>
    pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900));

pw.Widget _paramTable(Map<String, String> values) {
  final entries = values.entries.toList();
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
    children: [
      for (var i = 0; i < entries.length; i += 2)
        pw.TableRow(children: [
          _paramCell(entries[i].key, entries[i].value),
          i + 1 < entries.length ? _paramCell(entries[i + 1].key, entries[i + 1].value) : pw.Container(),
        ]),
    ],
  );
}

pw.Widget _paramCell(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

pw.Widget _testResultsTable(List<ComponentTest> tests) {
  final done = tests.where((t) => t.status != TestStatus.idle).toList();
  if (done.isEmpty) {
    return pw.Text('Henüz test çalıştırılmadı.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600));
  }
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1)},
    children: [
      for (final t in done)
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(t.name, style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              _statusLabel(t.status),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _statusColor(t.status)),
            ),
          ),
        ]),
    ],
  );
}

String _statusLabel(TestStatus status) {
  switch (status) {
    case TestStatus.passed: return 'Geçti';
    case TestStatus.failed: return 'Başarısız';
    case TestStatus.unsupported: return 'Desteklenmiyor';
    case TestStatus.running: return 'Çalışıyor';
    case TestStatus.idle: return 'Beklemede';
  }
}

PdfColor _statusColor(TestStatus status) {
  switch (status) {
    case TestStatus.passed: return PdfColors.teal700;
    case TestStatus.failed: return PdfColors.red700;
    case TestStatus.unsupported: return PdfColors.grey600;
    case TestStatus.running: return PdfColors.blue700;
    case TestStatus.idle: return PdfColors.grey600;
  }
}

// ── Donanım Testi raporu ────────────────────────────────────────────────────

Future<Uint8List> buildHardwareTestReportPdf(HardwareTestReport report) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

  final statusLabel = report.hasFailure ? 'BAŞARISIZ ADIM VAR' : 'KRİTİK HATA YOK';
  final statusColor = report.hasFailure ? PdfColors.red700 : PdfColors.teal700;

  final dateStr = '${report.finishedAt.day.toString().padLeft(2, '0')}/'
      '${report.finishedAt.month.toString().padLeft(2, '0')}/${report.finishedAt.year} '
      '${report.finishedAt.hour.toString().padLeft(2, '0')}:${report.finishedAt.minute.toString().padLeft(2, '0')}';

  final byCategory = <HwTestItemCategory, List<HardwareTestItemResult>>{};
  for (final item in report.items) {
    byCategory.putIfAbsent(item.category, () => []).add(item);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Donanım Testi Raporu', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Tamamlandı: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(color: statusColor, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(statusLabel, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        _infoBox('Donanım', {
          'Takograf': report.deviceModel ?? '—',
          'Seri No': report.deviceSerial ?? '—',
          'FW': report.deviceFwVersion ?? '—',
          'HW Rev': report.deviceHwVersion ?? '—',
          'PIN Doğrulaması': report.pinAuthenticatedDuringRun ? 'Evet' : 'Hayır (yazma testleri atlandı)',
        }),
        pw.SizedBox(height: 6),
        pw.Text(
          'Geçti: ${report.passCount}   Başarısız: ${report.failCount}   '
          'Görsel Onay: ${report.visualConfirmCount}   İletişim OK: ${report.commsOkUnverifiedCount}   '
          'Atlandı: ${report.skippedCount}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        for (final category in byCategory.keys) ...[
          _sectionTitle(_hwCategoryLabel(category)),
          pw.SizedBox(height: 6),
          _hwItemsTable(byCategory[category]!),
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );

  return doc.save();
}

String _hwCategoryLabel(HwTestItemCategory category) {
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

pw.Widget _hwItemsTable(List<HardwareTestItemResult> items) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1), 2: pw.FlexColumnWidth(3)},
    children: [
      for (final item in items)
        pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(item.label, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              _hwStatusPdfLabel(item.status),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _hwStatusPdfColor(item.status)),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(item.detail, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
        ]),
    ],
  );
}

String _hwStatusPdfLabel(HwTestStatus status) {
  switch (status) {
    case HwTestStatus.pass: return 'Geçti';
    case HwTestStatus.fail: return 'Başarısız';
    case HwTestStatus.visualConfirmRequired: return 'Görsel Onay Gerekli';
    case HwTestStatus.skipped: return 'Atlandı';
    case HwTestStatus.commsOkResultUnverified: return 'İletişim OK';
  }
}

PdfColor _hwStatusPdfColor(HwTestStatus status) {
  switch (status) {
    case HwTestStatus.pass: return PdfColors.teal700;
    case HwTestStatus.fail: return PdfColors.red700;
    case HwTestStatus.visualConfirmRequired: return PdfColors.blue700;
    case HwTestStatus.skipped: return PdfColors.grey600;
    case HwTestStatus.commsOkResultUnverified: return PdfColors.orange700;
  }
}

pw.Widget _infoBox(String title, Map<String, String> rows) => pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
          pw.SizedBox(height: 6),
          for (final e in rows.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(e.key, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(e.value, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
