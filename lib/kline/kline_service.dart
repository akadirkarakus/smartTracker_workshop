// K-LINE servis katmanı — CalibrationMessages.md Flow 1–21
// Her Flow bir async metod veya Stream olarak implement edilmiştir.

import 'dart:async';

import '../bluetooth/models/log_entry.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../core/app_logger.dart';
import 'kline_codec.dart';
import 'kline_frame.dart';
import 'kline_records.dart';

// ── Sonuç modelleri ────────────────────────────────────────────────────────

class SecurityAccessResult {
  const SecurityAccessResult({required this.success, this.nrc});
  final bool success;
  final int? nrc;
}

class CalibrationSnapshot {
  const CalibrationSnapshot({
    this.vin,
    this.currentDateTime,
    this.odometer,
    this.kConstant,
    this.tyreCircumference,
    this.wConstant,
    this.tyreSize,
    this.nextCalDate,
    this.speedLimit,
    this.memberState,
    this.vrn,
    this.regDate,
    this.hwNumber,
    this.hwVersionNumber,
    this.swVersionNumber,
    this.serialNumber,
    this.ecuInstallDate,
    this.pproos,
    this.teethCount,
    this.tripDistance,
    this.utcOffsetMinutes,
    this.heartbeatEnabled,
    this.tco1Priority,
    this.tco1Rate50ms,
    this.prewarningCard1Days,
    this.prewarningTachoDays,
    this.prewarningCalDays,
    this.downloadPeriodVuDays,
    this.downloadPeriodCardDays,
  });

  final String?   vin;
  final DateTime? currentDateTime;
  final int?      odometer;         // km
  final int?      kConstant;        // imp/km
  final int?      tyreCircumference; // mm
  final int?      wConstant;        // imp/km
  final String?   tyreSize;
  final DateTime? nextCalDate;
  final int?      speedLimit;       // km/h
  final String?   memberState;      // 3-char ISO code
  final String?   vrn;
  final DateTime? regDate;          // Araç Tescil Tarihi
  final String?   hwNumber;         // Cihaz modeli (0xF192)
  final String?   hwVersionNumber;  // Donanım versiyonu (0xF193)
  final String?   swVersionNumber;  // Firmware sürümü (0xF195)
  final String?   serialNumber;     // Seri numarası (0xF18C)
  final DateTime? ecuInstallDate;   // ECU Kurulum Tarihi (0xF19D)
  final int?      pproos;           // Çıkış mili hızı (0xF91E)
  final int?      teethCount;       // Diş sayısı (0xF91A)
  final int?      tripDistance;     // km (0xF913)
  final int?      utcOffsetMinutes; // UTC farkı, toplam dakika (0xF90D/0xF90E)
  final bool?     heartbeatEnabled; // Kalp atışı sıfırlama (0xF90C)
  final int?      tco1Priority;     // TCO1 önceliği (0xF90F)
  final bool?     tco1Rate50ms;     // TCO1 tekrar hızı (0xF920)
  final int?      prewarningCard1Days; // (0xF994)
  final int?      prewarningTachoDays; // (0xF995)
  final int?      prewarningCalDays;   // (0xF996)
  final int?      downloadPeriodVuDays;   // (0xF991)
  final int?      downloadPeriodCardDays; // (0xF990)
}

class OptionalSettingsSnapshot {
  const OptionalSettingsSnapshot({
    this.speedometerFactor,
    this.b7Recognize,
    this.militaryDimmer,
    this.overspeedPrewarningTime,
    this.ignitionOption,
    this.distanceUnit,
    this.tripMeterReset,
    this.imsSource,
    this.canABaudrate,
    this.canCBaudrate,
    this.gnssAntenna,
    this.periodicDags,
    this.cardExistenceWarning,
  });

  final int?    speedometerFactor;
  final bool?   b7Recognize;
  final bool?   militaryDimmer;        // yalnızca STC8250
  final int?    overspeedPrewarningTime;
  final String? ignitionOption;
  final String? distanceUnit;
  final bool?   tripMeterReset;
  final String? imsSource;
  final String? canABaudrate;
  final String? canCBaudrate;
  final String? gnssAntenna;           // yalnızca STC8255
  final bool?   periodicDags;          // yalnızca STC8255
  final bool?   cardExistenceWarning;  // yalnızca STC8255
}

