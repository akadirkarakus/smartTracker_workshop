import 'package:flutter/material.dart';
import '../../bluetooth/models/log_entry.dart';
import '../../core/app_logger.dart';
import '../../kline/kline_codec.dart';
import '../../kline/kline_records.dart';
import '../../kline/kline_service.dart';
import '../../models/calibration_data.dart';

class OptionalSettingsScreen extends StatefulWidget {
  final OptionalSettings settings;
  final VoidCallback onChanged;
  final KLineService? klineService;
  final String? deviceHwNumber;

  const OptionalSettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    this.klineService,
    this.deviceHwNumber,
  });

  @override
  State<OptionalSettingsScreen> createState() => _OptionalSettingsScreenState();
}

class _OptionalSettingsScreenState extends State<OptionalSettingsScreen> {
  late final OptionalSettings _s;
  late final bool _isStc8255;
  bool _isSaving = false;
  bool _isLoading = false;

  // Bağlı cihaz kesin olarak STC8250 ise "Yalnızca STC8255" alanları düzenlenemez.
  bool get _disableAdvanced => widget.klineService != null && !_isStc8255;

  // Askeri Dimmer yalnızca STC8250'de tanımlı bir K-Line kaydı.
  bool get _disableMilitaryDimmer => widget.klineService != null && _isStc8255;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _isStc8255 = widget.deviceHwNumber?.toUpperCase().contains('8255') ?? false;
    if (widget.klineService != null) {
      _loadFromDevice();
    }
  }

  Future<void> _loadFromDevice() async {
    final service = widget.klineService;
    if (service == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await service.readOptionalSettings(isStc8255: _isStc8255);
      if (!mounted) return;
      setState(() {
        _s.speedometerFactor = snap.speedometerFactor?.toString() ?? _s.speedometerFactor;
        _s.b7Recognize = snap.b7Recognize ?? _s.b7Recognize;
        _s.militaryDimmer = snap.militaryDimmer ?? _s.militaryDimmer;
        _s.overspeedPrewarningTime = snap.overspeedPrewarningTime ?? _s.overspeedPrewarningTime;
        _s.ignitionOption = snap.ignitionOption ?? _s.ignitionOption;
        _s.distanceUnit = snap.distanceUnit ?? _s.distanceUnit;
        _s.tripMeterReset = snap.tripMeterReset ?? _s.tripMeterReset;
        _s.imsSource = snap.imsSource ?? _s.imsSource;
        _s.canABaudrate = snap.canABaudrate ?? _s.canABaudrate;
        _s.canCBaudrate = snap.canCBaudrate ?? _s.canCBaudrate;
        _s.gnssAntenna = snap.gnssAntenna ?? _s.gnssAntenna;
        _s.periodicDags = snap.periodicDags ?? _s.periodicDags;
        _s.cardExistenceWarning = snap.cardExistenceWarning ?? _s.cardExistenceWarning;
      });
    } catch (e) {
      AppLogger.instance.log(
        'Optional settings read error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Değişken/hâlihazırdaki değerleri (donanıma göre doğru kayıt ID'siyle) K-Line yazım listesine çevirir.
  List<MapEntry<int, List<int>>> _fieldsToWrite() {
    final entries = <MapEntry<int, List<int>>>[];
    void add(int recordId, List<int>? bytes) {
      if (bytes != null) entries.add(MapEntry(recordId, bytes));
    }

    add(
      _isStc8255 ? KLineRecords.fd11SpeedometerFactor8255 : KLineRecords.fd00SpeedometerFactor,
      _s.speedometerFactor == null ? null : KLineCodec.encodeSpeedometerFactor(int.parse(_s.speedometerFactor!)),
    );
    add(
      _isStc8255 ? KLineRecords.fd1cB7Recognize8255 : KLineRecords.fd01B7Recognize,
      _s.b7Recognize == null ? null : KLineCodec.encodeEnabledByte(_s.b7Recognize!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1aOverspeedPrewarningTime8255 : KLineRecords.fd06OverspeedPrewarningTime,
      _s.overspeedPrewarningTime == null ? null : KLineCodec.encodeOverspeedPrewarningSeconds(_s.overspeedPrewarningTime!),
    );
    add(
      _isStc8255 ? KLineRecords.fd18IgnitionOptions8255 : KLineRecords.fd07IgnitionOptions,
      _s.ignitionOption == null ? null : KLineCodec.encodeIgnitionOption(_s.ignitionOption!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1eDistanceUnit8255 : KLineRecords.fd0bDistanceUnit,
      _s.distanceUnit == null ? null : KLineCodec.encodeDistanceUnit(_s.distanceUnit!),
    );
    add(
      _isStc8255 ? KLineRecords.fd3bTripmeterReset8255 : KLineRecords.fd11TripmeterReset,
      _s.tripMeterReset == null ? null : KLineCodec.encodeEnabledByte(_s.tripMeterReset!),
    );
    add(
      _isStc8255 ? KLineRecords.fd17ImsSource8255 : KLineRecords.fd0fImsSource,
      _s.imsSource == null ? null : KLineCodec.encodeImsSource(_s.imsSource!),
    );
    add(
      _isStc8255 ? KLineRecords.fd32CanABaudrate8255 : KLineRecords.fd08CanABaudrate,
      _s.canABaudrate == null ? null : KLineCodec.encodeCanBaudrate(_s.canABaudrate!),
    );
    add(
      _isStc8255 ? KLineRecords.fd35CanCBaudrate8255 : KLineRecords.fd09CanCBaudrate,
      _s.canCBaudrate == null ? null : KLineCodec.encodeCanBaudrate(_s.canCBaudrate!),
    );

    // STC8250'ye özel — 8255'te bu kayıt ID'si tanımlı değil.
    if (!_isStc8255) {
      add(KLineRecords.fd04MilitaryDimmer, _s.militaryDimmer == null ? null : KLineCodec.encodeMilitaryDimmer(_s.militaryDimmer!));
    }

    // STC8255'e özel — 8250'de bu kayıt ID'leri tanımlı değil.
    if (_isStc8255) {
      add(KLineRecords.fd53GnssAntenna8255, _s.gnssAntenna == null ? null : KLineCodec.encodeGnssAntenna(_s.gnssAntenna!));
      add(KLineRecords.fd41PeriodicDags8255, _s.periodicDags == null ? null : KLineCodec.encodeEnabledByte(_s.periodicDags!));
      add(KLineRecords.fd51CardExistenceWarning8255, _s.cardExistenceWarning == null ? null : KLineCodec.encodeCardExistenceWarning(_s.cardExistenceWarning!));
    }

    return entries;
  }

  Future<void> _save() async {
    final service = widget.klineService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cihaz bağlı değil — değişiklikler K-Line\'a yazılamadı'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final field in _fieldsToWrite()) {
        await service.writeParameter(field.key, field.value);
      }
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opsiyonel ayarlar kaydedildi'),
          backgroundColor: CalColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.instance.log(
        'Optional settings write error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yazma hatası: $e'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CalColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Opsiyonel Ayarlar', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: _isLoading
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CalColors.primary)),
                  ),
                ),
              ]
            : null,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: 'Ortak Ayarlar', tag: 'STC8250 / STC8255'),
            const SizedBox(height: 8),
            _SettingsCard(children: [
              _NumberRow(
                label: 'Hız Göstergesi Faktörü',
                value: _s.speedometerFactor ?? '—',
                onEdit: () => _showEditDialog('Hız Göstergesi Faktörü', _s.speedometerFactor ?? '', (v) => setState(() => _s.speedometerFactor = v)),
              ),
              _ToggleRow(
                label: 'B7 Tanıma',
                value: _s.b7Recognize ?? false,
                onChanged: (v) => setState(() => _s.b7Recognize = v),
              ),
              Opacity(
                opacity: _disableMilitaryDimmer ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: _disableMilitaryDimmer,
                  child: _ToggleRow(
                    label: 'Askeri Dimmer',
                    value: _s.militaryDimmer ?? false,
                    onChanged: (v) => setState(() => _s.militaryDimmer = v),
                  ),
                ),
              ),
              _NumberRow(
                label: 'Aşırı Hız Ön Uyarı Süresi',
                value: '${_s.overspeedPrewarningTime ?? 0} sn',
                onEdit: () => _showEditDialog('Ön Uyarı Süresi (sn)', (_s.overspeedPrewarningTime ?? 0).toString(), (v) {
                  final n = int.tryParse(v);
                  if (n != null) setState(() => _s.overspeedPrewarningTime = n);
                }),
              ),
              _SelectRow(
                label: 'Kontak Seçeneği',
                value: _s.ignitionOption ?? 'Sürücü',
                options: const ['Sürücü', 'Ko-Pilot'],
                onSelect: (v) => setState(() => _s.ignitionOption = v),
              ),
              _SelectRow(
                label: 'Mesafe Birimi',
                value: _s.distanceUnit ?? 'km',
                options: const ['km', 'Mil'],
                onSelect: (v) => setState(() => _s.distanceUnit = v),
              ),
              _ToggleRow(
                label: 'Tripmetre Sıfırlama',
                value: _s.tripMeterReset ?? false,
                onChanged: (v) => setState(() => _s.tripMeterReset = v),
              ),
              _SelectRow(
                label: 'IMS Kaynağı',
                value: _s.imsSource ?? 'CAN A',
                options: const ['CAN A', 'CAN C', 'Devre Dışı'],
                onSelect: (v) => setState(() => _s.imsSource = v),
              ),
              _SelectRow(
                label: 'CAN A Baud Hızı',
                value: _s.canABaudrate ?? '250 kbps',
                options: const ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'],
                onSelect: (v) => setState(() => _s.canABaudrate = v),
              ),
              _SelectRow(
                label: 'CAN C Baud Hızı',
                value: _s.canCBaudrate ?? '250 kbps',
                options: const ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'],
                onSelect: (v) => setState(() => _s.canCBaudrate = v),
              ),
            ]),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Gelişmiş Ayarlar', tag: 'Yalnızca STC8255'),
            const SizedBox(height: 8),
            Opacity(
              opacity: _disableAdvanced ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _disableAdvanced,
                child: _SettingsCard(children: [
                  _SelectRow(
                    label: 'GNSS Anten',
                    value: _s.gnssAntenna ?? 'İç',
                    options: const ['İç', 'Dış'],
                    onSelect: (v) => setState(() => _s.gnssAntenna = v),
                  ),
                  _ToggleRow(
                    label: 'Periyodik DAGS',
                    value: _s.periodicDags ?? false,
                    onChanged: (v) => setState(() => _s.periodicDags = v),
                  ),
                  _ToggleRow(
                    label: 'Kart Var/Yok Uyarı Çıkışı',
                    value: _s.cardExistenceWarning ?? false,
                    onChanged: (v) => setState(() => _s.cardExistenceWarning = v),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CalColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CalColors.outlineVariant),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: CalColors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'STC8255\'e özel ayarlar STC8250 donanımında "GEÇERSİZ" olarak gösterilir ve yazılamaz.',
                      style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Kaydediliyor...' : 'Tüm Değişiklikleri Kaydet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String label, String initial, void Function(String) onSave) {
    final controller = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable row widgets ──────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String tag;

  const _SectionHeader({required this.title, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalColors.outline, letterSpacing: 0.8)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: CalColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
          child: Text(tag, style: const TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1) const Divider(height: 1, indent: 16, endIndent: 0, color: CalColors.outlineVariant),
            ],
          );
        }),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: CalColors.onSurface))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: CalColors.accent,
            activeTrackColor: CalColors.accent.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final void Function(String) onSelect;

  const _SelectRow({required this.label, required this.value, required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: CalColors.onSurface))),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) { if (v != null) onSelect(v); },
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _NumberRow({required this.label, required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: CalColors.onSurface))),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CalColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CalColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: const TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14, color: CalColors.outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
