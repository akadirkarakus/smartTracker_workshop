// Donanım Testi ekranları arası paylaşılan durum → renk/ikon/etiket eşlemesi.

import 'package:flutter/material.dart';
import '../../models/calibration_data.dart';
import '../../models/hardware_test_report.dart';

Color hwStatusColor(HwTestStatus status) {
  switch (status) {
    case HwTestStatus.pass:
      return const Color(0xFF16A34A);
    case HwTestStatus.fail:
      return CalColors.error;
    case HwTestStatus.visualConfirmRequired:
      return const Color(0xFF2563EB);
    case HwTestStatus.skipped:
      return CalColors.outline;
    case HwTestStatus.commsOkResultUnverified:
      return const Color(0xFFF59E0B);
  }
}

IconData hwStatusIcon(HwTestStatus status) {
  switch (status) {
    case HwTestStatus.pass:
      return Icons.check_circle;
    case HwTestStatus.fail:
      return Icons.cancel;
    case HwTestStatus.visualConfirmRequired:
      return Icons.visibility;
    case HwTestStatus.skipped:
      return Icons.remove_circle_outline;
    case HwTestStatus.commsOkResultUnverified:
      return Icons.help;
  }
}

String hwStatusLabel(HwTestStatus status) => status.label;

Widget hwStatusChip(HwTestStatus status) {
  final color = hwStatusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(hwStatusIcon(status), size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          hwStatusLabel(status),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}

class HwTestItemTile extends StatelessWidget {
  const HwTestItemTile({super.key, required this.item});
  final HardwareTestItemResult item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                const SizedBox(height: 2),
                Text(item.detail, style: TextStyle(fontSize: 11.5, color: CalColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          hwStatusChip(item.status),
        ],
      ),
    );
  }
}
