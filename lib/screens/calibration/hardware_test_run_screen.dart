import 'dart:async';

import 'package:flutter/material.dart';
import '../../kline/hardware_test_runner.dart';
import '../../kline/kline_service.dart';
import '../../models/calibration_data.dart';
import '../../models/hardware_test_report.dart';
import 'hardware_test_ui.dart';
import 'pin_entry_screen.dart';

class HardwareTestRunScreen extends StatefulWidget {
  const HardwareTestRunScreen({
    super.key,
    required this.klineService,
    required this.isPinAuthenticated,
    required this.isStc8255,
    required this.onAuthChanged,
  });

  final KLineService klineService;
  final bool isPinAuthenticated;
  final bool isStc8255;
  final void Function(bool) onAuthChanged;

  @override
  State<HardwareTestRunScreen> createState() => _HardwareTestRunScreenState();
}

enum _RunState { idle, running, done }

class _HardwareTestRunScreenState extends State<HardwareTestRunScreen> {
  _RunState _state = _RunState.idle;
  late bool _pinAuthenticated;
  final _items = <HardwareTestItemResult>[];
  int _total = 0;
  HardwareTestReport? _report;
  StreamSubscription<HardwareTestProgress>? _sub;
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _pinAuthenticated = widget.isPinAuthenticated;
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 80;
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openPin() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PinEntryScreen(
          onResult: (success) {
            widget.onAuthChanged(success);
            setState(() => _pinAuthenticated = success);
            Navigator.pop(context);
          },
          onRequestSeed: () async {
            try {
              return await widget.klineService.requestSeed();
            } catch (_) {
              return null;
            }
          },
          onSendKey: (pin) async {
            try {
              final result = await widget.klineService.sendKey(pin);
              return (result.success, result.nrc);
            } catch (_) {
              return (false, null);
            }
          },
          onCancel: () {
            unawaited(() async {
              try {
                await widget.klineService.cancelSecurityAccess();
              } catch (_) {
                // Bağlantı zaten kopmuş olabilir — sessizce yut.
              }
            }());
          },
        ),
      ),
    );
  }

  void _startTest() {
    setState(() {
      _state = _RunState.running;
      _items.clear();
      _total = 0;
      _report = null;
    });
    final runner = HardwareTestRunner(widget.klineService);
    _sub = runner
        .run(pinAuthenticated: _pinAuthenticated, isStc8255: widget.isStc8255)
        .listen((progress) {
      if (!mounted) return;
      setState(() {
        if (progress.lastItem != null && !_items.contains(progress.lastItem)) {
          _items.add(progress.lastItem!);
        }
        _total = progress.totalCount;
        if (progress.isDone) {
          _state = _RunState.done;
          _report = progress.finalReport;
        }
      });
      if (_autoScroll) _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Donanım Testi', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: switch (_state) {
        _RunState.idle => _buildIdle(),
        _RunState.running || _RunState.done => _buildRun(),
      },
    );
  }

  Widget _buildIdle() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu test, tüm kalibrasyon parametrelerini, opsiyonel ayarları, DTC servislerini ve '
            'bileşen öz-testlerini sırayla takograftan okuyup (yazılabilir parametreler için '
            'mevcut değeri geri yazıp doğrulayarak) her biri için sonucu kaydeder.',
            style: TextStyle(fontSize: 13.5, color: CalColors.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _pinAuthenticated ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _pinAuthenticated ? const Color(0xFF16A34A) : const Color(0xFFF59E0B)),
            ),
            child: Row(
              children: [
                Icon(_pinAuthenticated ? Icons.lock_open : Icons.lock_outline,
                    color: _pinAuthenticated ? const Color(0xFF16A34A) : const Color(0xFF92400E), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pinAuthenticated
                        ? 'PIN doğrulandı — yazma-doğrulama testleri de çalışacak.'
                        : 'PIN doğrulanmadı — yazma-doğrulama testleri atlanacak (sadece okuma yapılır).',
                    style: TextStyle(fontSize: 12.5, color: _pinAuthenticated ? const Color(0xFF166534) : const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          if (!_pinAuthenticated) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openPin,
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text('Şimdi PIN Gir'),
              style: OutlinedButton.styleFrom(foregroundColor: CalColors.primary),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _startTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: CalColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Testi Başlat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRun() {
    final progressValue = _total == 0 ? 0.0 : _items.length / _total;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            children: [
              LinearProgressIndicator(value: progressValue.clamp(0.0, 1.0)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_items.length}/$_total adım', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  if (_state == _RunState.done)
                    const Text('Tamamlandı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                ],
              ),
            ],
          ),
        ),
        if (_state == _RunState.done && _report != null) _buildSummaryBanner(_report!),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Icon(Icons.terminal, size: 14, color: CalColors.outline),
              const SizedBox(width: 6),
              Text(
                'CANLI GÜNLÜK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalColors.outline, letterSpacing: 0.6),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _items.length,
                itemBuilder: (_, i) => _HwLogLine(item: _items[i]),
              ),
              if (!_autoScroll)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _autoScroll = true);
                      _scrollToBottom();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: CalColors.primaryContainer,
                      alignment: Alignment.center,
                      child: const Text(
                        '↓ En alta git',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBanner(HardwareTestReport report) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: report.hasFailure ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: report.hasFailure ? CalColors.error : const Color(0xFF16A34A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.hasFailure ? 'Test tamamlandı — bazı adımlar başarısız oldu' : 'Test tamamlandı — kritik hata yok',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: report.hasFailure ? CalColors.error : const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _summaryStat('Geçti', report.passCount, const Color(0xFF16A34A)),
              _summaryStat('Başarısız', report.failCount, CalColors.error),
              _summaryStat('Görsel Onay', report.visualConfirmCount, const Color(0xFF2563EB)),
              _summaryStat('İletişim OK', report.commsOkUnverifiedCount, const Color(0xFFF59E0B)),
              _summaryStat('Atlandı', report.skippedCount, CalColors.outline),
            ],
          ),
          const SizedBox(height: 8),
          Text('Rapor otomatik olarak kaydedildi — "Test Raporlarını Görüntüle" ile erişebilirsiniz.',
              style: TextStyle(fontSize: 11.5, color: CalColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: $count', style: TextStyle(fontSize: 11.5, color: CalColors.onSurface)),
      ],
    );
  }
}

// TestLogScreen'deki _LogLine ile aynı görsel dil (monospace, [saat] [DURUM] etiket)
// — kullanıcı testi başlattığında gördüğü ekranın gerçek bir "log ekranı" olması için.
class _HwLogLine extends StatelessWidget {
  const _HwLogLine({required this.item});
  final HardwareTestItemResult item;

  @override
  Widget build(BuildContext context) {
    final ts = item.timestamp;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    final color = hwStatusColor(item.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6),
          children: [
            TextSpan(text: '[$time] ', style: TextStyle(color: CalColors.onSurfaceVariant)),
            TextSpan(
              text: '[${hwStatusLabel(item.status)}] ',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: '${item.label} — ',
              style: TextStyle(color: CalColors.onSurface, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: item.detail, style: TextStyle(color: CalColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
