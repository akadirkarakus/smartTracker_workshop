import 'dart:async';

import 'package:flutter/material.dart';
import '../../../bluetooth/models/log_entry.dart';
import '../../../core/app_logger.dart';
import '../../../kline/parameter_validation.dart';
import '../../../models/calibration_data.dart';
import '../edit_parameter_screen.dart';
import '../w_constant_measurement_screen.dart';

const _refreshAttentionThreshold = Duration(minutes: 1);

class CalibrationParamsTab extends StatefulWidget {
  final List<CalParam> params;
  final void Function(String id, String value) onParamChanged;
  final bool isDeviceConnected;
  final bool isSimulated;
  final Future<bool> Function(String paramId, String value)? onWriteParam;
  final Future<bool> Function()? onRefresh;

  const CalibrationParamsTab({
    super.key,
    required this.params,
    required this.onParamChanged,
    required this.isDeviceConnected,
    this.isSimulated = false,
    this.onWriteParam,
    this.onRefresh,
  });

  @override
  State<CalibrationParamsTab> createState() => _CalibrationParamsTabState();
}

class _CalibrationParamsTabState extends State<CalibrationParamsTab> {
  bool _isSaving = false;
  bool _isRefreshing = false;
  bool _needsAttention = false;
  DateTime? _lastRefreshAt;
  Timer? _attentionTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isDeviceConnected) _lastRefreshAt = DateTime.now();
    _attentionTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickAttention());
  }

  @override
  void didUpdateWidget(covariant CalibrationParamsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeviceConnected && !oldWidget.isDeviceConnected) {
      // Yeni bağlantı: veri zaten taze okundu, sayaç sıfırlansın.
      _lastRefreshAt = DateTime.now();
      _needsAttention = false;
    } else if (!widget.isDeviceConnected) {
      _needsAttention = false;
    }
  }

  @override
  void dispose() {
    _attentionTimer?.cancel();
    super.dispose();
  }

  void _tickAttention() {
    if (!widget.isDeviceConnected || _lastRefreshAt == null) return;
    final needsAttention = DateTime.now().difference(_lastRefreshAt!) >= _refreshAttentionThreshold;
    if (needsAttention != _needsAttention) {
      setState(() => _needsAttention = needsAttention);
    }
  }

  Future<void> _refresh() async {
    if (widget.onRefresh == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    final ok = await widget.onRefresh!();
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      if (ok) {
        _lastRefreshAt = DateTime.now();
        _needsAttention = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Veriler takograftan yenilendi' : 'Veri yenileme başarısız'),
        backgroundColor: ok ? CalColors.accent : CalColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _commitAll() async {
    if (widget.onWriteParam == null) return;
    AppLogger.instance.log(
      'Parameter save started (${widget.params.length} parameters)',
      level: LogLevel.info,
      category: LogCategory.calibration,
    );
    setState(() => _isSaving = true);
    int failed = 0;
    final errors = <String>[];
    for (final p in widget.params) {
      if (p.value == null) continue;
      try {
        final ok = await widget.onWriteParam!(p.id, p.value!);
        if (!ok) {
          failed++;
          errors.add('${p.label}: yazma başarısız');
        }
      } on ParamValidationException catch (e) {
        failed++;
        errors.add(e.message);
        AppLogger.instance.log(
          'Validation failed [${p.id}]: ${e.message}',
          level: LogLevel.error,
          category: LogCategory.calibration,
        );
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
      if (failed == 0) {
        AppLogger.instance.log(
          'All parameters written to tachograph',
          level: LogLevel.success,
          category: LogCategory.calibration,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm parametreler takografa yazıldı'),
            backgroundColor: CalColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final detail = errors.take(2).join(' • ');
        final extra = errors.length > 2 ? ' (+${errors.length - 2} tane daha)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failed parametre yazılamadı: $detail$extra'),
            backgroundColor: CalColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openEdit(CalParam param) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditParameterScreen(
          parameter: param,
          onWrite: widget.onWriteParam == null
              ? null
              : (v) async {
                  final ok = await widget.onWriteParam!(param.id, v);
                  if (ok) {
                    AppLogger.instance.log(
                      'Parameter written: ${param.label} = $v',
                      level: LogLevel.success,
                      category: LogCategory.calibration,
                    );
                  }
                  return ok;
                },
        ),
      ),
    );
  }

  void _openWMeasure() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WConstantMeasurementScreen(
          onWriteResult: (v) => widget.onParamChanged('w_constant', v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.isDeviceConnected;
    final vehicleParams = widget.params.where((p) => p.section == CalSection.vehicle).toList();
    final tyreParams    = widget.params.where((p) => p.section == CalSection.tyre).toList();
    final timeParams    = widget.params.where((p) => p.section == CalSection.time).toList();
    final systemParams  = widget.params.where((p) => p.section == CalSection.system).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (connected && widget.onRefresh != null) ...[
                      _RefreshButton(
                        isRefreshing: _isRefreshing,
                        needsAttention: _needsAttention,
                        onTap: _refresh,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ConnectionBadge(isConnected: connected, isSimulated: widget.isSimulated),
                  ],
                ),
                const SizedBox(height: 12),

                if (!connected) ...[
                  const _DisconnectedBanner(),
                  const SizedBox(height: 12),
                ],

                // Status banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: connected ? CalColors.primaryContainer : CalColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build_circle, color: connected ? Colors.white : CalColors.outline, size: 20),
                          const SizedBox(width: 8),
                          Text('Kalibrasyon Durumu', style: TextStyle(color: connected ? Colors.white : CalColors.outline, fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                      Text(connected ? 'Aktif Oturum' : 'Bekleniyor', style: TextStyle(color: connected ? Colors.white70 : CalColors.outline, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // W-Constant measurement shortcut
                _WMeasureCard(enabled: connected, onTap: _openWMeasure),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (connected) ...[
          SliverToBoxAdapter(
            child: _ParamSection(
              title: 'Araç Kimliği',
              tag: 'AKİM-01',
              params: vehicleParams,
              enabled: true,
              onEdit: _openEdit,
            ),
          ),

          SliverToBoxAdapter(
            child: _ParamSection(
              title: 'Lastik & Hareket',
              tag: 'LAS-02',
              params: tyreParams,
              enabled: true,
              onEdit: _openEdit,
            ),
          ),

          SliverToBoxAdapter(
            child: _ParamSection(
              title: 'Zaman & Bölge',
              tag: 'ZMN-03',
              params: timeParams,
              enabled: true,
              onEdit: _openEdit,
            ),
          ),

          SliverToBoxAdapter(
            child: _ParamSection(
              title: 'Sistem & Bakım',
              tag: 'SİS-04',
              params: systemParams,
              enabled: true,
              onEdit: _openEdit,
            ),
          ),
        ] else
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 48, color: CalColors.outline),
                    SizedBox(height: 16),
                    Text(
                      'Parametre verisi yok',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurfaceVariant),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Verileri görmek için Ana Sayfa\'dan bir cihaz bağlayın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: CalColors.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Commit button (only when connected)
        if (connected) SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: widget.isDeviceConnected && !_isSaving ? _commitAll : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _isSaving ? 'Yazılıyor...' : 'Tüm Değişiklikleri Kaydet',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parametreler takografın dahili flash belleğine yazılacaktır.',
                  style: TextStyle(fontSize: 11, color: CalColors.outline),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final bool isRefreshing;
  final bool needsAttention;
  final VoidCallback onTap;

  const _RefreshButton({
    required this.isRefreshing,
    required this.needsAttention,
    required this.onTap,
  });

  static const _attentionColor = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    // 1 dakikadır yenilenmediyse turuncuya döner, animasyon yok.
    final color = needsAttention ? _attentionColor : CalColors.primary;
    return Material(
      color: color.withValues(alpha: needsAttention ? 0.22 : 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isRefreshing ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: isRefreshing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(Icons.refresh, size: 20, color: color),
        ),
      ),
    );
  }
}

class _DisconnectedBanner extends StatelessWidget {
  const _DisconnectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CalColors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: CalColors.onSecondaryContainer, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bu sekmedeki işlemler için önce Bluetooth cihaz bağlayın.',
              style: TextStyle(fontSize: 12, color: CalColors.onSecondaryContainer, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  final bool isSimulated;

  const _ConnectionBadge({required this.isConnected, this.isSimulated = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? CalColors.tertiaryFixed : CalColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSimulated
                    ? const Color(0xFFF59E0B)
                    : isConnected
                        ? CalColors.accent
                        : CalColors.outline,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isSimulated ? 'Simülasyon' : isConnected ? 'Bağlı' : 'Bağlı Değil',
            style: TextStyle(
              fontSize: 12,
              color: isSimulated
                  ? const Color(0xFFF59E0B)
                  : isConnected
                      ? CalColors.tertiary
                      : CalColors.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WMeasureCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;

  const _WMeasureCard({required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
      color: CalColors.surfaceLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CalColors.outlineVariant),
          ),
          child: const Row(
            children: [
              Icon(Icons.speed, color: CalColors.primaryContainer, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('W-Sabiti Otomatik Ölçüm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                    Text('WMEASURE — darbe dizisi ile otomatik ölçüm', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: CalColors.outline),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ParamSection extends StatelessWidget {
  final String title;
  final String tag;
  final List<CalParam> params;
  final void Function(CalParam) onEdit;
  final bool enabled;

  const _ParamSection({
    required this.title,
    required this.tag,
    required this.params,
    required this.onEdit,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalColors.outline, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CalColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: const TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ),
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
              children: List.generate(params.length, (i) {
                final p = params[i];
                return Column(
                  children: [
                    _ParamRow(param: p, enabled: enabled, onEdit: () => onEdit(p)),
                    if (i < params.length - 1)
                      const Divider(height: 1, indent: 16, color: CalColors.outlineVariant),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final CalParam param;
  final VoidCallback onEdit;
  final bool enabled;

  const _ParamRow({required this.param, required this.onEdit, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(param.label, style: const TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Text(
                    param.value == null
                        ? '—'
                        : param.unit.isNotEmpty
                            ? '${param.value} ${param.unit}'
                            : param.value!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            if (enabled)
              const Row(
                children: [
                  Icon(Icons.edit, size: 14, color: CalColors.primary),
                  SizedBox(width: 4),
                  Text('Düzenle', style: TextStyle(fontSize: 12, color: CalColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
