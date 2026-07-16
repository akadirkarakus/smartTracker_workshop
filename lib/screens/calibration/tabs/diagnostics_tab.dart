import 'package:flutter/material.dart';
import '../../../bluetooth/models/log_entry.dart';
import '../../../core/app_logger.dart';
import '../../../kline/kline_dtc_mapper.dart';
import '../../../kline/kline_records.dart';
import '../../../kline/kline_service.dart';
import '../../../models/calibration_data.dart';

class DiagnosticsTab extends StatefulWidget {
  final List<DtcCode> dtcCodes;
  final VoidCallback onClearDtcs;
  final void Function(List<DtcCode> codes) onDtcsRead;
  final List<ComponentTest> tests;
  final void Function(String id, TestStatus status, int progress) onTestUpdate;
  final bool isDeviceConnected;
  final KLineService? klineService;

  const DiagnosticsTab({
    super.key,
    required this.dtcCodes,
    required this.onClearDtcs,
    required this.onDtcsRead,
    required this.tests,
    required this.onTestUpdate,
    required this.isDeviceConnected,
    this.klineService,
  });

  @override
  State<DiagnosticsTab> createState() => _DiagnosticsTabState();
}

class _DiagnosticsTabState extends State<DiagnosticsTab> {
  bool _isScanning = false;
  bool _scanFound = false;