class DtcEntry {
  const DtcEntry({required this.code, required this.statusMask});
  final int code;
  final int statusMask;
}

enum MsPairingStatus { waiting, paired, conditionsNotCorrect }

class ClockTestProgress {
  const ClockTestProgress({
    required this.capturedPulses,
    this.driftSecondsPerDay,
    required this.isDone,
  });
  final int capturedPulses;
  final double? driftSecondsPerDay; // null — henüz hesaplanmadı
  final bool isDone;
}

class SpeedTestProgress {
  const SpeedTestProgress({
    required this.speedStep,        // 0=40km/h, 1=70km/h, 2=100km/h
    required this.commandedKmh,
    this.measuredKmh,
    required this.isDone,
    this.isPassed,
  });
  final int speedStep;
  final double commandedKmh;
  final double? measuredKmh;
  final bool isDone;
  // null = test sürmekte, true = tolerans içinde, false = tolerans aşıldı (±2 km/h)
  final bool? isPassed;
}

// ── İstisna ────────────────────────────────────────────────────────────────

class KLineException implements Exception {
  const KLineException(this.message, {this.nrc});
  final String message;
  final int? nrc;

  @override
  String toString() => nrc != null
      ? 'KLineException: $message (NRC=0x${nrc!.toRadixString(16).toUpperCase()})'
      : 'KLineException: $message';
}

// ── KLineService ────────────────────────────────────────────────────────────

class KLineService {
  KLineService(this._transport) {
    _notifySub = _transport
        .notifyStream('SPP_DATA')
        .listen(_buffer.add);
  }

  final BleConnectionRepository _transport;
  final KLineFrameBuffer _buffer = KLineFrameBuffer();
  StreamSubscription<List<int>>? _notifySub;

  // ── Flow 1 — Security Access (PIN) ────────────────────────────────────────

  // Seed'i takograftan ister; hex string olarak döner (örn. "A3F7")
  Future<String> requestSeed() async {
    await _beginTransaction();
    await _startSession(KLineSession.standard);
    final resp = await _transact(KLineFrame.securityAccessRequestSeed());
    await _endTransaction();

    if (resp.isNegative) {
      throw KLineException('RequestSeed başarısız', nrc: resp.nrc);
    }
    // Yanıt: 67 7D <seed bytes...> — data = seed bytes
    return KLineCodec.decodeSeedHex(resp.data);
  }

  // Operatörün girdiği PIN'i takografa gönderir
  Future<SecurityAccessResult> sendKey(String pin) async {
    final pinBytes = KLineCodec.encodePinAscii(pin);
    await _beginTransaction();
    try {
      await _startSession(KLineSession.standard);
      await _requestSeedInternal(); // seed istenmeden sendKey gönderilmez
      final resp = await _transact(
        KLineFrame.securityAccessSendKey(pinBytes),
        timeout: KLineTiming.pinResponseTimeout,
        retryOnNrc78: true,
      );
      if (resp.isNegative) {
        // NRC 0x36: 3 yanlış denemeden sonra session kilitlenir; StopComm gönder.
        return SecurityAccessResult(success: false, nrc: resp.nrc);
      }
      return const SecurityAccessResult(success: true);
    } finally {
      await _endTransaction();
    }
  }

  // ── Flow 2 — CAL1: Tüm kalibrasyon verilerini oku ─────────────────────────

