import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bluetooth/models/ble_device_result.dart';
import '../bluetooth/models/log_entry.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../core/app_logger.dart';
import '../core/exceptions/ble_exception.dart';
import '../models/calibration_data.dart';

class BleTerminalScreen extends StatefulWidget {
  const BleTerminalScreen({
    super.key,
    required this.device,
    required this.repository,
    this.onConnected,
  });

  final BleDeviceResult device;
  final BleConnectionRepository repository;
  final void Function(BleDeviceResult, BleConnectionRepository)? onConnected;

  @override
  State<BleTerminalScreen> createState() => _BleTerminalScreenState();
}

class _BleTerminalScreenState extends State<BleTerminalScreen> {
  final _logs = <LogEntry>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  bool _hexMode = false;

  BleConnectionState _connState = BleConnectionState.disconnected;
  bool _connectedCallbackFired = false;
  bool _repositoryAdopted = false;
  Timer? _closeTimer;

  StreamSubscription<BleConnectionState>? _stateSub;
  StreamSubscription<LogEntry>? _logSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.repository.connectionState.listen((s) {
      if (mounted) setState(() => _connState = s);
    });
    _logSub = widget.repository.logs.listen((entry) {
      if (mounted) {
        setState(() => _logs.add(entry));
        _scrollToBottom();
      }
    });
    AppLogger.instance.bridgeStream(widget.repository.logs);
    _connect();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _stateSub?.cancel();
    _logSub?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    if (!_repositoryAdopted) unawaited(widget.repository.dispose());
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await widget.repository.connect(widget.device.deviceId);
      await widget.repository.discoverServices();
      // Notify karakteristiğini aktif et — 'SPP_DATA', KLineService'in de
      // kullandığı transporttan bağımsız kanal adıdır (BLE'de discoverServices()
      // sırasında gerçek UUID'ye eşlenir, bkz. ble_connection_service.dart).
      // Hata varsa yutmadan görünür kılınır, aksi halde KLineService sonradan
      // çok daha kafa karıştırıcı bir "Notify not active" hatasıyla karşılaşır.
      await widget.repository.setNotify('SPP_DATA', enable: true);
      _scheduleHandoff();
    } on BleException catch (e) {
      if (mounted) {
        setState(() => _logs.add(
              LogEntry(message: e.toString(), level: LogLevel.error),
            ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _logs.add(
              LogEntry(
                  message: '[terminal] Unexpected error: $e',
                  level: LogLevel.error),
            ));
      }
    }
  }

  // KLineService'e devretmeden önce setNotify'ın gerçekten tamamlanmış olması
  // gerekir — önceden bu, ham GATT 'connected' durumuna bağlı sabit bir 2 sn
  // zamanlayıcıyla tetikleniyordu ve discoverServices()+setNotify() 2 sn'den
  // uzun sürerse KLineService, notify kanalı hazır olmadan inşa edilip
  // notifyStream('SPP_DATA') içinde yakalanmamış bir exception fırlatıyordu.
  void _scheduleHandoff() {
    if (_connectedCallbackFired || widget.onConnected == null) return;
    _connectedCallbackFired = true;
    _repositoryAdopted = true;
    _closeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) widget.onConnected!.call(widget.device, widget.repository);
    });
  }

  Future<void> _disconnect() async {
    await widget.repository.disconnect();
  }

  void _copyAll() {
    final buf = StringBuffer();
    buf.writeln('=== ${widget.device.displayName} — BLE Terminal Log ===');
    buf.writeln('Date: ${DateTime.now()}');
    buf.writeln('Total entries: ${_logs.length}');
    buf.writeln('');
    for (final e in _logs) {
      final ts = e.timestamp;
      final time =
          '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
      buf.writeln('[$time] [${e.prefix}] ${e.message}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Günlük panoya kopyalandı'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Bağlanılan cihazın gerçekten takograf adaptörü olup olmadığını anlamak
  // için Device Information servisindeki (180A) standart, şifrelenmemiş
  // Read karakteristiklerini okur: 2A29 (Üretici Adı), 2A24 (Model Numarası).
  Future<void> _readDeviceInfo() async {
    for (final (uuid, label) in [
      ('2A29', 'Üretici'),
      ('2A24', 'Model'),
    ]) {
      try {
        final bytes = await widget.repository.readCharacteristic(uuid);
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        if (mounted) {
          setState(() => _logs.add(LogEntry(
                message: '$label: ${text.isEmpty ? "(boş)" : text}',
                level: LogLevel.success,
              )));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _logs.add(LogEntry(
                message: '$label okunamadı ($uuid): $e',
                level: LogLevel.error,
              )));
        }
      }
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    List<int> bytes;
    if (_hexMode) {
      try {
        final clean = text.replaceAll(' ', '');
        bytes = List.generate(
          clean.length ~/ 2,
          (i) => int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16),
        );
      } catch (_) {
        setState(() => _logs.add(LogEntry(
              message: 'Invalid hex input. Example: "48 65 6C 6C 6F"',
              level: LogLevel.error,
            )));
        return;
      }
    } else {
      bytes = text.codeUnits;
    }

    _inputController.clear();
    try {
      await widget.repository.writeCharacteristic('SPP_DATA', bytes);
    } on BleException catch (e) {
      if (mounted) {
        setState(() =>
            _logs.add(LogEntry(message: e.toString(), level: LogLevel.error)));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connState == BleConnectionState.connected;

    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.device.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            _ConnectionChip(state: _connState),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Cihaz bilgisi oku (Üretici/Model)',
            onPressed: isConnected ? _readDeviceInfo : null,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white),
            tooltip: 'Panoya kopyala',
            onPressed: _logs.isEmpty ? null : _copyAll,
          ),
          if (isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: Icon(Icons.bluetooth_disabled,
                  color: CalColors.error, size: 18),
              label: Text('Kes',
                  style: TextStyle(color: CalColors.error, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _LogView(logs: _logs, controller: _scrollController)),
          _InputPanel(
            controller: _inputController,
            hexMode: _hexMode,
            onToggleMode: () => setState(() => _hexMode = !_hexMode),
            onSend: isConnected ? _send : null,
          ),
        ],
      ),
    );
  }
}