  Future<void> _readDtcs() async {
    AppLogger.instance.log(
      'DTC scan started',
      level: LogLevel.info,
      category: LogCategory.diagnostics,
    );
    setState(() => _isScanning = true);
    if (widget.klineService == null) {
      setState(() => _isScanning = false);
      return;
    }
    try {
      final entries = await widget.klineService!.readDtcCodes();
      if (!mounted) return;
      final codes = entries.map((e) => DtcCode(
        code: e.code.toRadixString(16).toUpperCase().padLeft(4, '0'),
        description: KLineDtcMapper.description(e.code),
        module: KLineDtcMapper.module(e.code),
        isActive: (e.statusMask & 0x01) != 0,
      )).toList();
      widget.onDtcsRead(codes);
      setState(() {
        _isScanning = false;
        _scanFound = true;
      });
      AppLogger.instance.log(
        'DTC scan complete — ${codes.length} codes found',
        level: LogLevel.success,
        category: LogCategory.diagnostics,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      AppLogger.instance.log(
        'DTC scan error: $e',
        level: LogLevel.error,
        category: LogCategory.diagnostics,
      );
    }
  }

  void _clearDtcs() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('DTC Temizle', style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: const Text('Tüm saklanan hata kodları silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CalColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.klineService?.clearDtcCodes();
              } catch (_) {}
              widget.onClearDtcs();
              setState(() => _scanFound = false);
              AppLogger.instance.log(
                'DTC codes cleared',
                level: LogLevel.info,
                category: LogCategory.diagnostics,
              );
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  // hardware/battery/data_memory/sw_integrity/keypad/buzzer_test — cihazın
  // kendi kendine sonuçlandırdığı veya hiç gözlemlenemeyen rutinler (bkz.
  // kline_records.dart:kDeviceOnlyResultTestIds, CalibrationMessages.md
  // Flow 15/17-21). Doküman bu testler için stopRoutine yanıtı göstermez —
  // yanıt zaman aşımı hata sayılmaz, sonuç operatör tarafından cihaz
  // ekranından kontrol edilmelidir.
  void _showDeviceCheckDialog(String testName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Test Başlatıldı',
          style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.primary),
        ),
        content: Text(
          '$testName başlatıldı. Bu test için cihazdan uygulamaya bir sonuç bildirimi '
          'gelmez — test sonucu takograf ekranı üzerinden incelenmelidir.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _startTest(ComponentTest test) async {
    if (widget.klineService == null) {
      widget.onTestUpdate(test.id, TestStatus.failed, 0);
      return;
    }
    final routineId = kComponentTestRoutineMap[test.id];
    if (routineId == null) {
      // clock and speed_odo require dedicated streaming flows — not handled here
      widget.onTestUpdate(test.id, TestStatus.unsupported, 0);
      return;
    }
    final deviceOnlyResult = kDeviceOnlyResultTestIds.contains(test.id);
    AppLogger.instance.log(
      'Test started: ${test.name}',
      level: LogLevel.info,
      category: LogCategory.diagnostics,
    );
    widget.onTestUpdate(test.id, TestStatus.running, 0);
    if (deviceOnlyResult) {
      _showDeviceCheckDialog(test.name);
    }
    try {
      await widget.klineService!.startRoutineTest(routineId);
      try {
        await widget.klineService!.stopRoutineTest(routineId);
      } on KLineTimeoutException {
        if (!deviceOnlyResult) rethrow;
        // Beklenen davranış — bu test için stopRoutine yanıtı gelmeyebilir.
      }
      if (!mounted) return;
      widget.onTestUpdate(test.id, TestStatus.passed, 100);
      AppLogger.instance.log(
        deviceOnlyResult
            ? 'Test completed: ${test.name} — İletişim OK, sonuç cihaz ekranından doğrulanmalı'
            : 'Test completed: ${test.name} — Passed',
        level: LogLevel.success,
        category: LogCategory.diagnostics,
      );
    } catch (e) {
      if (!mounted) return;
      widget.onTestUpdate(test.id, TestStatus.failed, 0);
      AppLogger.instance.log(
        'Test error: ${test.name} — $e',
        level: LogLevel.error,
        category: LogCategory.diagnostics,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.isDeviceConnected;
    final componentTests = widget.tests.where((t) => t.menuSection == 'COMPONENT').toList();
    final systemTests = widget.tests.where((t) => t.menuSection == 'SYSTEM').toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                if (!connected) ...[
                  _DiagDisconnectedBanner(),
                  const SizedBox(height: 12),
                ],

                // Quick actions header
                _QuickActionsHeader(
                  isEnabled: connected,
                  isScanning: _isScanning,
                  onReadDtcs: _readDtcs,
                  onClearFaults: widget.dtcCodes.isEmpty ? null : _clearDtcs,
                  onRunAll: () {
                    for (final t in widget.tests) {
                      if (t.status == TestStatus.idle) _startTest(t);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // DTC section header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Hata Kodları (DTC)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Son kontrol: ${TimeOfDay.now().format(context)}',
                        style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // DTC list
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: widget.dtcCodes.isEmpty
                ? _EmptyDtc(wasScanned: _scanFound)
                : _DtcList(codes: widget.dtcCodes),
          ),
        ),

        if (connected) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Bileşen & Arayüz ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TestSectionHeader(
                label: 'Bileşen & Arayüz Testleri',
                tests: componentTests,
                isEnabled: true,
                onRunSection: () {
                  for (final t in componentTests) {
                    if (t.status != TestStatus.running) _startTest(t);
                  }
                },
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= componentTests.length) return null;
                final test = componentTests[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _TestCard(
                    test: test,
                    isEnabled: true,
                    onStart: test.status != TestStatus.running ? () => _startTest(test) : null,
                  ),
                );
              },
              childCount: componentTests.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Sistem & Bütünlük ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _TestSectionHeader(
                label: 'Sistem & Bütünlük Testleri',
                tests: systemTests,
                isEnabled: true,
                onRunSection: () {
                  for (final t in systemTests) {
                    if (t.status != TestStatus.running) _startTest(t);
                  }
                },
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= systemTests.length) return null;
                final test = systemTests[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _TestCard(
                    test: test,
                    isEnabled: true,
                    onStart: test.status != TestStatus.running ? () => _startTest(test) : null,
                  ),
                );
              },
              childCount: systemTests.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────

class _DiagDisconnectedBanner extends StatelessWidget {
  const _DiagDisconnectedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CalColors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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

class _QuickActionsHeader extends StatelessWidget {
  final bool isEnabled;
  final bool isScanning;
  final VoidCallback onReadDtcs;
  final VoidCallback? onClearFaults;
  final VoidCallback onRunAll;

  const _QuickActionsHeader({
    required this.isEnabled,
    required this.isScanning,
    required this.onReadDtcs,
    required this.onClearFaults,
    required this.onRunAll,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CalColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Sistem Sağlığı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ActionChip(label: isScanning ? 'Taranıyor...' : 'DTC Oku', icon: Icons.search, onTap: isEnabled ? (isScanning ? () {} : onReadDtcs) : null)),
                const SizedBox(width: 8),
                Expanded(child: _ActionChip(label: 'Hataları Temizle', icon: Icons.delete_sweep_outlined, onTap: isEnabled ? (onClearFaults ?? () {}) : null)),
                const SizedBox(width: 8),
                Expanded(child: _ActionChip(label: 'Tüm Testler', icon: Icons.play_circle_outline, onTap: isEnabled ? onRunAll : null)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDtc extends StatelessWidget {
  final bool wasScanned;

  const _EmptyDtc({required this.wasScanned});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            wasScanned ? Icons.check_circle_outline : Icons.search_outlined,
            color: wasScanned ? CalColors.accent : CalColors.outline,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            wasScanned ? 'Hata kodu bulunamadı' : 'DTC okumak için yukarıdaki butona basın',
            style: TextStyle(color: CalColors.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DtcList extends StatelessWidget {
  final List<DtcCode> codes;

  const _DtcList({required this.codes});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: List.generate(codes.length, (i) {
          final dtc = codes[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                dtc.code,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: dtc.isActive ? CalColors.error : CalColors.primary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dtc.isActive ? CalColors.errorContainer : CalColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dtc.isActive ? 'Aktif' : 'Saklı',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: dtc.isActive ? CalColors.onErrorContainer : CalColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(dtc.description, style: TextStyle(fontSize: 13, color: CalColors.onSurface)),
                          Text(dtc.module, style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.info_outline, color: CalColors.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
              if (i < codes.length - 1) Divider(height: 1, color: CalColors.outlineVariant),
            ],
          );
        }),
      ),
    );
  }
}

class _TestSectionHeader extends StatelessWidget {
  final String label;
  final List<ComponentTest> tests;
  final VoidCallback onRunSection;
  final bool isEnabled;

  const _TestSectionHeader({required this.label, required this.tests, required this.onRunSection, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    final hasRunnable = tests.any((t) => t.status != TestStatus.running);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CalColors.primary))),
        if (hasRunnable)
          TextButton.icon(
            onPressed: isEnabled ? onRunSection : null,
            style: TextButton.styleFrom(
              foregroundColor: isEnabled ? CalColors.primary : CalColors.outline,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Tümünü Çalıştır', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class _TestCard extends StatelessWidget {
  final ComponentTest test;
  final VoidCallback? onStart;
  final bool isEnabled;

  const _TestCard({required this.test, required this.onStart, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CalColors.surfaceLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: test.status == TestStatus.running
                  ? CalColors.primary.withValues(alpha: 0.5)
                  : CalColors.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, color: _iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(test.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                        Text(test.description, style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _StatusButton(status: test.status, progress: test.progress, onStart: onStart, isEnabled: isEnabled),
                ],
              ),
              if (test.status == TestStatus.running) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: test.progress > 0 ? test.progress / 100 : null,
                    backgroundColor: CalColors.surfaceContainer,
                    color: CalColors.primary,
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        );
  }

  Color get _iconBg {
    switch (test.status) {
      case TestStatus.passed: return CalColors.tertiaryFixed;
      case TestStatus.failed: return CalColors.errorContainer;
      case TestStatus.unsupported: return CalColors.secondaryContainer;
      case TestStatus.running: return CalColors.surfaceLow;
      case TestStatus.idle: return CalColors.surfaceLow;
    }
  }

  IconData get _icon {
    switch (test.id) {
      case 'clock': return Icons.schedule;
      case 'speed_odo': return Icons.speed;
      case 'display': return Icons.tv;
      case 'lcd_neg': return Icons.contrast;
      case 'printer': return Icons.print;
      case 'hardware': return Icons.memory;
      case 'card_reader': return Icons.credit_card;
      case 'keypad': return Icons.grid_view;
      case 'battery': return Icons.battery_full;
      case 'data_memory': return Icons.storage;
      case 'sw_integrity': return Icons.verified_user;
      case 'buzzer_test': return Icons.volume_up;
      default: return Icons.check;
    }
  }

  Color get _iconColor {
    switch (test.status) {
      case TestStatus.passed: return CalColors.onTertiaryFixed;
      case TestStatus.failed: return CalColors.error;
      case TestStatus.unsupported: return CalColors.onSecondaryContainer;
      case TestStatus.running: return CalColors.primary;
      case TestStatus.idle: return CalColors.onSurfaceVariant;
    }
  }
}

class _StatusButton extends StatelessWidget {
  final TestStatus status;
  final int progress;
  final VoidCallback? onStart;
  final bool isEnabled;

  const _StatusButton({required this.status, required this.progress, required this.onStart, this.isEnabled = true});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TestStatus.running:
        return Text('$progress%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalColors.primary));
      case TestStatus.passed:
        return Icon(Icons.check_circle, color: CalColors.accent, size: 26);
      case TestStatus.failed:
        return Icon(Icons.cancel, color: CalColors.error, size: 26);
      case TestStatus.unsupported:
        return Tooltip(
          message: 'Bu test bu cihazda desteklenmiyor',
          child: Icon(Icons.help_outline, color: CalColors.onSecondaryContainer, size: 26),
        );
      case TestStatus.idle:
        return Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: isEnabled ? onStart : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: CalColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Başlat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    }
  }
}
