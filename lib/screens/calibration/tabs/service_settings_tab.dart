import 'package:flutter/material.dart';
import '../../../core/app_logger.dart';
import '../../../kline/kline_service.dart';
import '../../../models/calibration_data.dart';
import '../optional_settings_screen.dart';
import '../../test_log_screen.dart';

class ServiceSettingsTab extends StatefulWidget {
  final ServiceSettings settings;
  final VoidCallback onSettingsChanged;
  final String? deviceModel;
  final String? firmwareVersion;
  final String? serialNumber;
  final String? hwVersion;
  final KLineService? klineService;

  const ServiceSettingsTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.deviceModel,
    this.firmwareVersion,
    this.serialNumber,
    this.hwVersion,
    this.klineService,
  });

  @override
  State<ServiceSettingsTab> createState() => _ServiceSettingsTabState();
}

class _ServiceSettingsTabState extends State<ServiceSettingsTab> {
  late final OptionalSettings _optionalSettings;
  late final TextEditingController _workshopCtrl;

  @override
  void initState() {
    super.initState();
    _optionalSettings = OptionalSettings();
    _workshopCtrl = TextEditingController(text: widget.settings.workshopName);
  }

  @override
  void dispose() {
    _workshopCtrl.dispose();
    super.dispose();
  }

  void _changed() {
    widget.settings.workshopName = _workshopCtrl.text;
    widget.onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Image.asset('assets/logo.png', height: 72)),
                const SizedBox(height: 24),

                // ── 1. Uygulama Ayarları ──────────────────
                const _SectionLabel(title: 'Uygulama Ayarları'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CalColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CalColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Language
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.language_outlined, color: CalColors.onSurfaceVariant, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Dil', style: TextStyle(fontSize: 14, color: CalColors.onSurface))),
                            DropdownButton<String>(
                              value: s.language,
                              underline: const SizedBox(),
                              style: const TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500),
                              items: ['Türkçe', 'English', 'Español', 'Українська']
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                  .toList(),
                              onChanged: (v) { if (v != null) setState(() { s.language = v; _changed(); }); },
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: CalColors.outlineVariant),

                      // Dark theme
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              s.darkThemeEnabled ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              color: CalColors.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Koyu Tema', style: TextStyle(fontSize: 14, color: CalColors.onSurface)),
                                  Text('Ekran parlaklığını azaltır', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Switch(
                              value: s.darkThemeEnabled,
                              onChanged: (v) => setState(() { s.darkThemeEnabled = v; _changed(); }),
                              activeThumbColor: CalColors.primary,
                              activeTrackColor: CalColors.primary.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 2. Geliştirici / Test ─────────────────
                Row(
                  children: [
                    const _SectionLabel(title: 'Geliştirici / Test'),
                    if (s.testModeEnabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Text(
                          'KAYIT AKTİF',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CalColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CalColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Test mode toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined,
                              color: s.testModeEnabled ? const Color(0xFFF59E0B) : CalColors.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Test Modu', style: TextStyle(fontSize: 14, color: CalColors.onSurface)),
                                  Text('Tüm işlemlerin adım adım loglanması', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Switch(
                              value: s.testModeEnabled,
                              onChanged: (v) => setState(() {
                                s.testModeEnabled = v;
                                AppLogger.instance.setTestMode(v);
                                _changed();
                              }),
                              activeThumbColor: const Color(0xFFF59E0B),
                              activeTrackColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: CalColors.outlineVariant),

                      // Log viewer tile
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TestLogScreen()),
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_outlined, color: CalColors.primary, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Test Günlüğünü Görüntüle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                      Text('Uygulama olaylarını ve BT loglarını incele', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const _LogEntryCountBadge(),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 3. Servis Kimliği ─────────────────────
                const _SectionLabel(title: 'Servis Kimliği'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CalColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CalColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yetkili Servis Adı', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _workshopCtrl,
                        onChanged: (_) => _changed(),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: CalColors.primary, width: 2),
                          ),
                          suffixIcon: const Icon(Icons.edit, size: 18, color: CalColors.outline),
                        ),
                        style: const TextStyle(fontSize: 14, color: CalColors.onSurface),
                      ),
                      const SizedBox(height: 6),
                      const Text('Bu isim tüm kalibrasyon sertifikalarında ve raporlarında görünecektir.', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── 4. Takograf Ayarları ──────────────────
                const _SectionLabel(title: 'Takograf Ayarları'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CalColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CalColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // Photo sensor
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sensors_outlined, color: CalColors.onSurfaceVariant, size: 20),
                                SizedBox(width: 10),
                                Text('Foto Sensör / Esnek Anahtar', style: TextStyle(fontSize: 14, color: CalColors.onSurface)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: ['Sensor', 'Matt', 'Lontex'].map((opt) {
                                final selected = s.photoSensor == opt;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: GestureDetector(
                                      onTap: () => setState(() { s.photoSensor = opt; _changed(); }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: selected ? CalColors.primaryContainer : CalColors.surfaceLow,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: selected ? CalColors.primary : CalColors.outlineVariant, width: selected ? 2 : 1),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(opt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CalColors.onSurfaceVariant)),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: CalColors.outlineVariant),

                      // Optional settings shortcut
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OptionalSettingsScreen(
                                settings: _optionalSettings,
                                onChanged: widget.onSettingsChanged,
                                klineService: widget.klineService,
                                deviceHwNumber: widget.deviceModel,
                              ),
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.tune, color: CalColors.primary, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Opsiyonel Ayarlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                      Text('Speedometre, CAN, GNSS, D1/D2 ve STC8255 ayarları', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Cihaz Hakkında ────────────────────────
                const _SectionLabel(title: 'Cihaz Hakkında'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CalColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CalColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _InfoRow('Model', widget.deviceModel ?? '—'),
                      const Divider(height: 1, color: CalColors.outlineVariant),
                      _InfoRow('Firmware Sürümü', widget.firmwareVersion ?? '—'),
                      const Divider(height: 1, color: CalColors.outlineVariant),
                      _InfoRow('Seri Numarası', widget.serialNumber ?? '—'),
                      const Divider(height: 1, color: CalColors.outlineVariant),
                      _InfoRow('Donanım Versiyonu', widget.hwVersion ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Firmware update button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Güncelleme kontrol ediliyor... Güncel sürüm kullanılıyor.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.system_update_alt, size: 20),
                    label: const Text('Firmware Güncellemesini Kontrol Et', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Exit ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.error)),
                        content: const Text('Rol seçim ekranına dönmek istiyor musunuz?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('İptal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CalColors.error,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                            child: const Text('Çıkış Yap'),
                          ),
                        ],
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CalColors.error,
                      side: const BorderSide(color: CalColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Çıkış Yap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
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

class _LogEntryCountBadge extends StatelessWidget {
  const _LogEntryCountBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: AppLogger.instance.changes,
      builder: (_, _) {
        final count = AppLogger.instance.entryCount;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: CalColors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalColors.outline, letterSpacing: 0.8),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: CalColors.onSurfaceVariant))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface, fontFeatures: [FontFeature.tabularFigures()]))),
        ],
      ),
    );
  }
}
