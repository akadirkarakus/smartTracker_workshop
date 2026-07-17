import 'dart:async';

import 'package:flutter/material.dart';
import '../../../bluetooth/models/ble_device_result.dart';
import '../../../bluetooth/repositories/ble_connection_repository.dart';
import '../../../kline/kline_service.dart';
import '../../../models/calibration_data.dart';
import '../../ble_terminal_screen.dart';
import '../pin_entry_screen.dart';
import '../motion_sensor_pairing_screen.dart';
import '../w_constant_measurement_screen.dart';

class DashboardTab extends StatelessWidget {
  final bool isPinAuthenticated;
  final void Function(bool) onAuthChanged;
  final void Function(int tabIndex) onNavigate;
  final List<RecentReport> reports;
  final List<CalParam> params;
  final List<DtcCode> dtcCodes;
  final Future<bool> Function(String paramId, String value)? onWriteParam;
  final BleDeviceResult? connectedDevice;
  final BleConnectionRepository? btRepository;
  final VoidCallback onConnectDevice;
  final VoidCallback onDisconnectDevice;
  final KLineService? klineService;
  final String? bleManufacturer;
  final String? bleModel;
  final String? deviceHwNumber;
  final String? deviceHwVersion;
  final String? deviceSwVersion;
  final String? deviceSerial;
  final String? deviceSystemSupplierId;
  final String? deviceSwNumber;
  final String? deviceExhaustRegNumber;

  const DashboardTab({
    super.key,
    required this.isPinAuthenticated,
    required this.onAuthChanged,
    required this.onNavigate,
    required this.reports,
    required this.params,
    required this.dtcCodes,
    required this.connectedDevice,
    required this.onConnectDevice,
    required this.onDisconnectDevice,
    this.btRepository,
    this.onWriteParam,
    this.klineService,
    this.bleManufacturer,
    this.bleModel,
    this.deviceHwNumber,
    this.deviceHwVersion,
    this.deviceSwVersion,
    this.deviceSerial,
    this.deviceSystemSupplierId,
    this.deviceSwNumber,
    this.deviceExhaustRegNumber,
  });

  String? _paramValue(String id) {
    try {
      return params.firstWhere((p) => p.id == id).value;
    } catch (_) {
      return null;
    }
  }

