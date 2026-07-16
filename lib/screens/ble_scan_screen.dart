import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../bluetooth/config/bluetooth_config.dart';
import '../bluetooth/models/ble_device_result.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../bluetooth/repositories/ble_scanner_repository.dart';
import '../core/exceptions/ble_exception.dart';
import '../models/calibration_data.dart';
import 'ble_terminal_screen.dart';

enum _ScanState { idle, scanning, error }

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key, this.repository, this.onDeviceConnected});
  final BleScannerRepository? repository;
  final void Function(BleDeviceResult, BleConnectionRepository)? onDeviceConnected;

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  _ScanState _state = _ScanState.idle;
  List<BleDeviceResult> _devices = [];
  String? _errorMessage;
  StreamSubscription<List<BleDeviceResult>>? _sub;

  BtTransport? _selectedTransport;
  BleScannerRepository? _repository;

  bool _showAll = false;
  static const int _rssiMin = -80; // dBm — bu eşiğin altındaki cihazlar gizlenir

  int _autoRetryCount = 0;
  static const int _maxAutoRetry = 3;
  static const Duration _scanDuration = Duration(seconds: 3);
  Timer? _scanTimer;

  bool get _showSelector => widget.repository == null && _selectedTransport == null;

  // RSSI filtresi uygulanmış ve takograf cihazları üste sıralanmış liste
  List<BleDeviceResult> get _filteredDevices {
    final list = _devices.where((d) {
      if (!d.isConnectable) return false;
      // Classic BT'de rssi == -100 ise bilinmiyor; simüle ve bilinmeyen RSSI filtrelenmez
      if (_showAll || d.isSimulated || d.rssi <= -100) return true;
      return d.rssi >= _rssiMin;
    }).toList()
      ..sort((a, b) {
        if (a.isTachographDevice != b.isTachographDevice) {
          return a.isTachographDevice ? -1 : 1;
        }
        return b.rssi.compareTo(a.rssi);
      });
    return list;
  }

  // Filtre nedeniyle gizlenen bağlanılabilir cihaz sayısı
  int get _hiddenCount => _devices.where((d) =>
      d.isConnectable && !d.isSimulated && d.rssi > -100 && d.rssi < _rssiMin,
  ).length;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startScan();
      });
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _sub?.cancel();
    _repository?.dispose();
    super.dispose();
  }

  void _selectTransport(BtTransport t) {
    if (t == BtTransport.classic && Platform.isIOS) return;
    if (t == BtTransport.simulated) {
      _startSimulation();
      return;
    }
    setState(() {
      _selectedTransport = t;
      _repository = createScannerService(t);
      _autoRetryCount = 0;
    });
    _startScan();
  }

  void _startSimulation() {
    final fakeDevice = BleDeviceResult(
      deviceId: 'SIM:FF:FF:FF:FF:FF',
      name: 'Simülasyon Cihazı',
      rssi: -55,
      isConnectable: true,
      serviceUuids: const [],
      lastSeen: DateTime.now(),
      isSimulated: true,
    );
    final simRepo = createConnectionService(BtTransport.simulated);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BleTerminalScreen(
          device: fakeDevice,
          repository: simRepo,
          onConnected: widget.onDeviceConnected == null
              ? null
              : (d, repo) {
                  widget.onDeviceConnected!(d, repo);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    _scanTimer?.cancel();
    setState(() {
      _state = _ScanState.scanning;
      _devices = [];
      _errorMessage = null;
    });

    _sub?.cancel();
    _sub = _repository!.scanResults.listen(
      (devices) => setState(() => _devices = devices),
      onError: (Object e) {
        _scanTimer?.cancel();
        if (mounted && _state == _ScanState.scanning) {
          setState(() {
            _state = _ScanState.error;
            _errorMessage = e is BleException ? e.message : e.toString();
          });
          _retryIfNeeded();
        }
      },
      onDone: () {
        _scanTimer?.cancel();
        if (mounted && _state == _ScanState.scanning) {
          setState(() => _state = _ScanState.idle);
        }
      },
    );

    // Timer taramayı _scanDuration sonra otomatik durdurur.
    // await startScan() BLE modunda tarama süresi boyunca bloklanabileceğinden
    // timer await'ten önce başlatılıyor.
    _scanTimer = Timer(_scanDuration, () => _stopScan());
    try {
      await _repository!.startScan();
    } on BleException catch (e) {
      _scanTimer?.cancel();
      if (mounted && _state == _ScanState.scanning) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = e.message;
        });
        _retryIfNeeded();
      }
    } catch (e) {
      _scanTimer?.cancel();
      if (mounted && _state == _ScanState.scanning) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Beklenmeyen hata: $e';
        });
        _retryIfNeeded();
      }
    }
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    await _repository!.stopScan();
    if (mounted) setState(() => _state = _ScanState.idle);
  }

  void _retryIfNeeded() {
    if (!mounted || _autoRetryCount >= _maxAutoRetry) return;
    _autoRetryCount++;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted && _state == _ScanState.error) _startScan();
    });
  }

  Widget _buildFilterStrip() {
    final hc = _hiddenCount;
    if (hc == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: CalColors.surfaceLow,
      child: Row(
        children: [
          Icon(
            _showAll ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined,
            size: 14,
            color: CalColors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            _showAll
                ? 'Sinyal filtresi devre dışı ($hc cihaz)'
                : '$hc zayıf sinyalli cihaz gizlendi',
            style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll ? 'Filtreyi Aç' : 'Tümünü Göster',
              style: TextStyle(
                fontSize: 12,
                color: CalColors.primaryContainer,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: CalColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDevices;
    return Scaffold(
      backgroundColor: CalColors.background,
      appBar: AppBar(
        backgroundColor: CalColors.primaryContainer,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Bluetooth ile Cihaz Tara',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_showSelector) ...[
            if (_state == _ScanState.scanning)
              TextButton.icon(
                onPressed: _stopScan,
                icon: const Icon(Icons.stop, color: Color(0xFFDC2626)),
                label: const Text('Durdur', style: TextStyle(color: Color(0xFFDC2626))),
              )
            else
              TextButton.icon(
                onPressed: () {
                  _autoRetryCount = 0;
                  _startScan();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Tara', style: TextStyle(color: Colors.white)),
              ),
          ],
        ],
      ),
      body: _showSelector
          ? _TransportSelector(onSelect: _selectTransport)
          : Column(
              children: [
                _StatusBanner(state: _state, deviceCount: filtered.length),
                if (_errorMessage != null)
                  _ErrorBanner(message: _errorMessage!, onRetry: _startScan),
                _buildFilterStrip(),
                Expanded(
                  child: _DeviceList(
                    devices: filtered,
                    state: _state,
                    transport: _selectedTransport ?? btTransport,
                    onDeviceConnected: widget.onDeviceConnected,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Transport Seçici ────────────────────────────────────────────────────────

class _TransportSelector extends StatelessWidget {
  const _TransportSelector({required this.onSelect});
  final void Function(BtTransport) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Bluetooth Türü Seçin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CalColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cihazınıza uygun bağlantı yöntemini seçin.',
            style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TransportCard(
                    icon: Icons.bluetooth,
                    title: 'Classic\nBluetooth',
                    subtitle: Platform.isIOS
                        ? 'SPP / Seri Port\niOS\'ta desteklenmiyor'
                        : 'SPP / Seri Port\nsadece Android',
                    onTap: () => onSelect(BtTransport.classic),
                    enabled: !Platform.isIOS,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TransportCard(
                    icon: Icons.bluetooth_searching,
                    title: 'BLE',
                    subtitle: 'Düşük Enerji\niOS & Android için',
                    onTap: () => onSelect(BtTransport.ble),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TransportCard(
                    icon: Icons.science_outlined,
                    title: 'Test\nModu',
                    subtitle: 'Gerçek cihaz\ngerekmez',
                    onTap: () => onSelect(BtTransport.simulated),
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  const _TransportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: CalColors.surfaceLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CalColors.outlineVariant, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor ?? CalColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CalColors.onSurface,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: CalColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Durum Bandı ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.deviceCount});
  final _ScanState state;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon, label) = switch (state) {
      _ScanState.scanning => (
          CalColors.primaryContainer,
          CalColors.surfaceContainer,
          Icons.bluetooth_searching,
          'Taranıyor...',
        ),
      _ScanState.error => (
          CalColors.error,
          CalColors.errorContainer,
          Icons.error_outline,
          'Hata oluştu',
        ),
      _ScanState.idle => (
          CalColors.onSurfaceVariant,
          CalColors.surfaceLow,
          Icons.bluetooth,
          'Hazır',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bg,
      child: Row(
        children: [
          if (state == _ScanState.scanning)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: CalColors.primaryContainer),
            )
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (deviceCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$deviceCount cihaz',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Hata Bandı ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CalColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, color: CalColors.error, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: CalColors.onErrorContainer, fontSize: 12, height: 1.4),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'Tekrar Dene',
                style: TextStyle(
                  color: CalColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Cihaz Listesi ───────────────────────────────────────────────────────────

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.state,
    required this.transport,
    this.onDeviceConnected,
  });
  final List<BleDeviceResult> devices;
  final _ScanState state;
  final BtTransport transport;
  final void Function(BleDeviceResult, BleConnectionRepository)? onDeviceConnected;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 56,
              color: CalColors.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              state == _ScanState.scanning
                  ? 'Cihazlar aranıyor...'
                  : '"Tara" butonuna basarak başlayın.',
              style: TextStyle(color: CalColors.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: devices.length,
      itemBuilder: (context, i) => _DeviceCard(
        device: devices[i],
        transport: transport,
        onDeviceConnected: onDeviceConnected,
      ),
    );
  }
}

// ─── Cihaz Kartı ─────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.transport, this.onDeviceConnected});
  final BleDeviceResult device;
  final BtTransport transport;
  final void Function(BleDeviceResult, BleConnectionRepository)? onDeviceConnected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BleTerminalScreen(
            device: device,
            repository: createConnectionService(transport),
            onConnected: onDeviceConnected == null ? null : (d, repo) {
              onDeviceConnected!(d, repo);
              Navigator.pop(context); // terminal'i kapat
              Navigator.pop(context); // scan ekranını kapat
            },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CalColors.surfaceLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: device.isTachographDevice
                ? const Color(0xFF15803D)
                : CalColors.outlineVariant,
            width: device.isTachographDevice ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: TextStyle(
                          color: device.hasName
                              ? CalColors.onSurface
                              : CalColors.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontStyle: device.hasName ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      if (device.isTachographDevice) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15803D),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TAKOGRAF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _RssiWidget(rssi: device.rssi),
              ],
            ),
            const SizedBox(height: 6),
            _InfoLine(Icons.fingerprint, device.deviceId),
            if (device.serviceUuids.isNotEmpty)
              _InfoLine(
                Icons.settings_input_antenna,
                device.serviceUuids.join(', '),
              ),
            if (device.manufacturerInfo != null)
              _InfoLine(Icons.business_outlined, device.manufacturerInfo!),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = CalColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _RssiWidget extends StatelessWidget {
  const _RssiWidget({required this.rssi});
  final int rssi;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (rssi) {
      >= -60 => (Icons.signal_cellular_alt, const Color(0xFF16A34A)),
      >= -75 => (Icons.signal_cellular_alt_2_bar, const Color(0xFF78716C)),
      >= -90 => (Icons.signal_cellular_alt_1_bar, const Color(0xFFD97706)),
      _ => (Icons.signal_cellular_0_bar, const Color(0xFFDC2626)),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 3),
        Text(
          '$rssi dBm',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

