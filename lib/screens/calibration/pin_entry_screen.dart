import 'package:flutter/material.dart';
import '../../bluetooth/models/log_entry.dart';
import '../../core/app_logger.dart';
import '../../models/calibration_data.dart';

class PinEntryScreen extends StatefulWidget {
  final void Function(bool success) onResult;
  final Future<String?> Function() onRequestSeed;
  final Future<bool> Function(String pin) onSendKey;
  final VoidCallback onCancel;

  const PinEntryScreen({
    super.key,
    required this.onResult,
    required this.onRequestSeed,
    required this.onSendKey,
    required this.onCancel,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _seed = '—';
  String _pin = '';
  _PinState _state = _PinState.idle;
  String _message = '';
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _fetchSeed();
  }

  Future<void> _fetchSeed() async {
    setState(() => _state = _PinState.fetchingSeed);
    try {
      final seed = await widget.onRequestSeed();
      if (mounted) {
        setState(() {
          _seed = seed ?? '—';
          _state = seed != null ? _PinState.idle : _PinState.seedError;
          if (seed == null) _message = 'Takograftan tohum değeri alınamadı.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _seed = '—';
          _state = _PinState.seedError;
          _message = 'Bağlantı hatası: $e';
        });
      }
    }
  }

  void _append(String ch) {
    if (_pin.length >= 8) return;
    setState(() => _pin += ch);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _cancelAndPop() {
    widget.onCancel();
    Navigator.pop(context);
  }

  Future<void> _verify() async {
    if (_pin.isEmpty) return;
    setState(() => _state = _PinState.verifying);

    _attempts++;
    bool success;
    try {
      success = await widget.onSendKey(_pin);
    } catch (_) {
      success = false;
    }

    if (!mounted) return;

    if (success) {
      AppLogger.instance.log(
        'PIN authentication successful (seed: $_seed)',
        level: LogLevel.success,
        category: LogCategory.pinAuth,
      );
      setState(() {
        _state = _PinState.success;
        _message = 'Kimlik doğrulama başarılı. Atölye oturumu açıldı.';
      });
      widget.onResult(true);
    } else {
      if (_attempts >= 3) {
        AppLogger.instance.log(
          'PIN entry locked (3 failed attempts)',
          level: LogLevel.error,
          category: LogCategory.pinAuth,
        );
        setState(() {
          _state = _PinState.locked;
          _message = 'Çok fazla başarısız deneme. Lütfen yeniden bağlanın.';
        });
      } else {
        AppLogger.instance.log(
          'PIN authentication failed — attempt $_attempts',
          level: LogLevel.error,
          category: LogCategory.pinAuth,
        );
        setState(() {
          _state = _PinState.failed;
          _message = 'PIN geçersiz. ${3 - _attempts} deneme hakkınız kaldı.';
          _pin = '';
        });
      }
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
          onPressed: _cancelAndPop,
        ),
        title: const Text('PIN Doğrulama', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Seed card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CalColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Takograf Tohum Değeri', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          _state == _PinState.fetchingSeed
                              ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(_seed, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6)),
                          const SizedBox(height: 2),
                          const Text('Servis kartınızdan PIN hesaplayınız', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PIN display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: CalColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _state == _PinState.failed || _state == _PinState.locked
                        ? CalColors.error
                        : _state == _PinState.success
                            ? CalColors.accent
                            : CalColors.primary,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(8, (i) {
                    final filled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 28,
                      height: 36,
                      decoration: BoxDecoration(
                        color: filled ? CalColors.primary : CalColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: filled ? CalColors.primary : CalColors.outlineVariant),
                      ),
                      child: filled
                          ? const Icon(Icons.circle, color: Colors.white, size: 10)
                          : null,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // Status message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _message.isNotEmpty
                    ? Container(
                        key: ValueKey(_message),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _state == _PinState.success ? CalColors.tertiaryFixed : CalColors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _state == _PinState.success ? Icons.check_circle_outline : Icons.error_outline,
                              size: 16,
                              color: _state == _PinState.success ? CalColors.tertiary : CalColors.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _state == _PinState.success ? CalColors.tertiary : CalColors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Keypad
              Expanded(
                child: _state == _PinState.locked
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, color: CalColors.error, size: 48),
                            const SizedBox(height: 12),
                            const Text('Hesap kilitlendi', style: TextStyle(color: CalColors.error, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _cancelAndPop,
                              child: const Text('Geri Dön', style: TextStyle(color: CalColors.primary)),
                            ),
                          ],
                        ),
                      )
                    : _PinKeypad(
                        onAppend: (_state == _PinState.verifying || _state == _PinState.fetchingSeed || _state == _PinState.seedError) ? (_) {} : _append,
                        onBackspace: (_state == _PinState.verifying || _state == _PinState.fetchingSeed || _state == _PinState.seedError) ? () {} : _backspace,
                        onVerify: (_state == _PinState.verifying || _state == _PinState.fetchingSeed || _state == _PinState.seedError) ? null : _verify,
                        isVerifying: _state == _PinState.verifying,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PinState { fetchingSeed, seedError, idle, verifying, success, failed, locked }

class _PinKeypad extends StatelessWidget {
  final void Function(String) onAppend;
  final VoidCallback onBackspace;
  final VoidCallback? onVerify;
  final bool isVerifying;

  const _PinKeypad({
    required this.onAppend,
    required this.onBackspace,
    required this.onVerify,
    required this.isVerifying,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(
                (d) => _DigitBtn(label: d, onTap: () => onAppend(d)),
              ),
              _DigitBtn(
                label: '⌫',
                onTap: onBackspace,
                backgroundColor: CalColors.surfaceLow,
                textColor: CalColors.onSurface,
              ),
              _DigitBtn(label: '0', onTap: () => onAppend('0')),
              const SizedBox.shrink(),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: CalColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: isVerifying
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Doğrula', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _DigitBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;

  const _DigitBtn({
    required this.label,
    required this.onTap,
    this.backgroundColor = CalColors.surfaceLowest,
    this.textColor = CalColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CalColors.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
          ),
        ),
      ),
    );
  }
}