  void _openPin(BuildContext context) {
    if (klineService == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PinEntryScreen(
          onResult: (success) {
            onAuthChanged(success);
            Navigator.pop(context);
          },
          onRequestSeed: () async {
            try {
              return await klineService!.requestSeed();
            } catch (_) {
              return null;
            }
          },
          onSendKey: (pin) async {
            try {
              final result = await klineService!.sendKey(pin);
              return (result.success, result.nrc);
            } catch (_) {
              return (false, null);
            }
          },
          onCancel: () {
            unawaited(() async {
              try {
                await klineService!.cancelSecurityAccess();
              } catch (_) {
                // Bağlantı zaten kopmuş olabilir — sessizce yut.
              }
            }());
          },
        ),
      ),
    );
  }

  void _openMsPair(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MotionSensorPairingScreen(klineService: klineService),
      ),
    );
  }

  void _openWMeasure(BuildContext context) {
    if (onWriteParam == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WConstantMeasurementScreen(
          onWriteResult: (v) => onWriteParam!('w_constant', v),
        ),
      ),
    );
  }

  void _openTerminal(BuildContext context) {
    if (connectedDevice == null || btRepository == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BleTerminalScreen(
          device: connectedDevice!,
          repository: btRepository!,
          ownsConnection: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = connectedDevice != null;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bluetooth connect card (animates between big/compact)
                _BluetoothConnectCard(
                  connectedDevice: connectedDevice,
                  onConnect: onConnectDevice,
                  onDisconnect: onDisconnectDevice,
                  onOpenTerminal: btRepository != null ? () => _openTerminal(context) : null,
                ),
                const SizedBox(height: 12),

                // PIN status card (only when connected)
                if (isConnected) ...[
                  _DeviceStatusCard(isAuthenticated: isPinAuthenticated, onPinTap: () => _openPin(context)),
                  const SizedBox(height: 12),
                  _DeviceInfoCard(
                    bleManufacturer: bleManufacturer,
                    bleModel: bleModel,
                    hwNumber: deviceHwNumber,
                    hwVersion: deviceHwVersion,
                    swVersion: deviceSwVersion,
                    serial: deviceSerial,
                    systemSupplierId: deviceSystemSupplierId,
                    swNumber: deviceSwNumber,
                    exhaustRegNumber: deviceExhaustRegNumber,
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 8),

                // Cihaz Durumu Özeti — sadece bağlıyken
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  sizeCurve: Curves.easeOut,
                  firstCurve: Curves.easeOut,
                  secondCurve: Curves.easeOut,
                  crossFadeState: isConnected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cihaz Durumu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                      const SizedBox(height: 10),
                      _DeviceStatusSummaryCard(
                        vrn: _paramValue('vrn'),
                        vin: _paramValue('vin'),
                        speedLimit: _paramValue('speed_limit'),
                        odometer: _paramValue('odometer'),
                        nextCalDate: _paramValue('next_cal_date'),
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // Uyarı Kartları — sadece bağlıyken
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  sizeCurve: Curves.easeOut,
                  firstCurve: Curves.easeOut,
                  secondCurve: Curves.easeOut,
                  crossFadeState: isConnected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text('Uyarılar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                      const SizedBox(height: 10),
                      _WarningCards(
                        nextCalDate: _paramValue('next_cal_date'),
                        dtcCodes: dtcCodes,
                        onDiagnosticsTap: () => onNavigate(2),
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // Özel İşlemler — animasyonla görünür/kaybolur
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  sizeCurve: Curves.easeOut,
                  firstCurve: Curves.easeOut,
                  secondCurve: Curves.easeOut,
                  crossFadeState: isConnected ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text('Özel İşlemler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurface)),
                      const SizedBox(height: 10),
                      _SpecialOpsRow(
                        onMsPair: () => _openMsPair(context),
                        onWMeasure: () => _openWMeasure(context),
                      ),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // Son Raporlar — her zaman görünür
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Son Raporlar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CalColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigate(3),
                      style: TextButton.styleFrom(foregroundColor: CalColors.primary, padding: EdgeInsets.zero),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Tümünü Gör', style: TextStyle(fontSize: 13)),
                          Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),

        // Report list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (i < reports.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _ReportCard(report: reports[i]),
                );
              }
              return const SizedBox(height: 16);
            },
            childCount: reports.length + 1,
          ),
        ),

        // Throughput chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _WeeklyThroughput(),
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────

class _BluetoothConnectCard extends StatelessWidget {
  final BleDeviceResult? connectedDevice;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback? onOpenTerminal;

  const _BluetoothConnectCard({
    required this.connectedDevice,
    required this.onConnect,
    required this.onDisconnect,
    this.onOpenTerminal,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = connectedDevice != null;
    final isSimulated = connectedDevice?.isSimulated ?? false;

    if (!isConnected) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE65100), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF8F00), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55E65100),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onConnect,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: _DisconnectedCardRow(key: ValueKey('disconnected')),
            ),
          ),
        ),
      );
    }

    final cardColor = isSimulated ? const Color(0xFF92400E) : const Color(0xFF1B5E20);
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: _ConnectedCardRow(
            key: const ValueKey('connected'),
            device: connectedDevice!,
            isSimulated: isSimulated,
            onDisconnect: onDisconnect,
            onOpenTerminal: onOpenTerminal,
          ),
        ),
      ),
    );
  }
}

class _DisconnectedCardRow extends StatefulWidget {
  const _DisconnectedCardRow({super.key});

  @override
  State<_DisconnectedCardRow> createState() => _DisconnectedCardRowState();
}