  Future<CalibrationSnapshot> readAllCalibrationData() async {
    await _beginTransaction();
    // Önceki flow programming/adjustment session'da bitmişse NRC 0x22 alınır;
    // her okuma flow'u standard session'da başlamalı.
    await _startSession(KLineSession.standard);

    final vinResp      = await _rdbiOrEmpty(KLineRecords.vin);
    final dtResp       = await _rdbiOrEmpty(KLineRecords.currentDateTime);
    final odoResp      = await _rdbiOrEmpty(KLineRecords.odometer);
    final kResp        = await _rdbiOrEmpty(KLineRecords.kConstant);
    final circResp     = await _rdbiOrEmpty(KLineRecords.tyreCircumference);
    final wResp        = await _rdbiOrEmpty(KLineRecords.wConstant);
    final sizeResp     = await _rdbiOrEmpty(KLineRecords.tyreSize);
    final calDateResp  = await _rdbiOrEmpty(KLineRecords.nextCalDate);
    final speedResp    = await _rdbiOrEmpty(KLineRecords.speedLimit);
    final stateResp    = await _rdbiOrEmpty(KLineRecords.memberState);
    final vrnResp      = await _rdbiOrEmpty(KLineRecords.vrn);
    final regDateResp  = await _rdbiOrEmpty(KLineRecords.vrd);
    final hwNumResp    = await _rdbiOrEmpty(KLineRecords.hwNumber);
    final hwVerResp    = await _rdbiOrEmpty(KLineRecords.hwVersionNumber);
    final swVerResp    = await _rdbiOrEmpty(KLineRecords.swVersionNumber);
    final serialResp   = await _rdbiOrEmpty(KLineRecords.serialNumber);
    final ecuInstResp  = await _rdbiOrEmpty(KLineRecords.ecuInstallDate);
    final pproosResp   = await _rdbiOrEmpty(KLineRecords.pproos);
    final teethResp    = await _rdbiOrEmpty(KLineRecords.teethCount);
    final tripResp     = await _rdbiOrEmpty(KLineRecords.tripDistance);
    final utcMinResp   = await _rdbiOrEmpty(KLineRecords.utcMinOffset);
    final utcHourResp  = await _rdbiOrEmpty(KLineRecords.utcHourOffset);
    final heartResp    = await _rdbiOrEmpty(KLineRecords.resetHeartbeat);
    final tco1PrioResp = await _rdbiOrEmpty(KLineRecords.tco1Priority);
    final tco1RateResp = await _rdbiOrEmpty(KLineRecords.tco1RepRate);
    final pwCard1Resp  = await _rdbiOrEmpty(KLineRecords.prewarningCard1);
    final pwTachoResp  = await _rdbiOrEmpty(KLineRecords.prewarningTacho);
    final pwCalResp    = await _rdbiOrEmpty(KLineRecords.prewarningCal);
    final dlVuResp     = await _rdbiOrEmpty(KLineRecords.downloadPeriodVu);
    final dlCardResp   = await _rdbiOrEmpty(KLineRecords.downloadPeriodCard);

    await _endTransaction();

    return CalibrationSnapshot(
      vin:               KLineCodec.decodeVin(vinResp),
      currentDateTime:   KLineCodec.decodeDateTime(dtResp),
      odometer:          KLineCodec.decodeOdometer(odoResp),
      kConstant:         KLineCodec.decodeKConstant(kResp),
      tyreCircumference: KLineCodec.decodeTyreCircumference(circResp),
      wConstant:         KLineCodec.decodeWConstant(wResp),
      tyreSize:          KLineCodec.decodeTyreSize(sizeResp),
      nextCalDate:       KLineCodec.decodeNextCalDate(calDateResp),
      speedLimit:        KLineCodec.decodeSpeedLimit(speedResp),
      memberState:       KLineCodec.decodeMemberState(stateResp),
      vrn:               KLineCodec.decodeVrn(vrnResp),
      regDate:           KLineCodec.decodeVehicleRegDate(regDateResp),
      hwNumber:          KLineCodec.decodeAsciiTrimmed(hwNumResp),
      hwVersionNumber:   KLineCodec.decodeAsciiTrimmed(hwVerResp),
      swVersionNumber:   KLineCodec.decodeAsciiTrimmed(swVerResp),
      serialNumber:      KLineCodec.decodeAsciiTrimmed(serialResp),
      ecuInstallDate:    KLineCodec.decodeEcuInstallDate(ecuInstResp),
      pproos:            KLineCodec.decodePproos(pproosResp),
      teethCount:        KLineCodec.decodeTeethCount(teethResp),
      tripDistance:      KLineCodec.decodeTripDistance(tripResp),
      utcOffsetMinutes:  KLineCodec.decodeUtcOffset(utcMinResp, utcHourResp),
      heartbeatEnabled:  KLineCodec.decodeHeartbeat(heartResp),
      tco1Priority:      KLineCodec.decodeTco1Priority(tco1PrioResp),
      tco1Rate50ms:      KLineCodec.decodeTco1RepRate(tco1RateResp),
      prewarningCard1Days:    KLineCodec.decodePrewarningDays(pwCard1Resp),
      prewarningTachoDays:    KLineCodec.decodePrewarningDays(pwTachoResp),
      prewarningCalDays:      KLineCodec.decodePrewarningDays(pwCalResp),
      downloadPeriodVuDays:   KLineCodec.decodeDownloadPeriod(dlVuResp),
      downloadPeriodCardDays: KLineCodec.decodeDownloadPeriod(dlCardResp),
    );
  }

