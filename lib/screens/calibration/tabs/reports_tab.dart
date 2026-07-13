import 'package:flutter/material.dart';
import '../../../models/calibration_data.dart';

class ReportsTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final paramMap = {for (final p in params) p.id: p};
    String val(String id) => paramMap[id]?.value ?? '—';
    String valWithUnit(String id) {
      final p = paramMap[id];
      if (p == null) return '—';
      final v = p.value;
      if (v == null) return '—';
      return p.unit.isNotEmpty ? '$v ${p.unit}' : v;
    }
    final passedCount = tests.where((t) => t.status == TestStatus.passed).length;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary header
                _ReportSummaryCard(plate: val('vrn')),
                const SizedBox(height: 14),

                // Calibration parameters
                _SectionHeader(title: 'Kalibrasyon Parametreleri', icon: Icons.settings_input_component),
                const SizedBox(height: 8),
                _ParamGrid(items: [
                  _GridItem('Plaka (VRN)', val('vrn')),
                  _GridItem('VIN', val('vin')),
                  _GridItem('Hız Limiti', valWithUnit('speed_limit')),
                  _GridItem('Kilometre', valWithUnit('odometer')),
                  _GridItem('Lastik Boyutu', val('tyre_size')),
                  _GridItem('Lastik Çevresi', valWithUnit('tyre_circ')),
                  _GridItem('K-Sabiti', valWithUnit('k_constant')),
                  _GridItem('W-Sabiti', valWithUnit('w_constant')),
                  _GridItem('Son. Kal. Tarihi', val('next_cal_date')),
                ]),
                const SizedBox(height: 14),

                // Test results
                _SectionHeader(title: 'Test Sonuçları', icon: Icons.fact_check_outlined),
                const SizedBox(height: 8),
                _TestResultsCard(tests: tests, passedCount: passedCount),
                const SizedBox(height: 14),

                // Hardware & workshop info (in a row)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _HardwareCard(
                      deviceModel: deviceModel,
                      serialNumber: serialNumber,
                      firmwareVersion: firmwareVersion,
                      hwVersion: hwVersion,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _WorkshopCard(workshopName: workshopName)),
                  ],
                ),
                const SizedBox(height: 14),

                // Operator notes
                _SectionHeader(title: 'Operatör Notları', icon: Icons.description_outlined),
                const SizedBox(height: 8),
                const _OperatorNotes(),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF Dışa Aktar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: CalColors.primary, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.print, size: 18, color: CalColors.primary),
                          label: const Text('Yazdır', style: TextStyle(color: CalColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
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

  const _ReportSummaryCard({required this.plate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
                Text(plate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: CalColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Oluşturuldu: $dateStr', style: const TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: CalColors.accent, borderRadius: BorderRadius.circular(20)),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('BAŞARILI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.primary)),
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
                Text(item.label, style: const TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(item.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TestResultsCard extends StatelessWidget {
  final List<ComponentTest> tests;
  final int passedCount;

  const _TestResultsCard({required this.tests, required this.passedCount});

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
          ? const Padding(
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
                          Text(t.name, style: const TextStyle(fontSize: 14, color: CalColors.onSurface)),
                          Icon(
                            t.status == TestStatus.passed ? Icons.check_circle : Icons.cancel,
                            color: t.status == TestStatus.passed ? CalColors.accent : CalColors.error,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    if (i < doneTests.length - 1) const Divider(height: 1, indent: 14, color: CalColors.outlineVariant),
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
          const Row(
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
          const Row(
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
          Text(label, style: const TextStyle(fontSize: 10, color: CalColors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
        ],
      ),
    );
  }
}

class _OperatorNotes extends StatelessWidget {
  const _OperatorNotes();

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: CalColors.primary, width: 3)),
          color: CalColors.surfaceLow,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
        ),
        child: const Text(
          '"Standart periyodik muayene gerçekleştirildi. Görsel inceleme sırasında tespit edilen hafif yıpranma nedeniyle sensör kablosu değiştirildi. Tüm kalibrasyon parametreleri ana üniteyle karşılaştırılmış ve AB 561/2006 kapsamındaki yasal toleranslar dahilinde doğrulanmıştır."',
          style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant, fontStyle: FontStyle.italic, height: 1.5),
        ),
      ),
    );
  }
}
