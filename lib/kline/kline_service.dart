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
    this.systemSupplierIdentifier,
    this.swNumber,
    this.exhaustRegOrTypeApprovalNumber,
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
  final String?   systemSupplierIdentifier;       // (0xF18A)
  final String?   swNumber;                       // (0xF194)
  final String?   exhaustRegOrTypeApprovalNumber; // (0xF196)
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
    // Ortak — Sprint 5
    this.languageChange,
    this.overspeedOutput,
    this.buzzerOverspeedControl,
    this.overspeedTco1,
    this.tco1HandlingInfo,
    this.canASyncJump,
    this.canCSyncJump,
    this.canAOnOff,
    this.canCOnOff,
    this.cardExpiryControl,
    this.cardExpiryDriver,
    this.cardExpiryWorkshop,
    this.cardExpiryCompany,
    this.cardExpiryCalibration,
    // STC8250'ye özel — Sprint 5
    this.canCTco1,
    this.backlightLevel,
    this.backlightBattery,
    this.outputShaftSpeedEnable,
    this.canASample,
    this.canCSample,
    this.imsCanPgn,
    // STC8255'e özel — Sprint 5
    this.nProfileRegistry,
    this.nSpeedProfiles,
    this.vProfileRegistry,
    this.vSpeedProfiles,
    this.nFactor,
    this.d1Enable,
    this.d2Enable,
    this.engineSpeedSource,
    this.canProtocolP1,
    this.canProtocolP2,
    this.canATermination,
    this.canCTermination,
    this.rddwInSleep,
    this.dagsBuzzerControl,
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

  // Ortak — Sprint 5
  final String? languageChange;
  final String? overspeedOutput;
  final bool?   buzzerOverspeedControl;
  final bool?   overspeedTco1;
  final String? tco1HandlingInfo;
  final int?    canASyncJump;
  final int?    canCSyncJump;
  final bool?   canAOnOff;
  final bool?   canCOnOff;
  final int?    cardExpiryControl;
  final int?    cardExpiryDriver;
  final int?    cardExpiryWorkshop;
  final int?    cardExpiryCompany;
  final int?    cardExpiryCalibration;

  // STC8250'ye özel — Sprint 5
  final int?    canCTco1;
  final int?    backlightLevel;
  final String? backlightBattery;
  final bool?   outputShaftSpeedEnable;
  final int?    canASample;
  final int?    canCSample;
  final String? imsCanPgn;

  // STC8255'e özel — Sprint 5
  final bool?      nProfileRegistry;
  final List<int>? nSpeedProfiles;
  final bool?      vProfileRegistry;
  final List<int>? vSpeedProfiles;
  final int?       nFactor;
  final bool?      d1Enable;
  final bool?      d2Enable;
  final String?    engineSpeedSource;
  final int?       canProtocolP1;
  final int?       canProtocolP2;
  final bool?      canATermination;
  final bool?      canCTermination;
  final int?       rddwInSleep;
  final bool?      dagsBuzzerControl;
}

class DtcEntry {
  const DtcEntry({required this.code, required this.statusMask});
  final int code;
  final int statusMask;
}

enum MsPairingStatus { waiting, paired, conditionsNotCorrect, routineNotSupported }

// pollRoutineCompletion() sonucu — Flow 12-21 rutinlerinden cihazın kendi
// kendine sonuçlandırdığı türler için (Hardware/Battery/Data Memory/SW Integrity).
enum RoutineCompletionStatus { completed, conditionsNotCorrect, timedOut }

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

// Bağlantı canlıyken hiçbir yanıt gelmeden zaman aşımına uğrandığında fırlatılır
// (bkz. _waitResponse). Bazı bileşen self-test rutinleri için (Flow 12-21,
// CalibrationMessages.md) start/stopRoutine yanıtı doküman düzeyinde hiç
// gösterilmemiştir; çağıran taraf bu durumu genel bir KLineException'dan
// (negatif NRC veya bağlantı kopması gibi gerçek hatalardan) ayırt edip
// "beklenen davranış" olarak ele alabilir.
class KLineTimeoutException extends KLineException {
  const KLineTimeoutException(super.message);
}

// ── KLineService ────────────────────────────────────────────────────────────

