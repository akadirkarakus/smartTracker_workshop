enum DriverActivity { driving, rest, available, otherWork }

extension DriverActivityLabel on DriverActivity {
  String get label {
    switch (this) {
      case DriverActivity.driving:
        return 'Sürüş';
      case DriverActivity.rest:
        return 'İstirahat';
      case DriverActivity.available:
        return 'Hazır';
      case DriverActivity.otherWork:
        return 'Diğer Çalışma';
    }
  }
}

class TachographData {
  final String driverName;
  final String cardNumber;
  final String plateNumber;
  final String vin;

  final DriverActivity activity;
  final double speedKmh;
  final int rpm;

  final Duration continuousDriving;
  final Duration dailyDriving;
  final Duration weeklyDriving;
  final Duration lastBreak;
  final Duration dailyRest;
  final Duration remainingDriving;

  final double odometerKm;

  final int speedViolations24h;
  final String cardStatus;
  final String powerStatus;
  final DateTime lastCalibrationDate;

  final double latitude;
  final double longitude;
  final DateTime locationTimestamp;

  final DateTime timestamp;

  const TachographData({
    required this.driverName,
    required this.cardNumber,
    required this.plateNumber,
    required this.vin,
    required this.activity,
    required this.speedKmh,
    required this.rpm,
    required this.continuousDriving,
    required this.dailyDriving,
    required this.weeklyDriving,
    required this.lastBreak,
    required this.dailyRest,
    required this.remainingDriving,
    required this.odometerKm,
    required this.speedViolations24h,
    required this.cardStatus,
    required this.powerStatus,
    required this.lastCalibrationDate,
    required this.latitude,
    required this.longitude,
    required this.locationTimestamp,
    required this.timestamp,
  });

  TachographData copyWith({
    DriverActivity? activity,
    double? speedKmh,
    int? rpm,
    Duration? continuousDriving,
    Duration? dailyDriving,
    Duration? weeklyDriving,
    Duration? lastBreak,
    Duration? dailyRest,
    Duration? remainingDriving,
    double? odometerKm,
    int? speedViolations24h,
    DateTime? timestamp,
  }) {
    return TachographData(
      driverName: driverName,
      cardNumber: cardNumber,
      plateNumber: plateNumber,
      vin: vin,
      activity: activity ?? this.activity,
      speedKmh: speedKmh ?? this.speedKmh,
      rpm: rpm ?? this.rpm,
      continuousDriving: continuousDriving ?? this.continuousDriving,
      dailyDriving: dailyDriving ?? this.dailyDriving,
      weeklyDriving: weeklyDriving ?? this.weeklyDriving,
      lastBreak: lastBreak ?? this.lastBreak,
      dailyRest: dailyRest ?? this.dailyRest,
      remainingDriving: remainingDriving ?? this.remainingDriving,
      odometerKm: odometerKm ?? this.odometerKm,
      speedViolations24h: speedViolations24h ?? this.speedViolations24h,
      cardStatus: cardStatus,
      powerStatus: powerStatus,
      lastCalibrationDate: lastCalibrationDate,
      latitude: latitude,
      longitude: longitude,
      locationTimestamp: locationTimestamp,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
