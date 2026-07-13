import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bluetooth/models/ble_device_result.dart';
import '../bluetooth/models/log_entry.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../core/app_logger.dart';
import '../core/exceptions/ble_exception.dart';

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
      if (s == BleConnectionState.connected && !_connectedCallbackFired) {
        _connectedCallbackFired = true;
        if (widget.onConnected != null) {
          _repositoryAdopted = true;
          _closeTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) widget.onConnected!.call(widget.device, widget.repository);
          });
        }
      }
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
    if (!_repositoryAdopted) widget.repository.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await widget.repository.connect(widget.device.deviceId);
      await widget.repository.discoverServices();
      // Notify karakteristiği varsa otomatik aktif et
      await widget.repository
          .setNotify(_kNotifyChar, enable: true)
          .catchError((_) {});
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

  Future<void> _disconnect() async {
    await widget.repository.disconnect();
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
      await widget.repository.writeCharacteristic(_kWriteChar, bytes);
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
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5F7A),
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
          if (isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled,
                  color: Color(0xFFDC2626), size: 18),
              label: const Text('Kes',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
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
      BleConnectionState.connected => ('Bağlandı', const Color(0xFF16A34A)),
      BleConnectionState.disconnecting => ('Kesiliyor...', const Color(0xFF6B7280)),
      BleConnectionState.disconnected => ('Bağlantı Kesildi', const Color(0xFFDC2626)),
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
      return const Center(
        child: Text('Bağlantı bekleniyor...',
            style: TextStyle(color: Color(0xFF4A7A8A))),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4DDE6)),
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
      LogLevel.success => const Color(0xFF16A34A),
      LogLevel.error => const Color(0xFFDC2626),
      LogLevel.outgoing => const Color(0xFF1A5F7A),
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
                style: const TextStyle(color: Color(0xFF4A7A8A))),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFC4DDE6))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Gönder →',
                  style: TextStyle(
                      color: Color(0xFF4A7A8A),
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
                  backgroundColor: const Color(0xFFD8EDF3),
                  selectedBackgroundColor: const Color(0xFFE1F2F7),
                  foregroundColor: const Color(0xFF4A7A8A),
                  selectedForegroundColor: const Color(0xFF1A5F7A),
                  side: const BorderSide(color: Color(0xFFC4DDE6)),
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
                    hintStyle: const TextStyle(
                        color: Color(0xFF4A7A8A), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC4DDE6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFC4DDE6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF57C5B6)),
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
                  backgroundColor: const Color(0xFF1A5F7A),
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

// ─── Sabit UUID'ler (LightBlue test ortamı) ──────────────────────────────────

const _kWriteChar = '70BA6C69-5584-4CF1-9871-9736640E1F9F';
const _kNotifyChar = '0069916F-18DE-4BB3-B4D7-1CB5E5B2EA0F';
