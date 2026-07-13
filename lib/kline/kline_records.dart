// K-LINE / KWP2000 (ISO 14230) sabitleri — CalibrationMessages.md'e göre

class KLineRecords {
  KLineRecords._();

  // ── Araç kimliği ───────────────────────────────────────────────────────────
  static const int systemSupplierIdentifier          = 0xF18A;
  static const int ecuManufacturingDate              = 0xF18B;
  static const int serialNumber                      = 0xF18C;
  static const int vin                               = 0xF190;
  static const int hwNumber                          = 0xF192;
  static const int hwVersionNumber                   = 0xF193;
  static const int swNumber                          = 0xF194;
  static const int swVersionNumber                   = 0xF195;
  static const int exhaustRegOrTypeApprovalNumber    = 0xF196;
  static const int calibrationDate                   = 0xF19B;
  static const int ecuInstallDate                    = 0xF19D;

  // ── Araç & takograf verileri ───────────────────────────────────────────────
  static const int vehicleSpeed                      = 0xF902;
  static const int currentDateTime                   = 0xF90B;
  static const int resetHeartbeat                    = 0xF90C;
  static const int utcMinOffset                      = 0xF90D;
  static const int utcHourOffset                     = 0xF90E;
  static const int tco1Priority                      = 0xF90F;
  static const int odometer                          = 0xF912;
  static const int tripDistance                      = 0xF913;
  static const int serviceComponentId                = 0xF914;
  static const int serviceDelayCalendarTimeBased     = 0xF915;
  static const int kConstant                         = 0xF918;
  static const int teethCount                        = 0xF91A;
  static const int tyreCircumference                 = 0xF91C;
  static const int wConstant                         = 0xF91D;
  static const int pproos                            = 0xF91E;
  static const int tco1RepRate                       = 0xF920;
  static const int tyreSize                          = 0xF921;
  static const int nextCalDate                       = 0xF922;
  static const int speedLimit                        = 0xF92C;
  static const int memberState                       = 0xF97D;
  static const int vrn                               = 0xF97E;
  static const int vrd                               = 0xF97F;

  // ── İndirme & uyarı periyotları ────────────────────────────────────────────
  static const int downloadPeriodCard                = 0xF990;
  static const int downloadPeriodVu                  = 0xF991;
  static const int downloadPeriod992                 = 0xF992;
  static const int prewarningCard1                   = 0xF994;
  static const int prewarningTacho                   = 0xF995;
  static const int prewarningCal                     = 0xF996;

  // ── IO Control ─────────────────────────────────────────────────────────────
  static const int iocpDataId                        = 0xF960;

  // ── Opsiyon blokları ───────────────────────────────────────────────────────
  static const int optionsBlock8250                  = 0x8250;
  static const int optionsBlock8255                  = 0x8255;

  // ── Opsiyonel ayarlar (STC8250) ────────────────────────────────────────────
  static const int fd00SpeedometerFactor       = 0xFD00;
  static const int fd01B7Recognize             = 0xFD01;
  static const int fd02CardExpiryDates         = 0xFD02;
  static const int fd03CanCOnOff               = 0xFD03;
  static const int fd04MilitaryDimmer          = 0xFD04;
  static const int fd05CanCTco1               = 0xFD05;
  static const int fd06OverspeedPrewarningTime = 0xFD06;
  static const int fd07IgnitionOptions         = 0xFD07;
  static const int fd08CanABaudrate            = 0xFD08;
  static const int fd09CanCBaudrate            = 0xFD09;
  static const int fd0aBacklightBattery        = 0xFD0A;
  static const int fd0bDistanceUnit            = 0xFD0B;
  static const int fd0cLanguageChange          = 0xFD0C;
  static const int fd0dOverspeedOutput         = 0xFD0D;
  static const int fd0eBuzzerOverspeed         = 0xFD0E;
  static const int fd0fImsSource               = 0xFD0F;
  static const int fd10OverspeedTco1           = 0xFD10;
  static const int fd11TripmeterReset          = 0xFD11;
  static const int fd12OutputShaftSpeedEnable  = 0xFD12;
  static const int fd13Tco1HandlingInfo        = 0xFD13;
  static const int fd14CanASample              = 0xFD14;
  static const int fd15CanASyncJump            = 0xFD15;
  static const int fd16CanCSample              = 0xFD16;
  static const int fd17CanCSyncJump            = 0xFD17;
  static const int fd18ImsCanPgn               = 0xFD18;
  static const int fd19CanAOnOff               = 0xFD19;

