// Donanım Testi orkestratörü — Ayarlar > "Donanım Testi Yap" tarafından kullanılır.
//
// Amaç: tüm kalibrasyon parametrelerini, opsiyonel ayarları, DTC servislerini ve
// bileşen self-testlerini sırayla otomatik olarak deneyip her biri için bağımsız
// pass/fail/skip sonucu üretmek. Her adım kendi try/catch'i içindedir — biri
// başarısız olsa da sweep durmaz, sonraki adımlar çalışmaya devam eder.
//
// Bilinçli olarak DIŞLANANLAR (asla çağrılmaz):
//  - clearDtcCodes()      — geri dönüşü olmayan bir işlem, sadece okuma test edilir.
//  - pairMotionSensor()   — gerçek bir eşleştirme yan etkisi olan bir işlem, self-test değil.
//  - runClockTest()/runSpeedOdometerTest() — süresi uzun (dk mertebesinde), ayrı
//    "Genişletilmiş Test" giriş noktasında (extended_hardware_test_screen.dart) çalıştırılır.
//
// Sahte "Geçti" üretmemek için (bkz. SPRINT_BACKLOG.md K4/H5): operatörün takograf
// ekranını görüp F1/F4 basmasını gerektiren rutinler asla `pass` almaz, sadece
// `visualConfirmRequired`. Cihazın kendi kendine sonuçlandırdığı rutinler (Hardware/
// Battery/Data Memory/SW Integrity) da `pass` değil `commsOkResultUnverified` alır —
// çünkü CONDITIONS_NOT_CORRECT NRC'sinin "tamamlandı" anlamına geldiği varsayımı
// henüz gerçek donanımda doğrulanmadı (bkz. CalibrationMessages.md Flow 15).

import 'dart:async';

import '../bluetooth/models/log_entry.dart';
import '../core/app_logger.dart';
import '../models/hardware_test_report.dart';
import '../services/hardware_test_report_store.dart';
import 'kline_codec.dart';
import 'kline_records.dart';
import 'kline_service.dart';

// Test Modu açıkken donanım testi sonuçlarının paylaşılan "Test Günlüğü"nde
// (AppLogger/TestLogScreen) de görünmesi için — asıl canlı log ekranı
// HardwareTestRunScreen'dir ve Test Modu'ndan bağımsız her zaman çalışır.
LogLevel _logLevelFor(HwTestStatus status) => switch (status) {
      HwTestStatus.pass => LogLevel.success,
      HwTestStatus.fail => LogLevel.error,
      HwTestStatus.visualConfirmRequired => LogLevel.info,
      HwTestStatus.skipped => LogLevel.info,
      HwTestStatus.commsOkResultUnverified => LogLevel.info,
    };

class HardwareTestProgress {
  const HardwareTestProgress({
    required this.completedCount,
    required this.totalCount,
    this.lastItem,
    required this.isDone,
    this.finalReport,
  });

  final int completedCount;
  final int totalCount;
  final HardwareTestItemResult? lastItem;
  final bool isDone;
  final HardwareTestReport? finalReport;
}

class _RecordTestSpec {
  const _RecordTestSpec(this.id, this.label, this.recordId, {this.writable = true});
  final String id;
  final String label;
  final int recordId;
  final bool writable;
}

