import 'package:flutter/material.dart';
import '../../bluetooth/models/log_entry.dart';
import '../../core/app_logger.dart';
import '../../kline/parameter_validation.dart';
import '../../models/calibration_data.dart';

class WConstantMeasurementScreen extends StatefulWidget {
  final Future<bool> Function(String wValue) onWriteResult;

  const WConstantMeasurementScreen({super.key, required this.onWriteResult});

  @override
  State<WConstantMeasurementScreen> createState() => _WConstantMeasurementScreenState();
}

class _WConstantMeasurementScreenState extends State<WConstantMeasurementScreen> {
  _MeasureState _state = _MeasureState.idle;
  String? _measuredValue;
  String? _errorMessage;

  Future<void> _enterValue() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('W-Sabiti Değerini Gir', style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'W-Sabiti',
            suffixText: 'imp/km',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (entered == null) return;

    try {
      final normalized = ParameterValidator.validateNumberInRange(
        entered,
        label: 'W-Sabiti',
        min: 1,
        max: 65535,
      );
      setState(() {
        _state = _MeasureState.done;
        _measuredValue = normalized.toString();
        _errorMessage = null;
      });
    } on ParamValidationException catch (e) {
      setState(() {
        _state = _MeasureState.idle;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _acceptAndWrite() async {
    setState(() => _state = _MeasureState.writing);
    bool success;
    try {
      success = await widget.onWriteResult(_measuredValue!);
    } on ParamValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _MeasureState.done;
        _errorMessage = e.message;
      });
      return;
    } catch (e) {
      AppLogger.instance.log(
        'W-constant write error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
      success = false;
    }
    if (!mounted) return;
    if (success) {
      AppLogger.instance.log(
        'W-constant written to tachograph: $_measuredValue imp/km',
        level: LogLevel.success,
        category: LogCategory.calibration,
      );
      Navigator.pop(context);
    } else {
      setState(() {
        _state = _MeasureState.done;
        _errorMessage = 'Yazma işlemi başarısız. Bağlantıyı kontrol edin.';
      });
    }
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
          icon: Icon(Icons.arrow_back, color: CalColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('W-Sabiti Girişi', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
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
                        Text('Bu Ekran Ne İşe Yarar?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'W-sabiti otomatik olarak ölçülmez. Değeri harici bir test düzeneğinde (dinamometre/test bankı) ölçüp aşağıya elle girin; onayladığınızda değer doğrudan takografa yazılır.',
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
                          child: Text(_errorMessage!, style: TextStyle(fontSize: 13, color: CalColors.onErrorContainer)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _StepCard(step: 1, text: 'W-sabitini harici test düzeneği/dinamometre ile ölçün'),
                      const SizedBox(height: 8),
                      _StepCard(step: 2, text: 'Ölçülen imp/km değerini "Değeri Gir" ile girin'),
                      const SizedBox(height: 8),
                      _StepCard(step: 3, text: 'Değeri onaylayıp takografa yazın'),
                    ] else if (_state == _MeasureState.done) ...[
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: CalColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text(_errorMessage!, style: TextStyle(fontSize: 13, color: CalColors.onErrorContainer)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CalColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CalColors.accent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Text('Ölçüm Sonucu', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(_measuredValue!, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: CalColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
                                SizedBox(width: 8),
                                Text('imp/km', style: TextStyle(fontSize: 16, color: CalColors.onSurfaceVariant)),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text('Ölçüm başarılı ✓', style: TextStyle(fontSize: 13, color: CalColors.accent, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Info note
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CalColors.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CalColors.outlineVariant),
                ),
                child: Row(
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
                    onPressed: _enterValue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Değeri Gir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                    SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CalColors.outlineVariant, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Yenile', style: TextStyle(color: CalColors.onSurfaceVariant)),
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

enum _MeasureState { idle, done, writing }

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
            decoration: BoxDecoration(shape: BoxShape.circle, color: CalColors.primaryContainer),
            alignment: Alignment.center,
            child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant, height: 1.4))),
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
      _MeasureState.done || _MeasureState.writing => (Icons.check_circle, CalColors.onTertiaryFixed, CalColors.tertiaryFixed),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 100,
      height: 100,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, color: color, size: 52),
    );
  }
}