class _DisconnectedCardRowState extends State<_DisconnectedCardRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13 + 0.12 * _pulseCtrl.value),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.bluetooth_searching, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cihaz Bağla',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text(
                'Takograf cihazını taramak için dokunun',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) => Transform.scale(
            scale: 1.0 + 0.08 * _pulseCtrl.value,
            child: Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.55 + 0.30 * _pulseCtrl.value),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectedCardRow extends StatelessWidget {
  final BleDeviceResult device;
  final bool isSimulated;
  final VoidCallback onDisconnect;
  final VoidCallback? onOpenTerminal;

  const _ConnectedCardRow({
    super.key,
    required this.device,
    required this.isSimulated,
    required this.onDisconnect,
    this.onOpenTerminal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.bluetooth_connected, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      isSimulated ? 'Test Modu Aktif' : 'Bağlantı Başarılı',
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (isSimulated) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SİMÜLASYON',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                device.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              if (device.rssi != 0)
                Text(
                  'Sinyal: ${device.rssi} dBm',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
            ],
          ),
        ),
        if (onOpenTerminal != null) ...[
          IconButton(
            onPressed: onOpenTerminal,
            tooltip: 'Terminal',
            icon: const Icon(Icons.terminal, color: Colors.white, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        TextButton(
          onPressed: onDisconnect,
          style: TextButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Kes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  final bool isAuthenticated;
  final VoidCallback onPinTap;

  const _DeviceStatusCard({required this.isAuthenticated, required this.onPinTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yetkilendirme', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isAuthenticated ? CalColors.accent : CalColors.outline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAuthenticated ? 'Doğrulandı' : 'Kilitli',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isAuthenticated ? CalColors.accent : CalColors.outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPinTap,
            style: TextButton.styleFrom(
              backgroundColor: isAuthenticated ? CalColors.tertiaryFixed : CalColors.surfaceContainer,
              foregroundColor: isAuthenticated ? CalColors.onTertiaryFixed : CalColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isAuthenticated ? 'Oturum Açık' : 'PIN Gir',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// BLE Device Information servisinden okunan üretici/model ile takografın
// K-Line üzerinden bildirdiği HW/SW/Seri bilgisini gösterir. Alanların hiçbiri
// okunamadıysa (adaptör bu servisi/karakteristikleri desteklemiyor olabilir)
// kart hiç render edilmez.
class _DeviceInfoCard extends StatelessWidget {
  final String? bleManufacturer;
  final String? bleModel;
  final String? hwNumber;
  final String? hwVersion;
  final String? swVersion;
  final String? serial;
  final String? systemSupplierId;
  final String? swNumber;
  final String? exhaustRegNumber;

  const _DeviceInfoCard({
    this.bleManufacturer,
    this.bleModel,
    this.hwNumber,
    this.hwVersion,
    this.swVersion,
    this.serial,
    this.systemSupplierId,
    this.swNumber,
    this.exhaustRegNumber,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (bleManufacturer != null) ('Üretici (BLE)', bleManufacturer!),
      if (bleModel != null) ('Model (BLE)', bleModel!),
      if (hwNumber != null) ('HW No', hwNumber!),
      if (hwVersion != null) ('HW Versiyon', hwVersion!),
      if (swVersion != null) ('SW Versiyon', swVersion!),
      if (serial != null) ('Seri No', serial!),
      if (systemSupplierId != null) ('Tedarikçi Kimliği', systemSupplierId!),
      if (swNumber != null) ('SW Numarası', swNumber!),
      if (exhaustRegNumber != null) ('Muayene/Tip Onay No', exhaustRegNumber!),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

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
          Text('Cihaz Bilgisi', style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: rows
                .map((r) => SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$1, style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant)),
                          Text(
                            r.$2,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusSummaryCard extends StatelessWidget {
  final String? vrn;
  final String? vin;
  final String? speedLimit;
  final String? odometer;
  final String? nextCalDate;

  const _DeviceStatusSummaryCard({
    this.vrn,
    this.vin,
    this.speedLimit,
    this.odometer,
    this.nextCalDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: [
          _StatusRow(Icons.directions_car_outlined, 'Plaka', vrn),
          _StatusRow(Icons.fingerprint, 'VIN', vin),
          _StatusRow(Icons.speed_outlined, 'Hız Limiti', speedLimit != null ? '$speedLimit km/h' : null),
          _StatusRow(Icons.route_outlined, 'Kilometre', odometer != null ? '$odometer km' : null),
          _StatusRow(Icons.event_outlined, 'Sonraki Kalibrasyon', nextCalDate, isLast: true),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isLast;

  const _StatusRow(this.icon, this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: CalColors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value ?? '—',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value != null ? CalColors.onSurface : CalColors.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: CalColors.outlineVariant),
      ],
    );
  }
}

class _WarningCards extends StatelessWidget {
  final String? nextCalDate;
  final List<DtcCode> dtcCodes;
  final VoidCallback? onDiagnosticsTap;

  const _WarningCards({this.nextCalDate, required this.dtcCodes, this.onDiagnosticsTap});

  @override
  Widget build(BuildContext context) {
    final warnings = <_WarningItem>[];

    // Kalibrasyon tarihi uyarısı
    if (nextCalDate != null) {
      final date = DateTime.tryParse(nextCalDate!);
      if (date != null) {
        final now = DateTime.now();
        final diff = date.difference(now).inDays;
        if (diff < 0) {
          warnings.add(_WarningItem(
            icon: Icons.event_busy_outlined,
            title: 'Kalibrasyon Süresi Doldu',
            subtitle: '${diff.abs()} gün önce doldu',
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEE2E2),
          ));
        } else if (diff <= 30) {
          warnings.add(_WarningItem(
            icon: Icons.event_note_outlined,
            title: 'Kalibrasyon Tarihi Yaklaşıyor',
            subtitle: '$diff gün kaldı',
            color: const Color(0xFFD97706),
            bg: const Color(0xFFFEF3C7),
          ));
        }
      }
    }

    // DTC uyarısı
    final activeDtcs = dtcCodes.where((d) => d.isActive).length;
    final totalDtcs = dtcCodes.length;
    if (activeDtcs > 0) {
      warnings.add(_WarningItem(
        icon: Icons.error_outline,
        title: 'Aktif Arıza Kodu',
        subtitle: '$activeDtcs aktif / $totalDtcs toplam DTC',
        color: const Color(0xFFDC2626),
        bg: const Color(0xFFFEE2E2),
        onTap: onDiagnosticsTap,
      ));
    } else if (totalDtcs > 0) {
      warnings.add(_WarningItem(
        icon: Icons.warning_amber_outlined,
        title: 'Pasif Arıza Kodu',
        subtitle: '$totalDtcs geçmiş DTC kaydı',
        color: const Color(0xFFD97706),
        bg: const Color(0xFFFEF3C7),
        onTap: onDiagnosticsTap,
      ));
    }

    if (warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
            SizedBox(width: 10),
            Text(
              'Sistem Normal — Herhangi bir uyarı yok',
              style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: warnings
          .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: w.bg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: w.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: w.color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(w.icon, color: w.color, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: w.color)),
                                Text(w.subtitle, style: TextStyle(fontSize: 11, color: w.color.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                          if (w.onTap != null)
                            Icon(Icons.chevron_right, color: w.color.withValues(alpha: 0.6), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _WarningItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;
  const _WarningItem({required this.icon, required this.title, required this.subtitle, required this.color, required this.bg, this.onTap});
}

class _SpecialOpsRow extends StatelessWidget {
  final VoidCallback onMsPair;
  final VoidCallback onWMeasure;

  const _SpecialOpsRow({required this.onMsPair, required this.onWMeasure});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _OpCard(
              onTap: onMsPair,
              icon: Icons.sensors,
              label: 'Sensör Eşleştir',
              color: CalColors.tertiaryContainer,
              iconColor: CalColors.tertiaryFixed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OpCard(
              onTap: onWMeasure,
              icon: Icons.speed,
              label: 'W-Sabiti Ölç',
              color: CalColors.primaryContainer,
              iconColor: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  const _OpCard({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final RecentReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: CalColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.local_shipping_outlined, color: CalColors.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        report.vehicleName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(report.time, style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: report.isSuccess ? CalColors.tertiaryFixed : CalColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        report.statusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: report.isSuccess ? CalColors.onTertiaryFixed : CalColors.onSecondaryContainer),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(report.plate, style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyThroughput extends StatelessWidget {
  static const List<String> _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CalColors.surfaceHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Haftalık Kalibrasyon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalColors.primary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: 0.05,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: CalColors.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_days[i], style: TextStyle(fontSize: 10, color: CalColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Henüz veri yok',
              style: TextStyle(fontSize: 11, color: CalColors.outline),
            ),
          ),
        ],
      ),
    );
  }
}