// CalParam'ların ve cihaz kimlik alanlarının tek-tek okunacağı/yazılacağı kayıtlar.
// Bkz. calibration_screen.dart:_writeCalParam ve kline_service.dart:readAllCalibrationData
// — aynı record ID eşlemesi burada tekrar kullanılıyor.
const List<_RecordTestSpec> _calParamRecords = [
  _RecordTestSpec('vrn', 'Plaka (VRN)', KLineRecords.vrn),
  _RecordTestSpec('vin', 'VIN', KLineRecords.vin),
  _RecordTestSpec('member_state', 'Kayıt Ülkesi', KLineRecords.memberState),
  _RecordTestSpec('reg_date', 'Araç Tescil Tarihi', KLineRecords.vrd),
  _RecordTestSpec('tyre_size', 'Lastik Boyutu', KLineRecords.tyreSize),
  _RecordTestSpec('tyre_circ', 'Lastik Çevresi', KLineRecords.tyreCircumference),
  _RecordTestSpec('k_constant', 'K-Sabiti', KLineRecords.kConstant),
  _RecordTestSpec('w_constant', 'W-Sabiti', KLineRecords.wConstant),
  _RecordTestSpec('pproos', 'Çıkış Mili Hızı (PPROOS)', KLineRecords.pproos),
  _RecordTestSpec('teeth_count', 'Diş Sayısı', KLineRecords.teethCount),
  _RecordTestSpec('speed_limit', 'Hız Limiti', KLineRecords.speedLimit),
  _RecordTestSpec('odometer', 'Kilometre Sayacı', KLineRecords.odometer),
  _RecordTestSpec('trip_distance', 'Seyahat Mesafesi', KLineRecords.tripDistance),
  _RecordTestSpec('datetime', 'Tarih ve Saat', KLineRecords.currentDateTime),
  _RecordTestSpec('utc_min_offset', 'UTC Farkı (Dakika)', KLineRecords.utcMinOffset),
  _RecordTestSpec('utc_hour_offset', 'UTC Farkı (Saat)', KLineRecords.utcHourOffset),
  _RecordTestSpec('heartbeat', 'Kalp Atışı Sıfırlama', KLineRecords.resetHeartbeat),
  _RecordTestSpec('tco1_priority', 'TCO1 Önceliği', KLineRecords.tco1Priority),
  _RecordTestSpec('tco1_rate', 'TCO1 Tekrar Hızı', KLineRecords.tco1RepRate),
  _RecordTestSpec('ecu_install_date', 'ECU Kurulum Tarihi', KLineRecords.ecuInstallDate),
  _RecordTestSpec('next_cal_date', 'Sonraki Kalibrasyon Tarihi', KLineRecords.nextCalDate),
  _RecordTestSpec('prewarning_card1', 'Kart 1 Ön Uyarı Süresi', KLineRecords.prewarningCard1),
  _RecordTestSpec('prewarning_tacho', 'Takograf Ön Uyarı Süresi', KLineRecords.prewarningTacho),
  _RecordTestSpec('prewarning_cal', 'Kalibrasyon Ön Uyarı Süresi', KLineRecords.prewarningCal),
  _RecordTestSpec('download_period_vu', 'İndirme Periyodu - VU', KLineRecords.downloadPeriodVu),
  _RecordTestSpec('download_period_card', 'İndirme Periyodu - Kart', KLineRecords.downloadPeriodCard),
  _RecordTestSpec('hw_number', 'Cihaz Modeli (HW No)', KLineRecords.hwNumber, writable: false),
  _RecordTestSpec('hw_version', 'Donanım Versiyonu', KLineRecords.hwVersionNumber, writable: false),
  _RecordTestSpec('sw_version', 'Yazılım Versiyonu', KLineRecords.swVersionNumber, writable: false),
  _RecordTestSpec('serial_number', 'Seri Numarası', KLineRecords.serialNumber, writable: false),
];

const Map<String, String> _componentTestLabels = {
  'display': 'Ekran Testi',
  'lcd_neg': 'LCD Negatif Modu',
  'printer': 'Yazıcı Testi',
  'hardware': 'Donanım Testi',
  'card_reader': 'Kart Okuyucu Testi (Slot 1)',
  'keypad': 'Tuş Takımı Testi',
  'battery': 'Batarya Seviye Testi',
  'data_memory': 'Veri Bellek Bütünlüğü',
  'sw_integrity': 'Yazılım Bütünlüğü',
  'buzzer_test': 'Zil Testi',
};

