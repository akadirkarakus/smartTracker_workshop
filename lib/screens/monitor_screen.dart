import 'package:flutter/material.dart';
import '../models/tachograph_data.dart';
import '../services/tachograph_simulator.dart';
import 'ble_scan_screen.dart';

const _bg = Color(0xFFE8F4F8);
const _cardBg = Colors.white;
const _cardBorder = Color(0xFFC4DDE6);
const _labelColor = Color(0xFF4A7A8A);
const _titleColor = Color(0xFF1A5F7A);
const _valueColor = Color(0xFF0D3347);
const _appBarBg = Color(0xFF1A5F7A);
const _appBarText = Colors.white;

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late final TachographSimulator _simulator;

  @override
  void initState() {
    super.initState();
    _simulator = TachographSimulator();
  }

  @override
  void dispose() {
    _simulator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarBg,
        elevation: 0,
        shadowColor: _cardBorder,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Takograf İzleme',
          style: TextStyle(color: _appBarText, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          _StatusIcon(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BleScanScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.circle, color: Color(0xFF16A34A), size: 10),
              label: const Text(
                'SİMÜLASYON',
                style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              backgroundColor: const Color(0xFFDCFCE7),
              side: const BorderSide(color: Color(0xFFBBF7D0)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<TachographData>(
        stream: _simulator.stream,
        initialData: _simulator.current,
        builder: (context, snapshot) {
          final data = snapshot.data!;
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                child: Column(
                  children: [
                    _DriverVehicleCard(data: data),
                    const SizedBox(height: 10),
                    _StatusCard(data: data),
                    const SizedBox(height: 10),
                    _DrivingTimesCard(data: data),
                    const SizedBox(height: 10),
                    _BreakRestCard(data: data),
                    const SizedBox(height: 10),
                    _OdometerCard(data: data),
                    const SizedBox(height: 10),
                    _AlertsCard(data: data),
                    const SizedBox(height: 10),
                    _LocationCard(data: data),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ControlBar(simulator: _simulator, activity: data.activity),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Bluetooth bağlantı butonu (kendi AnimationController'ı var) ─────────────

class _StatusIcon extends StatefulWidget {
  final VoidCallback onTap;
  const _StatusIcon({required this.onTap});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_searching, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'BAĞLAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Kartlar ─────────────────────────────────────────────────────────────────

class _DriverVehicleCard extends StatelessWidget {
  const _DriverVehicleCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sürücü & Araç',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _InfoRow('Sürücü', data.driverName),
          _InfoRow('Kart No', data.cardNumber),
          _InfoRow('Plaka', data.plateNumber),
          _InfoRow('VIN', data.vin),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(data.activity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            data.activity.label,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BigMetric('HIZ', '${data.speedKmh.toStringAsFixed(0)} km/h', Icons.speed, color),
              _BigMetric('DEVİR', '${data.rpm} RPM', Icons.settings_outlined, color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Son güncelleme: ${_timeStr(data.timestamp)}',
            style: const TextStyle(color: _labelColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _activityColor(DriverActivity a) {
    switch (a) {
      case DriverActivity.driving:
        return const Color(0xFF1A73E8);
      case DriverActivity.rest:
        return const Color(0xFF16A34A);
      case DriverActivity.available:
        return const Color(0xFFD97706);
      case DriverActivity.otherWork:
        return const Color(0xFF7C3AED);
    }
  }
}

class _DrivingTimesCard extends StatelessWidget {
  const _DrivingTimesCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    final isWarning = data.remainingDriving.inMinutes <= 30;
    return _SectionCard(
      title: 'Sürüş Süreleri',
      icon: Icons.timer_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _TimeMetric('Kesintisiz\nSürüş', data.continuousDriving)),
              Expanded(
                child: _TimeMetric(
                  'Kalan Hak',
                  data.remainingDriving,
                  warningColor: isWarning ? const Color(0xFFDC2626) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _TimeMetric('Günlük\nToplam', data.dailyDriving)),
              Expanded(child: _TimeMetric('Haftalık\nToplam', data.weeklyDriving)),
            ],
          ),
          if (isWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Kalan sürüş hakkı 30 dakikanın altında!',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakRestCard extends StatelessWidget {
  const _BreakRestCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Mola & Dinlenme',
      icon: Icons.coffee_outlined,
      child: Row(
        children: [
          Expanded(child: _TimeMetric('Son Mola\nSüresi', data.lastBreak)),
          Expanded(child: _TimeMetric('Günlük\nDinlenme', data.dailyRest)),
        ],
      ),
    );
  }
}

class _OdometerCard extends StatelessWidget {
  const _OdometerCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Mesafe',
      icon: Icons.route_outlined,
      child: _InfoRow('Kilometre Sayacı', '${data.odometerKm.toStringAsFixed(1)} km'),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Durum & Uyarılar',
      icon: Icons.notifications_outlined,
      child: Column(
        children: [
          _InfoRow(
            'Hız İhlali (24s)',
            '${data.speedViolations24h} adet',
            valueColor: data.speedViolations24h > 0 ? const Color(0xFFDC2626) : null,
          ),
          _InfoRow('Kart Durumu', data.cardStatus),
          _InfoRow('Güç Durumu', data.powerStatus),
          _InfoRow('Son Kalibrasyon', _dateStr(data.lastCalibrationDate)),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.data});
  final TachographData data;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Konum (GPS)',
      icon: Icons.location_on_outlined,
      child: Column(
        children: [
          _InfoRow('Enlem', data.latitude.toStringAsFixed(4)),
          _InfoRow('Boylam', data.longitude.toStringAsFixed(4)),
          _InfoRow('Son Güncelleme', _timeStr(data.locationTimestamp)),
        ],
      ),
    );
  }
}

// ─── Kontrol Çubuğu ──────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.simulator, required this.activity});
  final TachographSimulator simulator;
  final DriverActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFC4DDE6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _CtrlBtn(
                label: 'Sürüş\nBaşlat',
                icon: Icons.play_arrow,
                color: const Color(0xFF1A73E8),
                active: activity == DriverActivity.driving,
                onTap: simulator.startDriving,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CtrlBtn(
                label: 'Mola\nVer',
                icon: Icons.pause,
                color: const Color(0xFFD97706),
                active: activity == DriverActivity.available,
                onTap: simulator.takeBreak,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CtrlBtn(
                label: 'İstirahat',
                icon: Icons.hotel,
                color: const Color(0xFF16A34A),
                active: activity == DriverActivity.rest,
                onTap: simulator.setRest,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CtrlBtn(
                label: 'Diğer\nÇalışma',
                icon: Icons.work_outline,
                color: const Color(0xFF7C3AED),
                active: activity == DriverActivity.otherWork,
                onTap: simulator.setWork,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yardımcı widget'lar ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _labelColor, size: 15),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _labelColor, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric(this.label, this.duration, {this.warningColor});
  final String label;
  final Duration duration;
  final Color? warningColor;

  @override
  Widget build(BuildContext context) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = h > 0 ? '$h:$m:$s' : '$m:$s';

    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: warningColor ?? _valueColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _labelColor, fontSize: 11),
        ),
      ],
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: _labelColor, fontSize: 11)),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(60) : const Color(0xFFD8EDF3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : _cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? color : _labelColor, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? color : _labelColor,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Yardımcı fonksiyonlar ────────────────────────────────────────────────────

String _timeStr(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

String _dateStr(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