  // ── Opsiyonel ayarlar (STC8255) ────────────────────────────────────────────
  static const int fd10BacklightSource8255         = 0xFD10;
  static const int fd11SpeedometerFactor8255       = 0xFD11;
  static const int fd12NProfileRegistry8255        = 0xFD12;
  static const int fd13NSpeedProfiles8255          = 0xFD13;
  static const int fd14VProfileRegistry8255        = 0xFD14;
  static const int fd15VSpeedProfiles8255          = 0xFD15;
  static const int fd16NFactor8255                 = 0xFD16;
  static const int fd17ImsSource8255               = 0xFD17;
  static const int fd18IgnitionOptions8255         = 0xFD18;
  static const int fd19LanguageChange8255          = 0xFD19;
  static const int fd1aOverspeedPrewarningTime8255 = 0xFD1A;
  static const int fd1bOverspeedOutput8255         = 0xFD1B;
  static const int fd1cB7Recognize8255             = 0xFD1C;
  static const int fd1dD1D2StateEnable8255         = 0xFD1D;
  static const int fd1eDistanceUnit8255            = 0xFD1E;
  static const int fd1fBuzzerOverspeed8255         = 0xFD1F;
  static const int fd22CardExpiryDates8255         = 0xFD22;
  static const int fd23EngineSpeedSource8255       = 0xFD23;
  static const int fd30CanProtocols8255            = 0xFD30;
  static const int fd31CanAOnOff8255               = 0xFD31;
  static const int fd32CanABaudrate8255            = 0xFD32;
  static const int fd33CanASyncJump8255            = 0xFD33;
  static const int fd34CanCOnOff8255               = 0xFD34;
  static const int fd35CanCBaudrate8255            = 0xFD35;
  static const int fd36CanCSyncJump8255            = 0xFD36;
  static const int fd3aOverspeedTco18255           = 0xFD3A;
  static const int fd3bTripmeterReset8255          = 0xFD3B;
  static const int fd3cTco1HandlingInfo8255        = 0xFD3C;
  static const int fd3dCanTerminations8255         = 0xFD3D;
  static const int fd3eRddwInSleep8255             = 0xFD3E;
  static const int fd41PeriodicDags8255            = 0xFD41;
  static const int fd50DagsBuzzerControl8255       = 0xFD50;
  static const int fd51CardExistenceWarning8255    = 0xFD51;
  static const int fd52CardRemoteDownload8255      = 0xFD52;
  static const int fd53GnssAntenna8255             = 0xFD53;
}

// ── Oturum tipleri (StartDiagnosticSession sub-function) ───────────────────
class KLineSession {
  KLineSession._();

  static const int standard    = 0x81; // StandartDiagnosticSession
  static const int programming = 0x85; // ECUProgrammingSession (write)
  static const int adjustment  = 0x87; // ECUAdjustmentSession (test / MS pairing)
}

// ── Servis IDleri (SID) ────────────────────────────────────────────────────
class KLineSid {
  KLineSid._();

  static const int startComm     = 0x81; // fast-init format
  static const int stopComm      = 0x82;
  static const int sessionCtrl   = 0x10;
  static const int testerPresent = 0x3E;
  static const int secAccess     = 0x27;
  static const int routineCtrl   = 0x31;
  static const int readDtcInfo   = 0x19;
  static const int clearDtcInfo  = 0x14;
  static const int rdbi          = 0x22; // ReadDataByIdentifier
  static const int wdbi          = 0x2E; // WriteDataByIdentifier
  static const int iocp          = 0x2F; // IOControlByIdentifier
  static const int negativeResp  = 0x7F;
}

// ── Rutin test IDleri ──────────────────────────────────────────────────────
class KLineRoutineIds {
  KLineRoutineIds._();

  static const int displayTest          = 0x0150;
  static const int lcdNegativeMode      = 0x0151;
  static const int printerTest          = 0x0152;
  static const int hardwareTest         = 0x0153;
  static const int smartCardReaderTest  = 0x0154;
  static const int motionSensorPairing  = 0x0155;
  static const int buttonTestLoop       = 0x0156;
  static const int batteryLevel         = 0x0157;
  static const int dataMemoryIntegrity  = 0x0158;
  static const int softwareIntegrity    = 0x0159;
  static const int buzzer               = 0x015A;
}

// ── RoutineControl sub-function seçicileri ─────────────────────────────────
class KLineRoutineSelect {
  KLineRoutineSelect._();

  static const int startRoutine          = 0x01;
  static const int stopRoutine           = 0x02;
  static const int requestRoutineResults = 0x03;
}

// ── IO Control seçenekleri ─────────────────────────────────────────────────
class KLineIocpControl {
  KLineIocpControl._();

  static const int returnControlToEcu   = 0x01; // Reset to default
  static const int shortTermAdjustment  = 0x03; // Enable calibration I/O

  static const int enableSpeedInput     = 0x01; // ShortTermAdjustment payload
  static const int enableSpeedOutput    = 0x02;
  static const int enableRtcOutput      = 0x03;
}

// ── Negative Response Codes (NRC) ──────────────────────────────────────────
class KLineNrc {
  KLineNrc._();

  static const int requestCorrectlyReceivedResponsePending = 0x78;
  static const int conditionsNotCorrect                    = 0x22;
  static const int requestOutOfRange                       = 0x31;
  static const int securityAccessDenied                    = 0x33;
  static const int invalidKey                              = 0x35;
  static const int exceededNumberOfAttempts                = 0x36;
  static const int requiredTimeDelayNotExpired             = 0x37;
}

// ── Timing sabitleri (ms) ──────────────────────────────────────────────────
class KLineTiming {
  KLineTiming._();

  static const Duration interMessageDelay = Duration(milliseconds: 60);
  static const Duration wakeupDelay       = Duration(milliseconds: 23);
  static const Duration testerPresentInterval = Duration(milliseconds: 150);
  static const Duration pinResponseTimeout    = Duration(seconds: 5);
  static const Duration sendKeyWait           = Duration(milliseconds: 1000);
  static const Duration msPairingPollInterval = Duration(milliseconds: 250);
  static const Duration defaultTimeout        = Duration(seconds: 5);
  static const Duration nrc78MaxWait          = Duration(seconds: 10);

  // DateTime değişimi bu eşiği aşarsa W-Constant da yeniden yazılmalı (protokol gereği)
  static const int dateTimeWConstantThresholdMinutes = 20;
}
