import 'dart:async';
import 'package:flutter/material.dart';
import '../../kline/kline_records.dart';
import '../../kline/kline_service.dart';
import '../../models/calibration_data.dart';

class MotionSensorPairingScreen extends StatefulWidget {
  final KLineService? klineService;

  const MotionSensorPairingScreen({super.key, this.klineService});

  @override
  State<MotionSensorPairingScreen> createState() => _MotionSensorPairingScreenState();
}

class _MotionSensorPairingScreenState extends State<MotionSensorPairingScreen>
    with SingleTickerProviderStateMixin {
  _PairState _state = _PairState.idle;
  String _statusMessage = 'Hareket sensörü eşleştirmesi başlatmak için düğmeye basın.';
  int _pollCount = 0;
  StreamSubscription<MsPairingStatus>? _pairSub;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pairSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startPairing() {
    if (widget.klineService == null) {
      setState(() => _statusMessage = 'Cihaz bağlı değil.');
      return;
    }
    setState(() {
      _state = _PairState.running;
      _pollCount = 0;
      _statusMessage = 'ECU Ayarlama Oturumu açılıyor...';
    });

    _pairSub = widget.klineService!
        .pairMotionSensor(KLineRoutineIds.motionSensorPairing)
        .listen(
      (status) {
        if (!mounted) return;
        _pollCount++;
        setState(() {
          switch (status) {
            case MsPairingStatus.waiting:
              _statusMessage = 'Sensör sinyali bekleniyor... (${_pollCount * 250} ms)';
            case MsPairingStatus.paired:
              _state = _PairState.success;
              _statusMessage = 'Eşleştirme başarıyla tamamlandı!';
            case MsPairingStatus.conditionsNotCorrect:
              _state = _PairState.failed;
              _statusMessage = 'Koşullar uygun değil (NRC 0x22). Araç durdurulmuş olmalı.';
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _state = _PairState.failed;
          _statusMessage = 'Hata: $e';
        });
      },
    );
  }

  void _reset() {
    _pairSub?.cancel();
    _pairSub = null;
    setState(() {
      _state = _PairState.idle;
      _pollCount = 0;
      _statusMessage = 'Hareket sensörü eşleştirmesi başlatmak için düğmeye basın.';
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
        title: const Text('Hareket Sensörü Eşleştirme', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // State visual
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StateIcon(state: _state, pulseCtrl: _pulseCtrl),
                    const SizedBox(height: 24),
                    Text(
                      _stateTitle,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CalColors.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CalColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CalColors.outlineVariant),
                      ),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(fontSize: 14, color: CalColors.onSurfaceVariant, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_state == _PairState.running) ...[
                      const SizedBox(height: 24),
                      _PollProgress(count: _pollCount, max: 8),
                    ],
                  ],
                ),
              ),

              // Info box
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
                        'Eşleştirme sırasında hareket sensörünün araçta takılı ve aktif olması gerekir. İşlem yaklaşık 4 saniye sürer.',
                        style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action button
              if (_state == _PairState.idle)
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _startPairing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.sensors),
                    label: const Text('Eşleştirmeyi Başlat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                )
              else if (_state == _PairState.running)
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CalColors.outline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.stop, color: CalColors.outline),
                    label: const Text('İptal', style: TextStyle(color: CalColors.outline, fontSize: 16)),
                  ),
                )
              else if (_state == _PairState.success)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CalColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Tamamlandı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  String get _stateTitle {
    switch (_state) {
      case _PairState.idle: return 'Hazır';
      case _PairState.running: return 'Eşleştirme Devam Ediyor';
      case _PairState.success: return 'Eşleştirme Başarılı';
      case _PairState.failed: return 'Eşleştirme Başarısız';
    }
  }
}

enum _PairState { idle, running, success, failed }

class _StateIcon extends StatelessWidget {
  final _PairState state;
  final AnimationController pulseCtrl;

  const _StateIcon({required this.state, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    if (state == _PairState.running) {
      return AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, _) => Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CalColors.primaryContainer.withValues(alpha: 0.1 + pulseCtrl.value * 0.2),
            border: Border.all(color: CalColors.primaryContainer.withValues(alpha: 0.5 + pulseCtrl.value * 0.5), width: 3),
          ),
          child: const Icon(Icons.sensors, color: CalColors.primaryContainer, size: 48),
        ),
      );
    }

    final (icon, color, bg) = switch (state) {
      _PairState.idle => (Icons.sensors_outlined, CalColors.outline, CalColors.surfaceContainer),
      _PairState.success => (Icons.check_circle, CalColors.accent, CalColors.tertiaryFixed),
      _PairState.failed => (Icons.error_outline, CalColors.error, CalColors.errorContainer),
      _ => (Icons.sensors, CalColors.primary, CalColors.surfaceLow),
    };

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, color: color, size: 48),
    );
  }
}

class _PollProgress extends StatelessWidget {
  final int count;
  final int max;

  const _PollProgress({required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: count / max,
          backgroundColor: CalColors.surfaceContainer,
          color: CalColors.primary,
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
        const SizedBox(height: 6),
        Text('Anket: $count / $max', style: const TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
      ],
    );
  }
}