class KLineService {
  KLineService(this._transport) {
    _notifySub = _transport
        .notifyStream('SPP_DATA')
        .listen(_buffer.add);
    _connStateSub = _transport.connectionState.listen((state) {
      if (state == BleConnectionState.disconnected) _connectionLost = true;
    });
  }

  final BleConnectionRepository _transport;
  final KLineFrameBuffer _buffer = KLineFrameBuffer();
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BleConnectionState>? _connStateSub;
  bool _connectionLost = false;

  // ── Flow 1 — Security Access (PIN) ────────────────────────────────────────
  //
  // ⚠️ DONANIM DOĞRULAMASI GEREKLİ: requestSeed() ile sendKey() arasında
  // K-Line oturumu artık AÇIK tutuluyor (StopCommunication gönderilmiyor) ve
  // operatör PIN'i hesaplarken bir TesterPresent keep-alive ile canlı
  // tutuluyor — bu, CalibrationMessages.md Flow 1'in tek-transaction
  // (Wakeup→StartComm→StartSession→RequestSeed→SendKey→StopComm) sırasına
  // uyum sağlamak için yapıldı (önceki davranış: sendKey() kendi başına YENİ
  // bir transaction'da seed'i tekrar istiyordu, bu da tachograf her
  // RequestSeed'de farklı seed üretiyorsa operatöre gösterilen seed ile
  // SendKey anında geçerli olan seed'in uyuşmamasına yol açabilirdi).
  // Tachografın uzatılmış bekleme penceresinde seed'i hâlâ geçerli kabul
  // edip etmediği gerçek donanımda TEST EDİLMEDEN bu akış production'da
  // güvenilir sayılmamalı.
  bool _securityAccessPending = false;
  Timer? _securityAccessKeepAlive;

  // Seed'i takograftan ister; hex string olarak döner (örn. "A3F7").
  // Transaction'ı KAPATMAZ — sendKey() veya cancelSecurityAccess() ile
  // kapatılana kadar açık (keep-alive ile canlı tutulan) kalır.
  Future<String> requestSeed() async {
    await _beginTransaction();
    try {
      await _startSession(KLineSession.standard);
      final resp = await _transact(KLineFrame.securityAccessRequestSeed());
      if (resp.isNegative) {
        throw KLineException('RequestSeed başarısız', nrc: resp.nrc);
      }
      _securityAccessPending = true;
      _startSecurityAccessKeepAlive();
      // Yanıt: 67 7D <seed bytes...> — data = seed bytes
      return KLineCodec.decodeSeedHex(resp.data);
    } catch (_) {
      await _endTransaction();
      rethrow;
    }
  }

  // Operatörün girdiği PIN'i, requestSeed() ile açılan AYNI oturum üzerinden
  // gönderir (yeni bir RequestSeed açmadan). Yanlış PIN (ama kilitlenme
  // olmadan) oturumu AÇIK bırakır — PinEntryScreen'in 3 deneme hakkı aynı
  // seed üzerinden tekrar denenebilsin diye. Başarı, ECU kilidi (NRC 0x36)
  // veya beklenmeyen bir hata durumunda oturum kapatılır.
  Future<SecurityAccessResult> sendKey(String pin) async {
    if (!_securityAccessPending) {
      throw const KLineException(
        'sendKey() çağrılmadan önce requestSeed() ile bir oturum açılmalı',
      );
    }
    _stopSecurityAccessKeepAlive();
    final pinBytes = KLineCodec.encodePinAscii(pin);
    try {
      final resp = await _transact(
        KLineFrame.securityAccessSendKey(pinBytes),
        timeout: KLineTiming.pinResponseTimeout,
        retryOnNrc78: true,
      );
      if (resp.isNegative) {
        if (resp.nrc == KLineNrc.exceededNumberOfAttempts) {
          _securityAccessPending = false;
          await _endTransaction();
        } else {
          // Yanlış PIN ama kilitlenmedi — aynı oturumda tekrar denemeye izin ver.
          _startSecurityAccessKeepAlive();
        }
        return SecurityAccessResult(success: false, nrc: resp.nrc);
      }
      _securityAccessPending = false;
      await _endTransaction();
      return const SecurityAccessResult(success: true);
    } catch (_) {
      _securityAccessPending = false;
      await _endTransaction();
      rethrow;
    }
  }