  // ── Flow 2b — Opsiyonel Ayarlar (0xFD??) oku ──────────────────────────────
  // FD00–FD1F aralığı donanıma göre farklı anlama gelir (bkz. CalibrationMessages.md §8.3),
  // bu yüzden hangi kayıt ID'sinin okunacağı çağıran tarafından (hwNumber'a bakarak) seçilir.

  Future<OptionalSettingsSnapshot> readOptionalSettings({required bool isStc8255}) async {
    await _beginTransaction();
    await _startSession(KLineSession.standard);

    final speedResp   = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd11SpeedometerFactor8255 : KLineRecords.fd00SpeedometerFactor);
    final b7Resp       = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd1cB7Recognize8255 : KLineRecords.fd01B7Recognize);
    final overspeedResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd1aOverspeedPrewarningTime8255 : KLineRecords.fd06OverspeedPrewarningTime);
    final ignitionResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd18IgnitionOptions8255 : KLineRecords.fd07IgnitionOptions);
    final distanceResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd1eDistanceUnit8255 : KLineRecords.fd0bDistanceUnit);
    final imsResp      = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd17ImsSource8255 : KLineRecords.fd0fImsSource);
    final canAResp     = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd32CanABaudrate8255 : KLineRecords.fd08CanABaudrate);
    final canCResp     = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd35CanCBaudrate8255 : KLineRecords.fd09CanCBaudrate);
    final tripMeterResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd3bTripmeterReset8255 : KLineRecords.fd11TripmeterReset);
    final militaryResp = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd04MilitaryDimmer);
    final gnssResp     = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd53GnssAntenna8255) : const <int>[];
    final dagsResp     = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd41PeriodicDags8255) : const <int>[];
    final cardWarnResp = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd51CardExistenceWarning8255) : const <int>[];

    await _endTransaction();

    return OptionalSettingsSnapshot(
      speedometerFactor:       KLineCodec.decodeSpeedometerFactor(speedResp),
      b7Recognize:             KLineCodec.decodeEnabledByte(b7Resp),
      militaryDimmer:          isStc8255 ? null : KLineCodec.decodeMilitaryDimmer(militaryResp),
      overspeedPrewarningTime: KLineCodec.decodeOverspeedPrewarningSeconds(overspeedResp),
      ignitionOption:          KLineCodec.decodeIgnitionOption(ignitionResp),
      distanceUnit:            KLineCodec.decodeDistanceUnit(distanceResp),
      tripMeterReset:          KLineCodec.decodeEnabledByte(tripMeterResp),
      imsSource:               KLineCodec.decodeImsSource(imsResp),
      canABaudrate:            KLineCodec.decodeCanBaudrate(canAResp),
      canCBaudrate:            KLineCodec.decodeCanBaudrate(canCResp),
      gnssAntenna:             isStc8255 ? KLineCodec.decodeGnssAntenna(gnssResp) : null,
      periodicDags:            isStc8255 ? KLineCodec.decodeEnabledByte(dagsResp) : null,
      cardExistenceWarning:    isStc8255 ? KLineCodec.decodeCardExistenceWarning(cardWarnResp) : null,
    );
  }

  // ── Flow 3 — CAL1: Tek parametre yaz ──────────────────────────────────────

  Future<void> writeParameter(int recordId, List<int> data) async {
    await _beginTransaction();
    await _startSession(KLineSession.programming);

    // Stoneridge: W-Constant yazılırken K-Constant'a da aynı değer yazılmalı;
    // aksi hâlde takograf W/K uyumsuzluğu nedeniyle değeri RAM'de bırakır.
    if (recordId == KLineRecords.wConstant) {
      await _wdbi(KLineRecords.kConstant, data);
    }
    await _wdbi(recordId, data);

    // Commit: İkinci StartCommunication flash'a yazmayı tetikler
    await _startComm();

    // Doğrulama: yazılan değeri geri oku ve karşılaştır
    final readback = await _rdbi(recordId);
    if (!_bytesEqual(readback, data)) {
      throw KLineException(
        'Yazma doğrulama başarısız: '
        'beklenen [${_hexStr(data)}], okunan [${_hexStr(readback)}]',
      );
    }
    if (recordId == KLineRecords.wConstant) {
      final kReadback = await _rdbi(KLineRecords.kConstant);
      if (!_bytesEqual(kReadback, data)) {
        throw KLineException(
          'K-Constant doğrulama başarısız: '
          'beklenen [${_hexStr(data)}], okunan [${_hexStr(kReadback)}]',
        );
      }
    }

    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── Flow 4 — CAL2: Tarih/Saat yaz ────────────────────────────────────────

  Future<void> writeDateTime(
    DateTime dt,
    int utcHourOffset,
    int utcMinOffset,
  ) async {
    await _beginTransaction();
    await _startSession(KLineSession.programming);

    // Mevcut zamanı oku (delta > 20 dk ise W-Constant da yeniden yazılmalı)
    final currentDtBytes = await _rdbi(KLineRecords.currentDateTime);
    final currentDt = KLineCodec.decodeDateTime(currentDtBytes);
    if (currentDt != null) {
      final delta = dt.difference(currentDt).abs();
      if (delta.inMinutes > KLineTiming.dateTimeWConstantThresholdMinutes) {
        // W-Constant'ı oku ve geri yaz (protokol gereği)
        final wBytes = await _rdbi(KLineRecords.wConstant);
        await _wdbi(KLineRecords.wConstant, wBytes);
      }
    }

    final encoded = KLineCodec.encodeDateTime(dt, utcHourOffset, utcMinOffset);
    await _wdbi(KLineRecords.currentDateTime, encoded);

    // Commit
    await _startComm();

    // Doğrulama
    await _rdbi(KLineRecords.currentDateTime);

    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── Flow 5 — CAL2: UTC Offset yaz ────────────────────────────────────────

  Future<void> writeUtcOffset(int totalOffsetMinutes) async {
    final encoded = KLineCodec.encodeUtcOffset(totalOffsetMinutes);
    final minByte  = [encoded[0]];
    final hourByte = [encoded[1]];

    await _beginTransaction();
    await _startSession(KLineSession.programming);

    await _wdbi(KLineRecords.utcMinOffset, minByte);
    await _wdbi(KLineRecords.utcHourOffset, hourByte);

    await Future<void>.delayed(const Duration(milliseconds: 1000));

    await _rdbi(KLineRecords.utcMinOffset);
    await _rdbi(KLineRecords.utcHourOffset);

    // Commit
    await _startComm();

    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── Flow 6 — CAL3: Prewarning süreleri yaz ───────────────────────────────

  Future<void> writePrewarningTimes(
    int card1Days,
    int tachoDays,
    int calDays,
  ) async {
    await _beginTransaction();
    await _startSession(KLineSession.programming);

    await _wdbi(KLineRecords.prewarningCard1, KLineCodec.encodePrewarningDays(card1Days));
    await _wdbi(KLineRecords.prewarningTacho,  KLineCodec.encodePrewarningDays(tachoDays));
    await _wdbi(KLineRecords.prewarningCal,    KLineCodec.encodePrewarningDays(calDays));

    // Commit
    await _startComm();

    await _rdbi(KLineRecords.prewarningCard1);
    await _rdbi(KLineRecords.prewarningTacho);
    await _rdbi(KLineRecords.prewarningCal);

    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── Flow 7 — CAL3: İndirme periyotları yaz ───────────────────────────────

  Future<void> writeDownloadPeriods(int vuDays, int cardDays) async {
    await _beginTransaction();
    await _startSession(KLineSession.programming);

    await _wdbi(KLineRecords.downloadPeriodVu,   KLineCodec.encodeDownloadPeriod(vuDays));
    await _wdbi(KLineRecords.downloadPeriodCard, KLineCodec.encodeDownloadPeriod(cardDays));

    // Commit
    await _startComm();

    await _rdbi(KLineRecords.downloadPeriodCard);
    await _rdbi(KLineRecords.downloadPeriodVu);

    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── Flow 8 — Hareket sensörü eşleştirme ──────────────────────────────────

  // Stream: MsPairingStatus değerleri yayar; paired veya conditionsNotCorrect
  // ile kapanır.
  Stream<MsPairingStatus> pairMotionSensor(int routineId) async* {
    await _beginTransaction();
    await _startSession(KLineSession.adjustment);

    // startRoutine
    await _transact(
      KLineFrame.routineControl(KLineRoutineSelect.startRoutine, routineId),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(KLineTiming.msPairingPollInterval);

      final resp = await _transact(
        KLineFrame.routineControl(KLineRoutineSelect.requestRoutineResults, routineId),
      );

      if (resp.isNegative && resp.nrc == KLineNrc.conditionsNotCorrect) {
        await _startSession(KLineSession.standard);
        await _endTransaction();
        yield MsPairingStatus.conditionsNotCorrect;
        return;
      }

      if (resp.data.isNotEmpty && resp.data.last == 0x01) {
        await _startSession(KLineSession.standard);
        await _endTransaction();
        yield MsPairingStatus.paired;
        return;
      }

      yield MsPairingStatus.waiting;
    }

    await _startSession(KLineSession.standard);
    await _endTransaction();
    yield MsPairingStatus.conditionsNotCorrect;
  }

  // ── Flow 9 — Tek parametre oku ────────────────────────────────────────────

  Future<List<int>> readParameter(int recordId) async {
    await _beginTransaction();
    final data = await _rdbi(recordId);
    await _endTransaction();
    return data;
  }

  // ── Flow 10 — Saat Testi ──────────────────────────────────────────────────

  Stream<ClockTestProgress> runClockTest() async* {
    await _beginTransaction();
    await _rdbi(KLineRecords.hwNumber); // version check
    await _startSession(KLineSession.adjustment);

    // RTC çıkışını etkinleştir
    await _transact(
      KLineFrame.ioControlByIdentifier(
        KLineIocpControl.shortTermAdjustment,
        KLineIocpControl.enableRtcOutput,
      ),
    );

    // 12 darbe yakala — her 150ms'de TesterPresent
    int pulses = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (pulses < 12 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(KLineTiming.testerPresentInterval);
      await _sendNoReply(KLineFrame.testerPresentNoResponse());
      pulses++;
      yield ClockTestProgress(capturedPulses: pulses, isDone: false);
    }

    // IO reset
    await _sendNoReply(KLineFrame.ioControlReset());
    await _startSession(KLineSession.standard);
    await _endTransaction();

    yield ClockTestProgress(capturedPulses: pulses, isDone: true);
  }

  // ── Flow 11 — Hız & Kilometre Testi ──────────────────────────────────────

  Stream<SpeedTestProgress> runSpeedOdometerTest() async* {
    await _beginTransaction();
    await _rdbi(KLineRecords.hwNumber);
    await _startSession(KLineSession.adjustment);

    await _transact(
      KLineFrame.ioControlByIdentifier(
        KLineIocpControl.shortTermAdjustment,
        KLineIocpControl.enableSpeedInput,
      ),
    );

    const steps = [40.0, 70.0, 100.0];
    bool allStepsPassed = true;

    for (int i = 0; i < steps.length; i++) {
      final kmh = steps[i];
      final stepDeadline = DateTime.now().add(const Duration(seconds: 300));
      double? lastMeasured;

      while (DateTime.now().isBefore(stepDeadline)) {
        await Future<void>.delayed(KLineTiming.testerPresentInterval);
        try {
          final speedBytes = await _rdbi(KLineRecords.vehicleSpeed);
          if (speedBytes.length >= 2) {
            lastMeasured = ((speedBytes[0] << 8) | speedBytes[1]) / 256.0;
          } else {
            AppLogger.instance.log(
              'Speed read short response: ${speedBytes.length} bytes',
              level: LogLevel.error,
              category: LogCategory.diagnostics,
            );
          }
        } catch (_) { /* okuma hatasını yoksay */ }

        yield SpeedTestProgress(
          speedStep: i,
          commandedKmh: kmh,
          measuredKmh: lastMeasured,
          isDone: false,
          isPassed: lastMeasured == null
              ? null
              : (lastMeasured - kmh).abs() <= 2.0,
        );
      }

      // Adım tamamlandı — son ölçüm tolerans dışıysa testi başarısız say
      if (lastMeasured == null || (lastMeasured - kmh).abs() > 2.0) {
        allStepsPassed = false;
      }

      if (i < steps.length - 1) {
        // Adımlar arası 4 s bekleme — her 500 ms'de TesterPresent göndererek
        // ECU session'ının (P3 ≈ 5 s) zaman aşımına uğramasını engelle
        for (int t = 0; t < 8; t++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await _sendNoReply(KLineFrame.testerPresentNoResponse());
        }
      }
    }

    await _sendNoReply(KLineFrame.ioControlReset());
    await _startSession(KLineSession.standard);
    await _endTransaction();

    yield SpeedTestProgress(
      speedStep: 2,
      commandedKmh: 100,
      isDone: true,
      isPassed: allStepsPassed,
    );
  }

  // ── Flow 12-21 — Rutin testler ────────────────────────────────────────────

  Future<void> startRoutineTest(int routineId, {int? slotNumber}) async {
    await _beginTransaction();
    await _startSession(KLineSession.adjustment);

    final frame = slotNumber != null
        ? KLineFrame.routineControlWithExtra(
            KLineRoutineSelect.startRoutine, routineId, slotNumber)
        : KLineFrame.routineControl(KLineRoutineSelect.startRoutine, routineId);

    await _transact(frame);
  }

  // operatorResult: true=SUCCESSFUL(0x01), false=FAILED(0x00), null=plain stop
  Future<void> stopRoutineTest(int routineId, {bool? operatorResult}) async {
    final frame = operatorResult != null
        ? KLineFrame.routineControlWithExtra(
            KLineRoutineSelect.stopRoutine,
            routineId,
            operatorResult ? 0x01 : 0x00,
          )
        : KLineFrame.routineControl(KLineRoutineSelect.stopRoutine, routineId);

    await _transact(frame);
    await _startSession(KLineSession.standard);
    await _endTransaction();
  }

  // ── DTC Servisleri ────────────────────────────────────────────────────────

  Future<int> readDtcCount() async {
    await _beginTransaction();
    final resp = await _transact(KLineFrame.readDtcNumberByStatusMask());
    await _endTransaction();
    if (resp.data.length >= 2) {
      return (resp.data[0] << 8) | resp.data[1];
    }
    return 0;
  }

  Future<List<DtcEntry>> readDtcCodes() async {
    await _beginTransaction();
    final resp = await _transact(KLineFrame.readDtcByStatusMask());
    await _endTransaction();

    final entries = <DtcEntry>[];
    final d = resp.data;
    // Her DTC: 3 byte DTC kodu + 1 byte status maskesi
    for (int i = 0; i + 3 < d.length; i += 4) {
      final code = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
      final mask = d[i + 3];
      entries.add(DtcEntry(code: code, statusMask: mask));
    }
    return entries;
  }

  Future<void> clearDtcCodes() async {
    await _beginTransaction();
    await _transact(KLineFrame.clearDiagnosticInformation());
    await _endTransaction();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _notifySub?.cancel();
  }

  // ── İç yardımcılar ────────────────────────────────────────────────────────

  // Wakeup + StartCommunication
  Future<void> _beginTransaction() async {
    _buffer.clear();
    await _transport.writeCharacteristic('SPP_DATA', KLineFrame.wakeup());
    await Future<void>.delayed(KLineTiming.wakeupDelay);
    await _startComm();
  }

  // StopCommunication
  Future<void> _endTransaction() async {
    await _transact(KLineFrame.stopCommunication(), retryOnNrc78: true);
    await Future<void>.delayed(KLineTiming.interMessageDelay);
  }

  // StartCommunication (fast-init) — commit tetikleyicisi olarak da kullanılır
  Future<void> _startComm() async {
    await _transact(KLineFrame.startCommunication(), retryOnNrc78: true);
    await Future<void>.delayed(KLineTiming.interMessageDelay);
  }

  // StartDiagnosticSession
  Future<void> _startSession(int sessionType) async {
    await _transact(KLineFrame.startDiagnosticSession(sessionType), retryOnNrc78: true);
    await Future<void>.delayed(KLineTiming.interMessageDelay);
  }

  // ReadDataByIdentifier — data payload'ını döner
  Future<List<int>> _rdbi(int recordId) async {
    final resp = await _transact(KLineFrame.readDataByIdentifier(recordId), retryOnNrc78: true);
    await Future<void>.delayed(KLineTiming.interMessageDelay);
    if (resp.isNegative) {
      throw KLineException('RDBI 0x${recordId.toRadixString(16).toUpperCase()} başarısız', nrc: resp.nrc);
    }
    return resp.data;
  }

  // ReadDataByIdentifier — desteklenmeyen/henüz yazılmamış kayıtlar için (NRC durumunda)
  // boş liste döner; toplu okuma akışlarının (Flow 2, Flow 2b) tek bir eksik alan
  // yüzünden tamamen başarısız olmasını engeller. Decode fonksiyonları boş/kısa
  // veriyi zaten null olarak yorumlar.
  Future<List<int>> _rdbiOrEmpty(int recordId) async {
    try {
      return await _rdbi(recordId);
    } on KLineException {
      return const <int>[];
    }
  }

  // WriteDataByIdentifier
  Future<void> _wdbi(int recordId, List<int> data) async {
    final resp = await _transact(KLineFrame.writeDataByIdentifier(recordId, data), retryOnNrc78: true);
    await Future<void>.delayed(KLineTiming.interMessageDelay);
    if (resp.isNegative) {
      throw KLineException('WDBI 0x${recordId.toRadixString(16).toUpperCase()} başarısız', nrc: resp.nrc);
    }
  }

  // SecurityAccess RequestSeed (flow içi kullanım)
  Future<void> _requestSeedInternal() async {
    await _transact(KLineFrame.securityAccessRequestSeed());
    await Future<void>.delayed(KLineTiming.interMessageDelay);
  }

  // Frame gönder, yanıtı bekle
  Future<KLineResponse> _transact(
    List<int> frame, {
    Duration? timeout,
    bool retryOnNrc78 = false,
  }) async {
    await _transport.writeCharacteristic('SPP_DATA', frame);
    return _waitResponse(
      timeout: timeout ?? KLineTiming.defaultTimeout,
      retryOnNrc78: retryOnNrc78,
    );
  }

  // Yanıt beklenmeden gönderim (TesterPresent no-response)
  Future<void> _sendNoReply(List<int> frame) async {
    await _transport.writeCharacteristic('SPP_DATA', frame);
  }

  // Buffer'dan tam frame gelene kadar bekler
  Future<KLineResponse> _waitResponse({
    required Duration timeout,
    bool retryOnNrc78 = false,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final resp = _buffer.tryParse();
      if (resp != null) {
        // NRC 0x78: tachograph hâlâ işliyor — yeniden dene
        if (retryOnNrc78 &&
            resp.isNegative &&
            resp.nrc == KLineNrc.requestCorrectlyReceivedResponsePending) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        return resp;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    throw const KLineException('Yanıt zaman aşımına uğradı');
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _hexStr(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
