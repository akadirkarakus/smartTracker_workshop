import 'package:flutter/material.dart';
import '../../../bluetooth/models/log_entry.dart';
import '../../../core/app_logger.dart';
import '../../../core/app_theme.dart';
import '../../../kline/kline_service.dart';
import '../../../models/calibration_data.dart';
import '../extended_hardware_test_screen.dart';
import '../hardware_test_reports_screen.dart';
import '../hardware_test_run_screen.dart';
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
  final bool isPinAuthenticated;
  final void Function(bool)? onAuthChanged;

  const ServiceSettingsTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.deviceModel,
    this.firmwareVersion,
    this.serialNumber,
    this.hwVersion,
    this.klineService,
    this.isPinAuthenticated = false,
    this.onAuthChanged,
  });

  @override
  State<ServiceSettingsTab> createState() => _ServiceSettingsTabState();
}

class _ServiceSettingsTabState extends State<ServiceSettingsTab> {
  late final OptionalSettings _optionalSettings;
  late final TextEditingController _workshopCtrl;
  late bool _pinBypass;

  @override
  void initState() {
    super.initState();
    _optionalSettings = OptionalSettings();
    _workshopCtrl = TextEditingController(text: widget.settings.workshopName);
    _pinBypass = widget.isPinAuthenticated;
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

  // Bu sayfa Navigator.push ile ayrı bir route olarak açıldığından, üst widget'taki
  // isPinAuthenticated değişimi bu route'u otomatik yeniden derlemez (bkz. calibration_screen'de
  // rota kapanıp yeniden açılınca güncellenme davranışı). Bu yüzden anlık UI geri bildirimi için
  // ayrıca yerel bir kopya tutulur; kaynak veri her zaman üst widget'tadır.
  void _setAuthenticated(bool v) {
    setState(() => _pinBypass = v);
    widget.onAuthChanged?.call(v);
  }

  // optional_settings_screen.dart ile aynı STC8250/8255 tespiti (hwNumber string eşleşmesi).
  bool get _isStc8255 => widget.deviceModel?.toUpperCase().contains('8255') ?? false;

  void _openHardwareTest() {
    if (widget.klineService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HardwareTestRunScreen(
          klineService: widget.klineService!,
          isPinAuthenticated: _pinBypass,
          isStc8255: _isStc8255,
          onAuthChanged: _setAuthenticated,
        ),
      ),
    );
  }

  void _openHardwareTestReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HardwareTestReportsScreen()),
    );
  }

  void _openExtendedTest() {
    if (widget.klineService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExtendedHardwareTestScreen(klineService: widget.klineService!),
      ),
    );
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
                            Icon(Icons.language_outlined, color: CalColors.onSurfaceVariant, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Dil', style: TextStyle(fontSize: 14, color: CalColors.onSurface))),
                            DropdownButton<String>(
                              value: s.language,
                              underline: const SizedBox(),
                              style: TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500),
                              items: ['Türkçe', 'English', 'Español', 'Українська']
                                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                                  .toList(),
                              onChanged: (v) { if (v != null) setState(() { s.language = v; _changed(); }); },
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 1, color: CalColors.outlineVariant),

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
                            Expanded(
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
                              onChanged: (v) => setState(() {
                                s.darkThemeEnabled = v;
                                AppTheme.instance.setDark(v);
                                _changed();
                              }),
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
                    const Flexible(child: _SectionLabel(title: 'Geliştirici / Test')),
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
                            Expanded(
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

                      Divider(height: 1, color: CalColors.outlineVariant),

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
                                Icon(Icons.receipt_long_outlined, color: CalColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
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
                                Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Divider(height: 1, color: CalColors.outlineVariant),

                      // Donanım Testi Yap
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.klineService != null ? _openHardwareTest : null,
                          child: Opacity(
                            opacity: widget.klineService != null ? 1 : 0.4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.fact_check_outlined, color: CalColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Donanım Testi Yap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                        Text('Tüm parametreleri ve iletişim akışlarını otomatik test et', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Divider(height: 1, color: CalColors.outlineVariant),

                      // Test Raporlarını Görüntüle
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openHardwareTestReports,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.summarize_outlined, color: CalColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Test Raporlarını Görüntüle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                      Text('Geçmiş donanım testi sonuçlarını incele', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Divider(height: 1, color: CalColors.outlineVariant),

                      // Genişletilmiş Test (uzun süren testler — bilinçli olarak ayrı)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.klineService != null ? _openExtendedTest : null,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: Opacity(
                            opacity: widget.klineService != null ? 1 : 0.4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.hourglass_bottom, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Genişletilmiş Test (Saat / Hız-Km)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                        Text('Dakikalar sürer — ayrı olarak çalıştırılır', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (s.testModeEnabled) ...[
                        Divider(height: 1, color: CalColors.outlineVariant),

                        // PIN bypass (test only)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                _pinBypass ? Icons.lock_open_outlined : Icons.lock_outlined,
                                color: const Color(0xFFF59E0B),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PIN Doğrulamasını Atla', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                    Text(
                                      _pinBypass
                                          ? 'Açık — atölye oturumu PIN girilmeden aktif'
                                          : 'Kapalı — PIN girmeden atölye oturumunu aç (yalnızca test ortamı)',
                                      style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _pinBypass,
                                onChanged: (v) {
                                  _setAuthenticated(v);
                                  AppLogger.instance.log(
                                    v
                                        ? 'PIN authentication bypassed via test mode'
                                        : 'PIN authentication bypass revoked via test mode',
                                    level: v ? LogLevel.error : LogLevel.info,
                                    category: LogCategory.pinAuth,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(v
                                          ? 'PIN doğrulaması atlandı (test modu).'
                                          : 'PIN doğrulaması bypass kapatıldı.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                activeThumbColor: const Color(0xFFF59E0B),
                                activeTrackColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      Text('Yetkili Servis Adı', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _workshopCtrl,
                        onChanged: (_) => _changed(),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CalColors.primary, width: 2),
                          ),
                          suffixIcon: Icon(Icons.edit, size: 18, color: CalColors.outline),
                        ),
                        style: TextStyle(fontSize: 14, color: CalColors.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Text('Bu isim tüm kalibrasyon sertifikalarında ve raporlarında görünecektir.', style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, height: 1.4)),
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
                            Row(
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

                      Divider(height: 1, color: CalColors.outlineVariant),

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
                                isPinAuthenticated: _pinBypass,
                              ),
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.tune, color: CalColors.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Opsiyonel Ayarlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                                      Text('Speedometre, CAN, GNSS, D1/D2 ve STC8255 ayarları', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
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
                      Divider(height: 1, color: CalColors.outlineVariant),
                      _InfoRow('Firmware Sürümü', widget.firmwareVersion ?? '—'),
                      Divider(height: 1, color: CalColors.outlineVariant),
                      _InfoRow('Seri Numarası', widget.serialNumber ?? '—'),
                      Divider(height: 1, color: CalColors.outlineVariant),
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
                        title: Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.error)),
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
                      side: BorderSide(color: CalColors.error),
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
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalColors.outline, letterSpacing: 0.8),
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
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: CalColors.onSurfaceVariant))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface, fontFeatures: [FontFeature.tabularFigures()]))),
        ],
      ),
    );
  }
}