  // Operatör PIN girmeden vazgeçerse (PIN ekranından geri dönerse) açık
  // kalan Security Access oturumunu temiz şekilde kapatır.
  Future<void> cancelSecurityAccess() async {
    if (!_securityAccessPending) return;
    _stopSecurityAccessKeepAlive();
    _securityAccessPending = false;
    await _endTransaction();
  }

  void _startSecurityAccessKeepAlive() {
    _securityAccessKeepAlive?.cancel();
    _securityAccessKeepAlive = Timer.periodic(
      KLineTiming.securityAccessKeepAliveInterval,
      (_) => _sendNoReply(KLineFrame.testerPresentNoResponse()),
    );
  }

  void _stopSecurityAccessKeepAlive() {
    _securityAccessKeepAlive?.cancel();
    _securityAccessKeepAlive = null;
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
    final supplierResp = await _rdbiOrEmpty(KLineRecords.systemSupplierIdentifier);
    final swNumResp    = await _rdbiOrEmpty(KLineRecords.swNumber);
    final exhaustResp  = await _rdbiOrEmpty(KLineRecords.exhaustRegOrTypeApprovalNumber);

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
      systemSupplierIdentifier:       KLineCodec.decodeAsciiTrimmed(supplierResp),
      swNumber:                       KLineCodec.decodeAsciiTrimmed(swNumResp),
      exhaustRegOrTypeApprovalNumber: KLineCodec.decodeAsciiTrimmed(exhaustResp),
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

    // Ortak — Sprint 5
    final langResp        = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd19LanguageChange8255 : KLineRecords.fd0cLanguageChange);
    final overspeedOutResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd1bOverspeedOutput8255 : KLineRecords.fd0dOverspeedOutput);
    final buzzerOverResp  = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd1fBuzzerOverspeed8255 : KLineRecords.fd0eBuzzerOverspeed);
    final overspeedTco1Resp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd3aOverspeedTco18255 : KLineRecords.fd10OverspeedTco1);
    final tco1HandlingResp = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd3cTco1HandlingInfo8255 : KLineRecords.fd13Tco1HandlingInfo);
    final canASyncResp    = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd33CanASyncJump8255 : KLineRecords.fd15CanASyncJump);
    final canCSyncResp    = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd36CanCSyncJump8255 : KLineRecords.fd17CanCSyncJump);
    final canAOnOffResp   = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd31CanAOnOff8255 : KLineRecords.fd19CanAOnOff);
    final canCOnOffResp   = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd34CanCOnOff8255 : KLineRecords.fd03CanCOnOff);
    final cardExpiryResp  = await _rdbiOrEmpty(isStc8255 ? KLineRecords.fd22CardExpiryDates8255 : KLineRecords.fd02CardExpiryDates);

    // STC8250'ye özel — Sprint 5
    final canCTco1Resp    = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd05CanCTco1);
    final backlightResp   = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd0aBacklightBattery);
    final outShaftResp    = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd12OutputShaftSpeedEnable);
    final canASampleResp  = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd14CanASample);
    final canCSampleResp  = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd16CanCSample);
    final imsPgnResp      = isStc8255 ? const <int>[] : await _rdbiOrEmpty(KLineRecords.fd18ImsCanPgn);

    // STC8255'e özel — Sprint 5
    final nProfileRegResp = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd12NProfileRegistry8255) : const <int>[];
    final nSpeedResp      = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd13NSpeedProfiles8255) : const <int>[];
    final vProfileRegResp = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd14VProfileRegistry8255) : const <int>[];
    final vSpeedResp      = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd15VSpeedProfiles8255) : const <int>[];
    final nFactorResp     = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd16NFactor8255) : const <int>[];
    final d1d2Resp        = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd1dD1D2StateEnable8255) : const <int>[];
    final engineSpeedResp = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd23EngineSpeedSource8255) : const <int>[];
    final canProtoResp    = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd30CanProtocols8255) : const <int>[];
    final canTermResp     = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd3dCanTerminations8255) : const <int>[];
    final rddwSleepResp   = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd3eRddwInSleep8255) : const <int>[];
    final dagsBuzzerResp  = isStc8255 ? await _rdbiOrEmpty(KLineRecords.fd50DagsBuzzerControl8255) : const <int>[];

    await _endTransaction();

    final cardExpiry = KLineCodec.decodeCardExpiryDates(cardExpiryResp);
    final backlight = isStc8255 ? null : KLineCodec.decodeBacklightBattery(backlightResp);
    final d1d2 = isStc8255 ? KLineCodec.decodeD1D2Enable(d1d2Resp) : null;
    final canProto = isStc8255 ? KLineCodec.decodeCanProtocols(canProtoResp) : null;
    final canTerm = isStc8255 ? KLineCodec.decodeCanTerminations(canTermResp) : null;

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

      // Ortak — Sprint 5
      languageChange:          KLineCodec.decodeLanguageChange(langResp),
      overspeedOutput:         KLineCodec.decodeOverspeedOutput(overspeedOutResp),
      buzzerOverspeedControl:  KLineCodec.decodeEnabledByte(buzzerOverResp),
      overspeedTco1:           KLineCodec.decodeEnabledByte(overspeedTco1Resp),
      tco1HandlingInfo:        KLineCodec.decodeTco1HandlingInfo(tco1HandlingResp),
      canASyncJump:            KLineCodec.decodeRawByte(canASyncResp),
      canCSyncJump:            KLineCodec.decodeRawByte(canCSyncResp),
      canAOnOff:               isStc8255 ? KLineCodec.decodeEnabledByte(canAOnOffResp) : KLineCodec.decodeEnabledUint16(canAOnOffResp),
      canCOnOff:               isStc8255 ? KLineCodec.decodeEnabledByte(canCOnOffResp) : KLineCodec.decodeEnabledUint16(canCOnOffResp),
      cardExpiryControl:       cardExpiry?.$1,
      cardExpiryDriver:        cardExpiry?.$2,
      cardExpiryWorkshop:      cardExpiry?.$3,
      cardExpiryCompany:       cardExpiry?.$4,
      cardExpiryCalibration:   cardExpiry?.$5,

      // STC8250'ye özel — Sprint 5
      canCTco1:                isStc8255 ? null : KLineCodec.decodeCanCTco1(canCTco1Resp),
      backlightLevel:          backlight?.$1,
      backlightBattery:        backlight?.$2,
      outputShaftSpeedEnable:  isStc8255 ? null : KLineCodec.decodeEnabledByte(outShaftResp),
      canASample:              isStc8255 ? null : KLineCodec.decodeCanSamplePoint(canASampleResp),
      canCSample:              isStc8255 ? null : KLineCodec.decodeCanSamplePoint(canCSampleResp),
      imsCanPgn:               isStc8255 ? null : KLineCodec.decodeImsCanPgn(imsPgnResp),

      // STC8255'e özel — Sprint 5
      nProfileRegistry:        isStc8255 ? KLineCodec.decodeEnabledByte(nProfileRegResp) : null,
      nSpeedProfiles:          isStc8255 ? KLineCodec.decodeNSpeedProfiles(nSpeedResp) : null,
      vProfileRegistry:        isStc8255 ? KLineCodec.decodeEnabledByte(vProfileRegResp) : null,
      vSpeedProfiles:          isStc8255 ? KLineCodec.decodeVSpeedProfiles(vSpeedResp) : null,
      nFactor:                 isStc8255 ? KLineCodec.decodeNFactor(nFactorResp) : null,
      d1Enable:                d1d2?.$1,
      d2Enable:                d1d2?.$2,
      engineSpeedSource:       isStc8255 ? KLineCodec.decodeEngineSpeedSource(engineSpeedResp) : null,
      canProtocolP1:           canProto?.$1,
      canProtocolP2:           canProto?.$2,
      canATermination:         canTerm?.$1,
      canCTermination:         canTerm?.$2,
      rddwInSleep:             isStc8255 ? KLineCodec.decodeRawByte(rddwSleepResp) : null,
      dagsBuzzerControl:       isStc8255 ? KLineCodec.decodeEnabledByte(dagsBuzzerResp) : null,
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

    // startRoutine — 0x0155'in gerçek donanımda doğrulanmamış bir varsayım
    // olması nedeniyle (bkz. PossibleProblems.md), yanıt kontrol edilmeden
    // 60s'lik polling döngüsüne girilirse "routine not supported" durumu
    // yanıltıcı bir "conditionsNotCorrect" mesajı olarak görünebilir.
    final startResp = await _transact(
      KLineFrame.routineControl(KLineRoutineSelect.startRoutine, routineId),
    );
    if (startResp.isNegative) {
      await _startSession(KLineSession.standard);
      await _endTransaction();
      yield MsPairingStatus.routineNotSupported;
      return;
    }

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

    final resp = await _transact(frame);
    if (resp.isNegative) {
      throw KLineException(
        'RoutineControl (start) 0x${routineId.toRadixString(16).toUpperCase()} başarısız',
        nrc: resp.nrc,
      );
    }
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

    final resp = await _transact(frame);
    await _startSession(KLineSession.standard);
    await _endTransaction();
    if (resp.isNegative) {
      throw KLineException(
        'RoutineControl (stop) 0x${routineId.toRadixString(16).toUpperCase()} başarısız',
        nrc: resp.nrc,
      );
    }
  }

  // startRoutineTest() ile açılan rutin için tamamlanma bekler — bazı rutinler
  // (Hardware/Battery/Data Memory/SW Integrity) tamamlandığında kendi kendine
  // sonuç bildirir (CONDITIONS_NOT_CORRECT NRC'si veya bir sonuç baytıyla).
  // pairMotionSensor()'daki poll deseninin (yukarıda) genelleştirilmiş hali.
  // Transaction'ı KAPATMAZ — çağıran ardından stopRoutineTest() ile kapatmalı.
  Future<RoutineCompletionStatus> pollRoutineCompletion(
    int routineId, {
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final resp = await _transact(
        KLineFrame.routineControl(KLineRoutineSelect.requestRoutineResults, routineId),
      );
      if (resp.isNegative && resp.nrc == KLineNrc.conditionsNotCorrect) {
        return RoutineCompletionStatus.conditionsNotCorrect;
      }
      if (!resp.isNegative && resp.data.isNotEmpty) {
        return RoutineCompletionStatus.completed;
      }
    }
    return RoutineCompletionStatus.timedOut;
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
    if (_securityAccessPending) {
      try {
        await cancelSecurityAccess();
      } catch (_) {
        // Dispose sırasında bağlantı zaten kopmuş olabilir — yutup devam et.
      }
    }
    await _notifySub?.cancel();
    await _connStateSub?.cancel();
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

  // Frame gönder, yanıtı bekle
  Future<KLineResponse> _transact(
    List<int> frame, {
    Duration? timeout,
    bool retryOnNrc78 = false,
  }) async {
    // Önceki isteğin çözülemeyen/artık baytlarının bu yeni isteğin yanıtını
    // kirletmesini önle — her request-response çifti temiz bir tamponla başlar.
    _buffer.clear();
    await _write(frame);
    return _waitResponse(
      timeout: timeout ?? KLineTiming.defaultTimeout,
      retryOnNrc78: retryOnNrc78,
    );
  }

  // Yanıt beklenmeden gönderim (TesterPresent no-response)
  Future<void> _sendNoReply(List<int> frame) async {
    await _write(frame);
  }

  // Frame'i K-LINE'ın gerçek zamanlama gereksinimine (ISO 14230 P4min ≥ 5 ms
  // bayt-arası boşluk) uygun şekilde bayt bayt yazar — STKC referans firmware'i
  // (Kline_Port.c::Send_KLINE_Package_Receive_Response) her baytı ayrı UART_write
  // ile gönderip aralarında Task_sleep(5) uyguluyor; bu birebir aynısını yapar.
  // Frame'in tamamını tek seferde yazmak bu boşluğu garanti etmiyordu ve gerçek
  // donanımda takografın kendi debug çıktısında bağlantı anında görülen
  // "FMT not correct / TGT check failure / SRC check failure" header-hizalama
  // hatalarının kök nedeniydi (bkz. PossibleProblems.md).
  //
  // K-LINE tek telli (half-duplex) olduğundan köprü adaptörü ham geçiş
  // yapıyorsa gönderdiğimiz baytlar aynı hat üzerinden bize yankı olarak geri
  // dönebilir (STKC de bunu bilerek okuyup atıyor) — expectEcho() bu yankıyı
  // gerçek yanıtla karışmadan sessizce tüketir.
  //
  // Teşhis: aynı header-hizalama hatası (PossibleProblems.md #17) artık
  // StartCommunication dışında HER RDBI/WDBI isteğinde de gözlemleniyor —
  // yazılım tarafındaki interByteDelay, writeCharacteristic() çağrısının
  // KENDİSİNİN ne kadar sürdüğünü (BLE ack round-trip / soket gecikmesi)
  // hesaba katmıyor; bu yüzden gerçek bayt-arası boşluk P4max=20ms'i aşıyor
  // olabilir. Aşağıdaki ölçüm, bir sonraki donanım testinde gerçek boşlukları
  // doğrudan görünür kılmak için eklendi — henüz bir "düzeltme" değil.
  Future<void> _write(List<int> frame) async {
    _buffer.expectEcho(frame);
    DateTime? previousByteSentAt;
    for (var i = 0; i < frame.length; i++) {
      final callStart = DateTime.now();
      if (previousByteSentAt != null) {
        final gapBeforeWrite = callStart.difference(previousByteSentAt).inMilliseconds;
        AppLogger.instance.log(
          'Bayt ${i + 1}/${frame.length}: bir önceki bayttan bu yana ${gapBeforeWrite}ms geçti '
          '(P4 penceresi: 5-20ms)',
          level: gapBeforeWrite < 5 || gapBeforeWrite > 20 ? LogLevel.error : LogLevel.info,
          category: LogCategory.bluetooth,
        );
      }
      await _transport.writeCharacteristic('SPP_DATA', [frame[i]]);
      previousByteSentAt = DateTime.now();
      final writeDuration = previousByteSentAt.difference(callStart).inMilliseconds;
      if (writeDuration > 5) {
        AppLogger.instance.log(
          'Bayt ${i + 1}/${frame.length}: writeCharacteristic() çağrısı ${writeDuration}ms sürdü '
          '(ack\'li yazım veya BLE gecikmesi olabilir)',
          level: LogLevel.info,
          category: LogCategory.bluetooth,
        );
      }
      await Future<void>.delayed(KLineTiming.interByteDelay);
    }
  }

  // Buffer'dan tam frame gelene kadar bekler
  Future<KLineResponse> _waitResponse({
    required Duration timeout,
    bool retryOnNrc78 = false,
  }) async {
    final baseDeadline = DateTime.now().add(timeout);
    // İlk NRC 0x78 alındığında set edilir; sonraki bekleme bu deadline'a
    // tabi olur (nrc78MaxWait'e kadar), tekrar tekrar uzatılmaz.
    DateTime? nrc78Deadline;

    while (true) {
      if (_connectionLost) {
        throw const KLineException('Bağlantı koptu');
      }
      final resp = _buffer.tryParse();
      if (resp != null) {
        // NRC 0x78: tachograph hâlâ işliyor — yeniden dene
        if (retryOnNrc78 &&
            resp.isNegative &&
            resp.nrc == KLineNrc.requestCorrectlyReceivedResponsePending) {
          nrc78Deadline ??= DateTime.now().add(KLineTiming.nrc78MaxWait);
          if (DateTime.now().isAfter(nrc78Deadline)) {
            throw const KLineException('NRC 0x78 azami bekleme süresi aşıldı');
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          continue;
        }
        return resp;
      }
      final effectiveDeadline = nrc78Deadline ?? baseDeadline;
      if (DateTime.now().isAfter(effectiveDeadline)) {
        // nrc78Deadline set edilmişse cihaz aktif olarak "meşgul" yanıtı verip
        // duruyordu — bu gerçek bir hata (KLineException), sessizce yutulmamalı.
        if (nrc78Deadline != null) {
          throw const KLineException('NRC 0x78 azami bekleme süresi aşıldı');
        }
        throw const KLineTimeoutException('Yanıt zaman aşımına uğradı');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
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