// ─── Bağlantı Chip ───────────────────────────────────────────────────────────

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});
  final BleConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      BleConnectionState.connecting => ('Bağlanıyor...', const Color(0xFFD97706)),
      BleConnectionState.connected => ('Bağlandı', CalColors.accent),
      BleConnectionState.disconnecting => ('Kesiliyor...', CalColors.outline),
      BleConnectionState.disconnected => ('Bağlantı Kesildi', CalColors.error),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Log Görünümü ─────────────────────────────────────────────────────────────

class _LogView extends StatelessWidget {
  const _LogView({required this.logs, required this.controller});
  final List<LogEntry> logs;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Text('Bağlantı bekleniyor...',
            style: TextStyle(color: CalColors.onSurfaceVariant)),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: ListView.builder(
        controller: controller,
        itemCount: logs.length,
        itemBuilder: (_, i) => _LogLine(entry: logs[i]),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.info => const Color(0xFF5B8EA6),
      LogLevel.success => CalColors.accent,
      LogLevel.error => CalColors.error,
      LogLevel.outgoing => CalColors.primaryContainer,
      LogLevel.incoming => const Color(0xFFD97706),
    };

    final ts = entry.timestamp;
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 12, height: 1.5),
          children: [
            TextSpan(
                text: '[$time] ',
                style: TextStyle(color: CalColors.onSurfaceVariant)),
            TextSpan(
                text: '[${entry.prefix}] ',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            TextSpan(text: entry.message, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Giriş Paneli ─────────────────────────────────────────────────────────────

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.controller,
    required this.hexMode,
    required this.onToggleMode,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hexMode;
  final VoidCallback onToggleMode;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        border: Border(top: BorderSide(color: CalColors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Gönder →',
                  style: TextStyle(
                      color: CalColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('ASCII')),
                  ButtonSegment(value: true, label: Text('HEX')),
                ],
                selected: {hexMode},
                onSelectionChanged: (_) => onToggleMode(),
                style: SegmentedButton.styleFrom(
                  backgroundColor: CalColors.surfaceLow,
                  selectedBackgroundColor: CalColors.surfaceContainer,
                  foregroundColor: CalColors.onSurfaceVariant,
                  selectedForegroundColor: CalColors.primaryContainer,
                  side: BorderSide(color: CalColors.outlineVariant),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: onSend != null,
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: hexMode
                        ? '48 65 6C 6C 6F (hex)'
                        : 'Mesaj yaz... (ASCII)',
                    hintStyle: TextStyle(
                        color: CalColors.onSurfaceVariant, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CalColors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CalColors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: CalColors.accent),
                    ),
                  ),
                  inputFormatters: hexMode
                      ? [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9a-fA-F ]'))
                        ]
                      : null,
                  onSubmitted: (_) => onSend?.call(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalColors.primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Gönder',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
