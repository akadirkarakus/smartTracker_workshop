// Genişletilmiş Test — Saat Testi (Flow 10) ve Hız & Kilometre Testi (Flow 11).
// Bu iki test, varsayılan "Donanım Testi Yap" akışına DAHİL DEĞİLDİR (kullanıcı kararı):
// Hız/Km testi ~15 dakika sürer, Saat Testi en az 12 RTC darbesi yakalanana kadar bekler.
// runClockTest()/runSpeedOdometerTest() şu ana kadar hiçbir ekrandan çağrılmıyordu
// (dead code) — bu ekran ilk gerçek çağıran taraf.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../kline/kline_service.dart';
import '../../models/calibration_data.dart';

class ExtendedHardwareTestScreen extends StatefulWidget {
  const ExtendedHardwareTestScreen({super.key, required this.klineService});
  final KLineService klineService;

  @override
  State<ExtendedHardwareTestScreen> createState() => _ExtendedHardwareTestScreenState();
}

class _ExtendedHardwareTestScreenState extends State<ExtendedHardwareTestScreen> {
  StreamSubscription<ClockTestProgress>? _clockSub;
  StreamSubscription<SpeedTestProgress>? _speedSub;

  ClockTestProgress? _clockProgress;
  bool _clockRunning = false;
  String? _clockError;

  SpeedTestProgress? _speedProgress;
  bool _speedRunning = false;
  String? _speedError;

  @override
  void dispose() {
    _clockSub?.cancel();
    _speedSub?.cancel();
    super.dispose();
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _startClockTest() async {
    final ok = await _confirm(
      'Saat Testi',
      'Bu test, takografın RTC çıkışından en az 12 darbe yakalanana kadar (yaklaşık 15 saniye) sürer. '
      'Not: Bu sürümde sapma (±s/gün) hesaplaması henüz uygulanmadı — sadece iletişim doğrulanır.',
    );
    if (!ok) return;
    setState(() {
      _clockRunning = true;
      _clockError = null;
      _clockProgress = null;
    });
    _clockSub = widget.klineService.runClockTest().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _clockProgress = p;
          if (p.isDone) _clockRunning = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _clockRunning = false;
          _clockError = e.toString();
        });
      },
    );
  }

  Future<void> _startSpeedTest() async {
    final ok = await _confirm(
      'Hız & Kilometre Testi',
      'Bu test 40, 70 ve 100 km/h adımlarında toplam yaklaşık 15-20 dakika sürer ve aracın hareketsiz, '
      'test moduna hazır olmasını gerektirir. Devam edilsin mi?',
    );
    if (!ok) return;
    setState(() {
      _speedRunning = true;
      _speedError = null;
      _speedProgress = null;
    });
    _speedSub = widget.klineService.runSpeedOdometerTest().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _speedProgress = p;
          if (p.isDone) _speedRunning = false;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _speedRunning = false;
          _speedError = e.toString();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Genişletilmiş Test', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, size: 18, color: Color(0xFF92400E)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu testler dakikalar sürebilir ve standart "Donanım Testi Yap" akışına dahil değildir.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildClockCard(),
          const SizedBox(height: 16),
          _buildSpeedCard(),
        ],
      ),
    );
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CalColors.onSurface)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildClockCard() {
    return _card(
      title: 'Saat Testi',
      subtitle: 'RTC darbe yakalama — Flow 10',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_clockProgress != null) ...[
            LinearProgressIndicator(value: _clockProgress!.capturedPulses / 12),
            const SizedBox(height: 8),
            Text('${_clockProgress!.capturedPulses}/12 darbe yakalandı', style: TextStyle(fontSize: 13, color: CalColors.onSurface)),
            if (_clockProgress!.isDone) ...[
              const SizedBox(height: 6),
              const Text(
                'İletişim başarılı — sapma hesaplaması (±s/gün) bu sürümde uygulanmadı.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ],
          ],
          if (_clockError != null) ...[
            const SizedBox(height: 6),
            Text('Hata: $_clockError', style: TextStyle(fontSize: 12, color: CalColors.error)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _clockRunning ? null : _startClockTest,
              style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_clockRunning ? 'Çalışıyor...' : 'Saat Testini Başlat'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard() {
    final p = _speedProgress;
    return _card(
      title: 'Hız & Kilometre Testi',
      subtitle: '40 / 70 / 100 km/h adımları — Flow 11 (~15-20 dk)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p != null) ...[
            Text('Adım ${p.speedStep + 1}/3 — Komut: ${p.commandedKmh.toStringAsFixed(0)} km/h',
                style: TextStyle(fontSize: 13, color: CalColors.onSurface)),
            const SizedBox(height: 4),
            Text(
              p.measuredKmh == null ? 'Ölçüm bekleniyor...' : 'Ölçülen: ${p.measuredKmh!.toStringAsFixed(1)} km/h',
              style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant),
            ),
            if (p.isPassed != null) ...[
              const SizedBox(height: 4),
              Text(
                p.isPassed! ? 'Tolerans içinde (±2 km/h)' : 'Tolerans aşıldı (±2 km/h)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.isPassed! ? const Color(0xFF16A34A) : CalColors.error),
              ),
            ],
          ],
          if (_speedError != null) ...[
            const SizedBox(height: 6),
            Text('Hata: $_speedError', style: TextStyle(fontSize: 12, color: CalColors.error)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _speedRunning ? null : _startSpeedTest,
              style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_speedRunning ? 'Çalışıyor...' : 'Hız/Km Testini Başlat'),
            ),
          ),
        ],
      ),
    );
  }
}
