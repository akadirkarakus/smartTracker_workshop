import 'dart:async';
import 'dart:math';
import '../models/tachograph_data.dart';

// AB 561/2006 limitleri
const Duration _maxContinuousDriving = Duration(hours: 4, minutes: 30);
const double _speedLimit = 90.0;

class TachographSimulator {
  final _controller = StreamController<TachographData>.broadcast();
  Timer? _timer;
  final _random = Random();

  TachographData _current = TachographData(
    driverName: 'Ahmet Yılmaz',
    cardNumber: 'TR-2024-00437',
    plateNumber: '34 ABC 123',
    vin: 'WDB9634031L123456',
    activity: DriverActivity.available,
    speedKmh: 0,
    rpm: 800,
    continuousDriving: Duration.zero,
    dailyDriving: Duration.zero,
    weeklyDriving: const Duration(hours: 12, minutes: 35),
    lastBreak: Duration.zero,
    dailyRest: Duration.zero,
    remainingDriving: _maxContinuousDriving,
    odometerKm: 87432.5,
    speedViolations24h: 0,
    cardStatus: 'Normal',
    powerStatus: 'Normal',
    lastCalibrationDate: DateTime(2024, 11, 15),
    latitude: 41.0082,
    longitude: 28.9784,
    locationTimestamp: DateTime.now(),
    timestamp: DateTime.now(),
  );

  double _targetSpeed = 0;

  Stream<TachographData> get stream => _controller.stream;
  TachographData get current => _current;

  TachographSimulator() {
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    _controller.add(_current);
  }

  void _tick(Timer _) {
    final now = DateTime.now();
    final isDriving = _current.activity == DriverActivity.driving;
    final isResting =
        _current.activity == DriverActivity.rest ||
        _current.activity == DriverActivity.available;

    final newSpeed = _smoothSpeed(_current.speedKmh, _targetSpeed);
    final newRpm = _calcRpm(newSpeed, isDriving);

    Duration contDriving = _current.continuousDriving;
    Duration dailyDriving = _current.dailyDriving;
    Duration weeklyDriving = _current.weeklyDriving;
    Duration lastBreak = _current.lastBreak;
    Duration dailyRest = _current.dailyRest;
    double odometer = _current.odometerKm;
    int violations = _current.speedViolations24h;

    if (isDriving) {
      contDriving += const Duration(seconds: 1);
      dailyDriving += const Duration(seconds: 1);
      weeklyDriving += const Duration(seconds: 1);
      odometer += newSpeed / 3600.0;
      if (newSpeed > _speedLimit) {
        violations++;
      }
    } else if (isResting) {
      lastBreak += const Duration(seconds: 1);
      dailyRest += const Duration(seconds: 1);
      if (contDriving > Duration.zero) {
        contDriving = Duration.zero;
      }
    }

    final remaining = _maxContinuousDriving - contDriving;
    final remainingDriving = remaining.isNegative ? Duration.zero : remaining;

    _current = _current.copyWith(
      speedKmh: (newSpeed * 10).round() / 10.0,
      rpm: newRpm,
      continuousDriving: contDriving,
      dailyDriving: dailyDriving,
      weeklyDriving: weeklyDriving,
      lastBreak: lastBreak,
      dailyRest: dailyRest,
      remainingDriving: remainingDriving,
      odometerKm: (odometer * 10).round() / 10.0,
      speedViolations24h: violations,
      timestamp: now,
    );

    _controller.add(_current);
  }

  double _smoothSpeed(double current, double target) {
    final diff = target - current;
    if (diff.abs() < 0.5) return target;
    final step = 2.0 + _random.nextDouble() * 1.5;
    return current + (diff > 0 ? step : -step);
  }

  int _calcRpm(double speed, bool driving) {
    if (!driving) return 700 + _random.nextInt(150);
    final base = (speed * 30).clamp(800, 3200).toInt();
    return base + _random.nextInt(200) - 100;
  }

  void startDriving() {
    _targetSpeed = 60 + _random.nextDouble() * 30;
    _setActivity(DriverActivity.driving);
  }

  void takeBreak() {
    _targetSpeed = 0;
    _setActivity(DriverActivity.available);
  }

  void setRest() {
    _targetSpeed = 0;
    _setActivity(DriverActivity.rest);
  }

  void setWork() {
    _targetSpeed = 0;
    _setActivity(DriverActivity.otherWork);
  }

  void setAvailable() {
    _targetSpeed = 0;
    _setActivity(DriverActivity.available);
  }

  void _setActivity(DriverActivity activity) {
    _current = _current.copyWith(activity: activity, timestamp: DateTime.now());
    _controller.add(_current);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