class HardwareTestRunner {
  HardwareTestRunner(this._service);
  final KLineService _service;

  int _totalCount(bool isStc8255) =>
      _calParamRecords.length + // okuma
      _calParamRecords.where((s) => s.writable).length + // yaz-doğrula
      (isStc8255 ? 12 : 10) + // opsiyonel ayarlar
      2 + // DTC sayısı + kodları
      kComponentTestRoutineMap.length; // bileşen self-testleri

  Stream<HardwareTestProgress> run({
    required bool pinAuthenticated,
    required bool isStc8255,
  }) async* {
    final startedAt = DateTime.now();
    final total = _totalCount(isStc8255);
    final results = <HardwareTestItemResult>[];
    final rawValues = <String, List<int>>{};
    String? hwNumber, hwVersion, swVersion, serialNumber;

    // Sonucu listeye ekler ve Test Modu açıkken paylaşılan Test Günlüğü'ne de
    // yazar (AppLogger, testModeEnabled=false iken no-op) — asıl garantili canlı
    // görünüm HardwareTestRunScreen'in kendi log ekranıdır (bkz. yukarıdaki not).
    void record(HardwareTestItemResult r) {
      results.add(r);
      AppLogger.instance.log(
        '${r.label} — ${r.status.label}: ${r.detail}',
        level: _logLevelFor(r.status),
        category: LogCategory.diagnostics,
      );
    }

    HardwareTestProgress tick(HardwareTestItemResult r) {
      record(r);
      return HardwareTestProgress(
        completedCount: results.length,
        totalCount: total,
        lastItem: r,
        isDone: false,
      );
    }

    // ── 1) CalParam + kimlik alanları okuma (Flow 9 — tek tek, hata izolasyonu için) ──
    for (final spec in _calParamRecords) {
      final sw = Stopwatch()..start();
      try {
        final bytes = await _service.readParameter(spec.recordId);
        sw.stop();
        rawValues[spec.id] = bytes;
        switch (spec.id) {
          case 'hw_number':
            hwNumber = KLineCodec.decodeAsciiTrimmed(bytes);
          case 'hw_version':
            hwVersion = KLineCodec.decodeAsciiTrimmed(bytes);
          case 'sw_version':
            swVersion = KLineCodec.decodeAsciiTrimmed(bytes);
          case 'serial_number':
            serialNumber = KLineCodec.decodeAsciiTrimmed(bytes);
        }
        yield tick(HardwareTestItemResult(
          id: 'read_${spec.id}',
          label: spec.label,
          category: HwTestItemCategory.calParamRead,
          recordId: spec.recordId,
          status: HwTestStatus.pass,
          detail: 'Okundu: ${_hex(bytes)}',
          duration: sw.elapsed,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        sw.stop();
        yield tick(HardwareTestItemResult(
          id: 'read_${spec.id}',
          label: spec.label,
          category: HwTestItemCategory.calParamRead,
          recordId: spec.recordId,
          status: HwTestStatus.fail,
          detail: e.toString(),
          duration: sw.elapsed,
          timestamp: DateTime.now(),
        ));
      }
    }

    // ── 2) Yaz-geri-oku doğrulaması (Flow 3 — okunan aynı ham baytları geri yaz) ──
    for (final spec in _calParamRecords) {
      if (!spec.writable) continue;
      if (spec.id == 'k_constant') continue; // w_constant ile birlikte ele alınır (aşağıda)

      Future<void> handle(String id, String label, int recordId, List<int>? current) async {
        if (!pinAuthenticated) {
          record(HardwareTestItemResult(
            id: 'write_$id',
            label: label,
            category: HwTestItemCategory.calParamWriteVerify,
            recordId: recordId,
            status: HwTestStatus.skipped,
            detail: 'PIN doğrulaması gerekli',
            duration: Duration.zero,
            timestamp: DateTime.now(),
          ));
          return;
        }
        if (current == null || current.isEmpty) {
          record(HardwareTestItemResult(
            id: 'write_$id',
            label: label,
            category: HwTestItemCategory.calParamWriteVerify,
            recordId: recordId,
            status: HwTestStatus.skipped,
            detail: 'Mevcut değer bilinmiyor, yazma atlandı',
            duration: Duration.zero,
            timestamp: DateTime.now(),
          ));
          return;
        }
        final sw = Stopwatch()..start();
        try {
          await _service.writeParameter(recordId, current);
          sw.stop();
          record(HardwareTestItemResult(
            id: 'write_$id',
            label: label,
            category: HwTestItemCategory.calParamWriteVerify,
            recordId: recordId,
            status: HwTestStatus.pass,
            detail: 'Aynı değer geri yazıldı ve doğrulandı: ${_hex(current)}',
            duration: sw.elapsed,
            timestamp: DateTime.now(),
          ));
        } catch (e) {
          sw.stop();
          record(HardwareTestItemResult(
            id: 'write_$id',
            label: label,
            category: HwTestItemCategory.calParamWriteVerify,
            recordId: recordId,
            status: HwTestStatus.fail,
            detail: e.toString(),
            duration: sw.elapsed,
            timestamp: DateTime.now(),
          ));
        }
      }

      await handle(spec.id, spec.label, spec.recordId, rawValues[spec.id]);

      // Stoneridge kuralı: W-Constant yazımı K-Constant'ı da aynı değerle
      // yazıp doğrular (kline_service.dart:writeParameter, satır ~405-429).
      // K-Constant'ı ayrıca test etmiyoruz — sonucunu W-Constant'ınkine bağlıyoruz.
      if (spec.id == 'w_constant') {
        final wResult = results.last;
        record(HardwareTestItemResult(
          id: 'write_k_constant',
          label: 'K-Sabiti',
          category: HwTestItemCategory.calParamWriteVerify,
          recordId: KLineRecords.kConstant,
          status: wResult.status == HwTestStatus.pass ? HwTestStatus.skipped : wResult.status,
          detail: wResult.status == HwTestStatus.pass
              ? "W-Sabiti testi K-Sabiti'ni eş zamanlı doğruladı (Stoneridge kuralı)"
              : "W-Sabiti yazımı başarısız/atlandığı için K-Sabiti doğrulaması da yapılamadı",
          duration: Duration.zero,
          timestamp: DateTime.now(),
        ));
      }
      yield HardwareTestProgress(
        completedCount: results.length,
        totalCount: total,
        lastItem: results.last,
        isDone: false,
      );
    }

    // ── 3) Opsiyonel Ayarlar okuma (tek transaction, alan-bazlı hataya karşı korumalı) ──
    try {
      final snap = await _service.readOptionalSettings(isStc8255: isStc8255);
      void emitField(String id, String label, dynamic value) {
        record(HardwareTestItemResult(
          id: 'opt_$id',
          label: label,
          category: HwTestItemCategory.optionalSettingRead,
          status: value == null ? HwTestStatus.fail : HwTestStatus.pass,
          detail: value == null ? 'Okunamadı/desteklenmiyor' : 'Okundu: $value',
          duration: Duration.zero,
          timestamp: DateTime.now(),
        ));
      }

      emitField('speedometer_factor', 'Hız Göstergesi Faktörü', snap.speedometerFactor);
      emitField('b7_recognize', 'B7 Tanıma', snap.b7Recognize);
      emitField('overspeed_prewarning', 'Aşırı Hız Ön Uyarı Süresi', snap.overspeedPrewarningTime);
      emitField('ignition_option', 'Ateşleme Seçeneği', snap.ignitionOption);
      emitField('distance_unit', 'Mesafe Birimi', snap.distanceUnit);
      emitField('trip_meter_reset', 'Tripmetre Sıfırlama', snap.tripMeterReset);
      emitField('ims_source', 'IMS Kaynağı', snap.imsSource);
      emitField('can_a_baudrate', 'CAN-A Hızı', snap.canABaudrate);
      emitField('can_c_baudrate', 'CAN-C Hızı', snap.canCBaudrate);
      if (isStc8255) {
        emitField('gnss_antenna', 'GNSS Anteni', snap.gnssAntenna);
        emitField('periodic_dags', 'Periyodik DAGS', snap.periodicDags);
        emitField('card_existence_warning', 'Kart Varlık Uyarısı', snap.cardExistenceWarning);
      } else {
        emitField('military_dimmer', 'Askeri Dimmer', snap.militaryDimmer);
      }
    } catch (e) {
      // Tüm bölüm başarısız oldu (bağlantı koptu vb.) — beklenen alan sayısı kadar 'fail' üret.
      final count = isStc8255 ? 12 : 10;
      for (int i = 0; i < count; i++) {
        record(HardwareTestItemResult(
          id: 'opt_fail_$i',
          label: 'Opsiyonel Ayar #$i',
          category: HwTestItemCategory.optionalSettingRead,
          status: HwTestStatus.fail,
          detail: e.toString(),
          duration: Duration.zero,
          timestamp: DateTime.now(),
        ));
      }
    }
    yield HardwareTestProgress(
      completedCount: results.length,
      totalCount: total,
      lastItem: results.isNotEmpty ? results.last : null,
      isDone: false,
    );

    // ── 4) DTC okuma (temizleme ASLA çağrılmaz) ──
    try {
      final sw = Stopwatch()..start();
      final count = await _service.readDtcCount();
      sw.stop();
      record(HardwareTestItemResult(
        id: 'dtc_count',
        label: 'DTC Sayısı',
        category: HwTestItemCategory.dtcCountRead,
        status: HwTestStatus.pass,
        detail: '$count adet hata kodu',
        duration: sw.elapsed,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      record(HardwareTestItemResult(
        id: 'dtc_count',
        label: 'DTC Sayısı',
        category: HwTestItemCategory.dtcCountRead,
        status: HwTestStatus.fail,
        detail: e.toString(),
        duration: Duration.zero,
        timestamp: DateTime.now(),
      ));
    }
    yield HardwareTestProgress(
      completedCount: results.length,
      totalCount: total,
      lastItem: results.last,
      isDone: false,
    );

    try {
      final sw = Stopwatch()..start();
      final codes = await _service.readDtcCodes();
      sw.stop();
      record(HardwareTestItemResult(
        id: 'dtc_codes',
        label: 'DTC Kodları',
        category: HwTestItemCategory.dtcCodesRead,
        status: HwTestStatus.pass,
        detail: '${codes.length} kod okundu',
        duration: sw.elapsed,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      record(HardwareTestItemResult(
        id: 'dtc_codes',
        label: 'DTC Kodları',
        category: HwTestItemCategory.dtcCodesRead,
        status: HwTestStatus.fail,
        detail: e.toString(),
        duration: Duration.zero,
        timestamp: DateTime.now(),
      ));
    }
    yield HardwareTestProgress(
      completedCount: results.length,
      totalCount: total,
      lastItem: results.last,
      isDone: false,
    );

    // ── 5) Bileşen self-testleri (Flow 12-21) — motion sensor pairing HİÇ dahil değil ──
    for (final entry in kComponentTestRoutineMap.entries) {
      final testId = entry.key;
      final routineId = entry.value;
      final label = _componentTestLabels[testId] ?? testId;
      final sw = Stopwatch()..start();
      try {
        if (testId == 'card_reader') {
          await _service.startRoutineTest(routineId, slotNumber: 1);
        } else {
          await _service.startRoutineTest(routineId);
        }

        if (kAutoResultTestIds.contains(testId)) {
          final completion = await _service.pollRoutineCompletion(routineId);
          // stopRoutine yanıtı doküman düzeyinde hiç gösterilmemiştir (Flow 15,
          // 18-20) — zaman aşımı burada hata sayılmaz, sessizce yutulur.
          try {
            await _service.stopRoutineTest(routineId);
          } on KLineTimeoutException {
            // beklenen davranış
          }
          sw.stop();
          record(HardwareTestItemResult(
            id: 'routine_$testId',
            label: label,
            category: HwTestItemCategory.componentAutoResult,
            routineId: routineId,
            status: completion == RoutineCompletionStatus.timedOut
                ? HwTestStatus.fail
                : HwTestStatus.commsOkResultUnverified,
            detail: completion == RoutineCompletionStatus.timedOut
                ? 'Tamamlanma sinyali alınamadı (zaman aşımı)'
                : 'İletişim OK — sonuç yorumu donanımda doğrulanmalı',
            duration: sw.elapsed,
            timestamp: DateTime.now(),
          ));
        } else if (kVisualConfirmTestIds.contains(testId)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          await _service.stopRoutineTest(routineId, operatorResult: null);
          sw.stop();
          record(HardwareTestItemResult(
            id: 'routine_$testId',
            label: label,
            category: HwTestItemCategory.componentVisualConfirm,
            routineId: routineId,
            status: HwTestStatus.visualConfirmRequired,
            detail: 'İletişim OK — ekranda/çıktıda operatör onayı gerekli (F1/F4)',
            duration: sw.elapsed,
            timestamp: DateTime.now(),
          ));
        } else if (kNoResultTestIds.contains(testId)) {
          // keypad / buzzer — gözlemlenemez, sadece iletişim kontrolü.
          // Doküman bu testler için stopRoutine dahi göndermez (Flow 17, 21) —
          // yanıt zaman aşımı hata sayılmaz, sessizce yutulur.
          await Future<void>.delayed(const Duration(seconds: 2));
          try {
            await _service.stopRoutineTest(routineId);
          } on KLineTimeoutException {
            // beklenen davranış
          }
          sw.stop();
          record(HardwareTestItemResult(
            id: 'routine_$testId',
            label: label,
            category: HwTestItemCategory.componentNoResult,
            routineId: routineId,
            status: HwTestStatus.commsOkResultUnverified,
            detail: 'İletişim OK — sonuç gözlemlenemez (tuş basımı/ses algılanamaz)',
            duration: sw.elapsed,
            timestamp: DateTime.now(),
          ));
        }
      } catch (e) {
        sw.stop();
        final category = kAutoResultTestIds.contains(testId)
            ? HwTestItemCategory.componentAutoResult
            : kVisualConfirmTestIds.contains(testId)
                ? HwTestItemCategory.componentVisualConfirm
                : HwTestItemCategory.componentNoResult;
        record(HardwareTestItemResult(
          id: 'routine_$testId',
          label: label,
          category: category,
          routineId: routineId,
          status: HwTestStatus.fail,
          detail: e.toString(),
          duration: sw.elapsed,
          timestamp: DateTime.now(),
        ));
      }
      yield HardwareTestProgress(
        completedCount: results.length,
        totalCount: total,
        lastItem: results.last,
        isDone: false,
      );
    }

    final report = HardwareTestReport(
      id: 'hwtest_${startedAt.millisecondsSinceEpoch}',
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      pinAuthenticatedDuringRun: pinAuthenticated,
      deviceModel: hwNumber,
      deviceSerial: serialNumber,
      deviceFwVersion: swVersion,
      deviceHwVersion: hwVersion,
      items: List.unmodifiable(results),
    );
    await HardwareTestReportStore.save(report);

    yield HardwareTestProgress(
      completedCount: results.length,
      totalCount: total,
      lastItem: results.last,
      isDone: true,
      finalReport: report,
    );
  }

  static String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
