import 'package:flutter/material.dart';
import '../../bluetooth/models/log_entry.dart';
import '../../core/app_logger.dart';
import '../../models/calibration_data.dart';

class WConstantMeasurementScreen extends StatefulWidget {
  final void Function(String wValue) onWriteResult;
  final Future<int?> Function()? onMeasure;

  const WConstantMeasurementScreen({super.key, required this.onWriteResult, this.onMeasure});

  @override
  State<WConstantMeasurementScreen> createState() => _WConstantMeasurementScreenState();
}

class _WConstantMeasurementScreenState extends State<WConstantMeasurementScreen> {
  _MeasureState _state = _MeasureState.idle;
  String? _measuredValue;
  String? _errorMessage;

  Future<void> _startMeasurement() async {
    if (widget.onMeasure == null) {
      setState(() {
        _state = _MeasureState.idle;
        _errorMessage = 'Cihaz bağlı değil.';
      });
      return;
    }
    AppLogger.instance.log(
      'W-constant measurement started',
      level: LogLevel.info,
      category: LogCategory.calibration,
    );
    setState(() {
      _state = _MeasureState.measuring;
      _measuredValue = null;
      _errorMessage = null;
    });

    try {
      final result = await widget.onMeasure!();
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _state = _MeasureState.done;
          _measuredValue = result.toString();
        });
        AppLogger.instance.log(
          'W-constant measurement result: $result imp/km',
          level: LogLevel.success,
          category: LogCategory.calibration,
        );
      } else {
        setState(() {
          _state = _MeasureState.idle;
          _errorMessage = 'Ölçüm sonucu alınamadı.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _MeasureState.idle;
        _errorMessage = 'Ölçüm hatası: $e';
      });
    }
  }

  Future<void> _acceptAndWrite() async {
    setState(() => _state = _MeasureState.writing);
    AppLogger.instance.log(
      'W-constant written to tachograph: $_measuredValue imp/km',
      level: LogLevel.success,
      category: LogCategory.calibration,
    );
    widget.onWriteResult(_measuredValue!);
    if (mounted) Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _state = _MeasureState.idle;
      _measuredValue = null;
      _errorMessage = null;
    });
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
        title: const Text('W-Sabiti Ölçümü', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // How it works info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CalColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Ölçüm Nasıl Çalışır?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cihaz, takografa bilinen bir hız darbe dizisi gönderir. Takograf raporlanan hızla karşılaştırarak W-sabitini otomatik hesaplar.',
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gauge visual
                    _MeasureGauge(state: _state, value: _measuredValue),
                    const SizedBox(height: 24),

                    // Steps
                    if (_state == _MeasureState.idle) ...[
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: CalColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text(_errorMessage!, style: const TextStyle(fontSize: 13, color: CalColors.onErrorContainer)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _StepCard(step: 1, text: 'Araç durdurulmuş ve takograf atölye modunda olmalı'),
                      const SizedBox(height: 8),
                      _StepCard(step: 2, text: 'Cihaz, hız giriş I/O komutunu etkinleştirecek'),
                      const SizedBox(height: 8),
                      _StepCard(step: 3, text: 'Darbe dizisi gönderilerek W-sabiti hesaplanacak'),
                    ] else if (_state == _MeasureState.measuring) ...[
                      const Text('Ölçüm devam ediyor...', style: TextStyle(fontSize: 16, color: CalColors.onSurface, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                        child: LinearProgressIndicator(
                          backgroundColor: CalColors.surfaceContainer,
                          color: CalColors.primary,
                          minHeight: 8,
                        ),
                      ),
                    ] else if (_state == _MeasureState.done) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CalColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CalColors.accent, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Text('Ölçüm Sonucu', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(_measuredValue!, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
                                const SizedBox(width: 8),
                                const Text('imp/km', style: TextStyle(fontSize: 16, color: CalColors.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Ölçüm başarılı ✓', style: TextStyle(fontSize: 13, color: CalColors.accent, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Info note
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
                    Icon(Icons.warning_amber_outlined, size: 16, color: CalColors.outline),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'W-sabiti yazıldıktan sonra takografın yeniden başlatılması gerekebilir.',
                        style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              if (_state == _MeasureState.idle)
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ölçümü Başlat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                )
              else if (_state == _MeasureState.measuring)
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CalColors.outline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('İptal', style: TextStyle(color: CalColors.outline, fontSize: 16)),
                  ),
                )
              else if (_state == _MeasureState.done)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _state == _MeasureState.writing ? null : _acceptAndWrite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: _state == _MeasureState.writing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 20),
                          label: Text(_state == _MeasureState.writing ? 'Yazılıyor...' : 'Kabul Et & Yaz', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: CalColors.outlineVariant, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Yenile', style: TextStyle(color: CalColors.onSurfaceVariant)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MeasureState { idle, measuring, done, writing }

class _StepCard extends StatelessWidget {
  final int step;
  final String text;

  const _StepCard({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: CalColors.primaryContainer),
            alignment: Alignment.center,
            child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant, height: 1.4))),
        ],
      ),
    );
  }
}

class _MeasureGauge extends StatelessWidget {
  final _MeasureState state;
  final String? value;

  const _MeasureGauge({required this.state, required this.value});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (state) {
      _MeasureState.idle => (Icons.speed, CalColors.outline, CalColors.surfaceContainer),
      _MeasureState.measuring => (Icons.sync, CalColors.primary, CalColors.surfaceLow),
      _MeasureState.done || _MeasureState.writing => (Icons.check_circle, CalColors.accent, CalColors.tertiaryFixed),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 100,
      height: 100,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: state == _MeasureState.measuring
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: CalColors.primary, strokeWidth: 4),
            )
          : Icon(icon, color: color, size: 52),
    );
  }
}
