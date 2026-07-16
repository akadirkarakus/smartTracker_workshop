import 'package:flutter/material.dart';
import '../../bluetooth/models/log_entry.dart';
import '../../core/app_logger.dart';
import '../../kline/kline_codec.dart';
import '../../kline/kline_records.dart';
import '../../kline/kline_service.dart';
import '../../kline/parameter_validation.dart';
import '../../models/calibration_data.dart';

class OptionalSettingsScreen extends StatefulWidget {
  final OptionalSettings settings;
  final VoidCallback onChanged;
  final KLineService? klineService;
  final String? deviceHwNumber;
  final bool isPinAuthenticated;

  const OptionalSettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    this.klineService,
    this.deviceHwNumber,
    this.isPinAuthenticated = false,
  });

  @override
  State<OptionalSettingsScreen> createState() => _OptionalSettingsScreenState();
}

class _OptionalSettingsScreenState extends State<OptionalSettingsScreen> {
  late final OptionalSettings _s;
  late final bool _isStc8255;
  bool _isSaving = false;
  bool _isLoading = false;

  // Bağlı cihaz kesin olarak STC8250 ise "Yalnızca STC8255" alanları düzenlenemez.
  bool get _disableAdvanced => widget.klineService != null && !_isStc8255;

  // Askeri Dimmer yalnızca STC8250'de tanımlı bir K-Line kaydı.
  bool get _disableMilitaryDimmer => widget.klineService != null && _isStc8255;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _isStc8255 = widget.deviceHwNumber?.toUpperCase().contains('8255') ?? false;
    if (widget.klineService != null) {
      _loadFromDevice();
    }
  }

  Future<void> _loadFromDevice() async {
    final service = widget.klineService;
    if (service == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await service.readOptionalSettings(isStc8255: _isStc8255);
      if (!mounted) return;
      setState(() {
        _s.speedometerFactor = snap.speedometerFactor?.toString() ?? _s.speedometerFactor;
        _s.b7Recognize = snap.b7Recognize ?? _s.b7Recognize;
        _s.militaryDimmer = snap.militaryDimmer ?? _s.militaryDimmer;
        _s.overspeedPrewarningTime = snap.overspeedPrewarningTime ?? _s.overspeedPrewarningTime;
        _s.ignitionOption = snap.ignitionOption ?? _s.ignitionOption;
        _s.distanceUnit = snap.distanceUnit ?? _s.distanceUnit;
        _s.tripMeterReset = snap.tripMeterReset ?? _s.tripMeterReset;
        _s.imsSource = snap.imsSource ?? _s.imsSource;
        _s.canABaudrate = snap.canABaudrate ?? _s.canABaudrate;
        _s.canCBaudrate = snap.canCBaudrate ?? _s.canCBaudrate;
        _s.gnssAntenna = snap.gnssAntenna ?? _s.gnssAntenna;
        _s.periodicDags = snap.periodicDags ?? _s.periodicDags;
        _s.cardExistenceWarning = snap.cardExistenceWarning ?? _s.cardExistenceWarning;

        // Ortak — Sprint 5
        _s.languageChange = snap.languageChange ?? _s.languageChange;
        _s.overspeedOutput = snap.overspeedOutput ?? _s.overspeedOutput;
        _s.buzzerOverspeedControl = snap.buzzerOverspeedControl ?? _s.buzzerOverspeedControl;
        _s.overspeedTco1 = snap.overspeedTco1 ?? _s.overspeedTco1;
        _s.tco1HandlingInfo = snap.tco1HandlingInfo ?? _s.tco1HandlingInfo;
        _s.canASyncJump = snap.canASyncJump ?? _s.canASyncJump;
        _s.canCSyncJump = snap.canCSyncJump ?? _s.canCSyncJump;
        _s.canAOnOff = snap.canAOnOff ?? _s.canAOnOff;
        _s.canCOnOff = snap.canCOnOff ?? _s.canCOnOff;
        _s.cardExpiryControl = snap.cardExpiryControl ?? _s.cardExpiryControl;
        _s.cardExpiryDriver = snap.cardExpiryDriver ?? _s.cardExpiryDriver;
        _s.cardExpiryWorkshop = snap.cardExpiryWorkshop ?? _s.cardExpiryWorkshop;
        _s.cardExpiryCompany = snap.cardExpiryCompany ?? _s.cardExpiryCompany;
        _s.cardExpiryCalibration = snap.cardExpiryCalibration ?? _s.cardExpiryCalibration;

        // STC8250'ye özel — Sprint 5
        _s.canCTco1 = snap.canCTco1 ?? _s.canCTco1;
        _s.backlightLevel = snap.backlightLevel ?? _s.backlightLevel;
        _s.backlightBattery = snap.backlightBattery ?? _s.backlightBattery;
        _s.outputShaftSpeedEnable = snap.outputShaftSpeedEnable ?? _s.outputShaftSpeedEnable;
        _s.canASample = snap.canASample ?? _s.canASample;
        _s.canCSample = snap.canCSample ?? _s.canCSample;
        _s.imsCanPgn = snap.imsCanPgn ?? _s.imsCanPgn;

        // STC8255'e özel — Sprint 5
        _s.nProfileRegistry = snap.nProfileRegistry ?? _s.nProfileRegistry;
        _s.nSpeedProfiles = snap.nSpeedProfiles ?? _s.nSpeedProfiles;
        _s.vProfileRegistry = snap.vProfileRegistry ?? _s.vProfileRegistry;
        _s.vSpeedProfiles = snap.vSpeedProfiles ?? _s.vSpeedProfiles;
        _s.nFactor = snap.nFactor ?? _s.nFactor;
        _s.d1Enable = snap.d1Enable ?? _s.d1Enable;
        _s.d2Enable = snap.d2Enable ?? _s.d2Enable;
        _s.engineSpeedSource = snap.engineSpeedSource ?? _s.engineSpeedSource;
        _s.canProtocolP1 = snap.canProtocolP1 ?? _s.canProtocolP1;
        _s.canProtocolP2 = snap.canProtocolP2 ?? _s.canProtocolP2;
        _s.canATermination = snap.canATermination ?? _s.canATermination;
        _s.canCTermination = snap.canCTermination ?? _s.canCTermination;
        _s.rddwInSleep = snap.rddwInSleep ?? _s.rddwInSleep;
        _s.dagsBuzzerControl = snap.dagsBuzzerControl ?? _s.dagsBuzzerControl;
      });
    } catch (e) {
      AppLogger.instance.log(
        'Optional settings read error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Değişken/hâlihazırdaki değerleri (donanıma göre doğru kayıt ID'siyle) K-Line yazım listesine çevirir.
  List<MapEntry<int, List<int>>> _fieldsToWrite() {
    final entries = <MapEntry<int, List<int>>>[];
    void add(int recordId, List<int>? bytes) {
      if (bytes != null) entries.add(MapEntry(recordId, bytes));
    }

    add(
      _isStc8255 ? KLineRecords.fd11SpeedometerFactor8255 : KLineRecords.fd00SpeedometerFactor,
      _s.speedometerFactor == null ? null : KLineCodec.encodeSpeedometerFactor(int.parse(_s.speedometerFactor!)),
    );
    add(
      _isStc8255 ? KLineRecords.fd1cB7Recognize8255 : KLineRecords.fd01B7Recognize,
      _s.b7Recognize == null ? null : KLineCodec.encodeEnabledByte(_s.b7Recognize!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1aOverspeedPrewarningTime8255 : KLineRecords.fd06OverspeedPrewarningTime,
      _s.overspeedPrewarningTime == null ? null : KLineCodec.encodeOverspeedPrewarningSeconds(_s.overspeedPrewarningTime!),
    );
    add(
      _isStc8255 ? KLineRecords.fd18IgnitionOptions8255 : KLineRecords.fd07IgnitionOptions,
      _s.ignitionOption == null ? null : KLineCodec.encodeIgnitionOption(_s.ignitionOption!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1eDistanceUnit8255 : KLineRecords.fd0bDistanceUnit,
      _s.distanceUnit == null ? null : KLineCodec.encodeDistanceUnit(_s.distanceUnit!),
    );
    add(
      _isStc8255 ? KLineRecords.fd3bTripmeterReset8255 : KLineRecords.fd11TripmeterReset,
      _s.tripMeterReset == null ? null : KLineCodec.encodeEnabledByte(_s.tripMeterReset!),
    );
    add(
      _isStc8255 ? KLineRecords.fd17ImsSource8255 : KLineRecords.fd0fImsSource,
      _s.imsSource == null ? null : KLineCodec.encodeImsSource(_s.imsSource!),
    );
    add(
      _isStc8255 ? KLineRecords.fd32CanABaudrate8255 : KLineRecords.fd08CanABaudrate,
      _s.canABaudrate == null ? null : KLineCodec.encodeCanBaudrate(_s.canABaudrate!),
    );
    add(
      _isStc8255 ? KLineRecords.fd35CanCBaudrate8255 : KLineRecords.fd09CanCBaudrate,
      _s.canCBaudrate == null ? null : KLineCodec.encodeCanBaudrate(_s.canCBaudrate!),
    );

    // STC8250'ye özel — 8255'te bu kayıt ID'si tanımlı değil.
    if (!_isStc8255) {
      add(KLineRecords.fd04MilitaryDimmer, _s.militaryDimmer == null ? null : KLineCodec.encodeMilitaryDimmer(_s.militaryDimmer!));
    }

    // STC8255'e özel — 8250'de bu kayıt ID'leri tanımlı değil.
    if (_isStc8255) {
      add(KLineRecords.fd53GnssAntenna8255, _s.gnssAntenna == null ? null : KLineCodec.encodeGnssAntenna(_s.gnssAntenna!));
      add(KLineRecords.fd41PeriodicDags8255, _s.periodicDags == null ? null : KLineCodec.encodeEnabledByte(_s.periodicDags!));
      add(KLineRecords.fd51CardExistenceWarning8255, _s.cardExistenceWarning == null ? null : KLineCodec.encodeCardExistenceWarning(_s.cardExistenceWarning!));
    }

    // Ortak — Sprint 5
    add(
      _isStc8255 ? KLineRecords.fd19LanguageChange8255 : KLineRecords.fd0cLanguageChange,
      _s.languageChange == null ? null : KLineCodec.encodeLanguageChange(_s.languageChange!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1bOverspeedOutput8255 : KLineRecords.fd0dOverspeedOutput,
      _s.overspeedOutput == null ? null : KLineCodec.encodeOverspeedOutput(_s.overspeedOutput!),
    );
    add(
      _isStc8255 ? KLineRecords.fd1fBuzzerOverspeed8255 : KLineRecords.fd0eBuzzerOverspeed,
      _s.buzzerOverspeedControl == null ? null : KLineCodec.encodeEnabledByte(_s.buzzerOverspeedControl!),
    );
    add(
      _isStc8255 ? KLineRecords.fd3aOverspeedTco18255 : KLineRecords.fd10OverspeedTco1,
      _s.overspeedTco1 == null ? null : KLineCodec.encodeEnabledByte(_s.overspeedTco1!),
    );
    add(
      _isStc8255 ? KLineRecords.fd3cTco1HandlingInfo8255 : KLineRecords.fd13Tco1HandlingInfo,
      _s.tco1HandlingInfo == null ? null : KLineCodec.encodeTco1HandlingInfo(_s.tco1HandlingInfo!),
    );
    add(
      _isStc8255 ? KLineRecords.fd33CanASyncJump8255 : KLineRecords.fd15CanASyncJump,
      _s.canASyncJump == null ? null : KLineCodec.encodeRawByte(_s.canASyncJump!),
    );
    add(
      _isStc8255 ? KLineRecords.fd36CanCSyncJump8255 : KLineRecords.fd17CanCSyncJump,
      _s.canCSyncJump == null ? null : KLineCodec.encodeRawByte(_s.canCSyncJump!),
    );
    add(
      _isStc8255 ? KLineRecords.fd31CanAOnOff8255 : KLineRecords.fd19CanAOnOff,
      _s.canAOnOff == null ? null : (_isStc8255 ? KLineCodec.encodeEnabledByte(_s.canAOnOff!) : KLineCodec.encodeEnabledUint16(_s.canAOnOff!)),
    );
    add(
      _isStc8255 ? KLineRecords.fd34CanCOnOff8255 : KLineRecords.fd03CanCOnOff,
      _s.canCOnOff == null ? null : (_isStc8255 ? KLineCodec.encodeEnabledByte(_s.canCOnOff!) : KLineCodec.encodeEnabledUint16(_s.canCOnOff!)),
    );
    add(
      _isStc8255 ? KLineRecords.fd22CardExpiryDates8255 : KLineRecords.fd02CardExpiryDates,
      (_s.cardExpiryControl == null && _s.cardExpiryDriver == null && _s.cardExpiryWorkshop == null &&
              _s.cardExpiryCompany == null && _s.cardExpiryCalibration == null)
          ? null
          : KLineCodec.encodeCardExpiryDates(
              _s.cardExpiryControl ?? 0,
              _s.cardExpiryDriver ?? 0,
              _s.cardExpiryWorkshop ?? 0,
              _s.cardExpiryCompany ?? 0,
              _s.cardExpiryCalibration ?? 0,
            ),
    );

    // STC8250'ye özel
    if (!_isStc8255) {
      add(KLineRecords.fd05CanCTco1, _s.canCTco1 == null ? null : KLineCodec.encodeCanCTco1(_s.canCTco1!));
      add(
        KLineRecords.fd0aBacklightBattery,
        (_s.backlightLevel == null && _s.backlightBattery == null)
            ? null
            : KLineCodec.encodeBacklightBattery(_s.backlightLevel ?? 0, _s.backlightBattery ?? '24V'),
      );
      add(KLineRecords.fd12OutputShaftSpeedEnable, _s.outputShaftSpeedEnable == null ? null : KLineCodec.encodeEnabledByte(_s.outputShaftSpeedEnable!));
      add(KLineRecords.fd14CanASample, _s.canASample == null ? null : KLineCodec.encodeCanSamplePoint(_s.canASample!));
      add(KLineRecords.fd16CanCSample, _s.canCSample == null ? null : KLineCodec.encodeCanSamplePoint(_s.canCSample!));
      add(KLineRecords.fd18ImsCanPgn, _s.imsCanPgn == null ? null : KLineCodec.encodeImsCanPgn(_s.imsCanPgn!));
    }

    // STC8255'e özel
    if (_isStc8255) {
      add(KLineRecords.fd12NProfileRegistry8255, _s.nProfileRegistry == null ? null : KLineCodec.encodeEnabledByte(_s.nProfileRegistry!));
      add(KLineRecords.fd13NSpeedProfiles8255, _s.nSpeedProfiles == null ? null : KLineCodec.encodeNSpeedProfiles(_s.nSpeedProfiles!));
      add(KLineRecords.fd14VProfileRegistry8255, _s.vProfileRegistry == null ? null : KLineCodec.encodeEnabledByte(_s.vProfileRegistry!));
      add(KLineRecords.fd15VSpeedProfiles8255, _s.vSpeedProfiles == null ? null : KLineCodec.encodeVSpeedProfiles(_s.vSpeedProfiles!));
      add(KLineRecords.fd16NFactor8255, _s.nFactor == null ? null : KLineCodec.encodeNFactor(_s.nFactor!));
      add(
        KLineRecords.fd1dD1D2StateEnable8255,
        (_s.d1Enable == null && _s.d2Enable == null) ? null : KLineCodec.encodeD1D2Enable(_s.d1Enable ?? false, _s.d2Enable ?? false),
      );
      add(KLineRecords.fd23EngineSpeedSource8255, _s.engineSpeedSource == null ? null : KLineCodec.encodeEngineSpeedSource(_s.engineSpeedSource!));
      add(
        KLineRecords.fd30CanProtocols8255,
        (_s.canProtocolP1 == null && _s.canProtocolP2 == null) ? null : KLineCodec.encodeCanProtocols(_s.canProtocolP1 ?? 0, _s.canProtocolP2 ?? 0),
      );
      add(
        KLineRecords.fd3dCanTerminations8255,
        (_s.canATermination == null && _s.canCTermination == null) ? null : KLineCodec.encodeCanTerminations(_s.canATermination ?? false, _s.canCTermination ?? false),
      );
      add(KLineRecords.fd3eRddwInSleep8255, _s.rddwInSleep == null ? null : KLineCodec.encodeRawByte(_s.rddwInSleep!));
      add(KLineRecords.fd50DagsBuzzerControl8255, _s.dagsBuzzerControl == null ? null : KLineCodec.encodeEnabledByte(_s.dagsBuzzerControl!));
    }

    return entries;
  }

  Future<void> _save() async {
    if (!widget.isPinAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN doğrulaması gerekli — Ana Sayfa\'dan atölye PIN\'i ile giriş yapın.'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final service = widget.klineService;
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cihaz bağlı değil — değişiklikler K-Line\'a yazılamadı'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      for (final field in _fieldsToWrite()) {
        await service.writeParameter(field.key, field.value);
      }
      widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opsiyonel ayarlar kaydedildi'),
          backgroundColor: CalColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.instance.log(
        'Optional settings write error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yazma hatası: $e'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          icon: Icon(Icons.arrow_back, color: CalColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Opsiyonel Ayarlar', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: _isLoading
            ? [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: CalColors.primary)),
                  ),
                ),
              ]
            : null,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: 'Ortak Ayarlar', tag: 'STC8250 / STC8255'),
            const SizedBox(height: 8),
            _SettingsCard(children: [
              _NumberRow(
                label: 'Hız Göstergesi Faktörü',
                value: _s.speedometerFactor ?? '—',
                onEdit: () => _showEditDialog(
                  'Hız Göstergesi Faktörü',
                  _s.speedometerFactor ?? '',
                  (v) => _applyValidatedNumber(
                    v,
                    label: 'Hız Göstergesi Faktörü',
                    min: 1,
                    max: 60000,
                    onValid: (value) => setState(() => _s.speedometerFactor = value.toString()),
                  ),
                ),
              ),
              _ToggleRow(
                label: 'B7 Tanıma',
                value: _s.b7Recognize ?? false,
                onChanged: (v) => setState(() => _s.b7Recognize = v),
              ),
              Opacity(
                opacity: _disableMilitaryDimmer ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: _disableMilitaryDimmer,
                  child: _ToggleRow(
                    label: 'Askeri Dimmer',
                    value: _s.militaryDimmer ?? false,
                    onChanged: (v) => setState(() => _s.militaryDimmer = v),
                  ),
                ),
              ),
              _NumberRow(
                label: 'Aşırı Hız Ön Uyarı Süresi',
                value: '${_s.overspeedPrewarningTime ?? 0} sn',
                onEdit: () => _showEditDialog(
                  'Ön Uyarı Süresi (sn)',
                  (_s.overspeedPrewarningTime ?? 0).toString(),
                  (v) => _applyValidatedNumber(
                    v,
                    label: 'Aşırı Hız Ön Uyarı Süresi (sn)',
                    min: 0,
                    max: 60,
                    onValid: (value) => setState(() => _s.overspeedPrewarningTime = value),
                  ),
                ),
              ),
              _SelectRow(
                label: 'Kontak Seçeneği',
                value: _s.ignitionOption ?? 'Sürücü',
                options: const ['Sürücü', 'Ko-Pilot'],
                onSelect: (v) => setState(() => _s.ignitionOption = v),
              ),
              _SelectRow(
                label: 'Mesafe Birimi',
                value: _s.distanceUnit ?? 'km',
                options: const ['km', 'Mil'],
                onSelect: (v) => setState(() => _s.distanceUnit = v),
              ),
              _ToggleRow(
                label: 'Tripmetre Sıfırlama',
                value: _s.tripMeterReset ?? false,
                onChanged: (v) => setState(() => _s.tripMeterReset = v),
              ),
              _SelectRow(
                label: 'IMS Kaynağı',
                value: _s.imsSource ?? 'CAN A',
                options: const ['CAN A', 'CAN C', 'Devre Dışı'],
                onSelect: (v) => setState(() => _s.imsSource = v),
              ),
              _SelectRow(
                label: 'CAN A Baud Hızı',
                value: _s.canABaudrate ?? '250 kbps',
                options: const ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'],
                onSelect: (v) => setState(() => _s.canABaudrate = v),
              ),
              _SelectRow(
                label: 'CAN C Baud Hızı',
                value: _s.canCBaudrate ?? '250 kbps',
                options: const ['125 kbps', '250 kbps', '500 kbps', '1 Mbps'],
                onSelect: (v) => setState(() => _s.canCBaudrate = v),
              ),
              _SelectRow(
                label: 'Dil Değiştirme',
                value: _s.languageChange ?? 'Karttan',
                options: const ['Karttan', 'Kart ve Manuel'],
                onSelect: (v) => setState(() => _s.languageChange = v),
              ),
              _SelectRow(
                label: 'Aşırı Hız Ön Uyarı Çıkışı',
                value: _s.overspeedOutput ?? 'Devre Dışı',
                options: const ['Devre Dışı', 'Ekran', 'Buzzer', 'Çıkış', 'Tümü'],
                onSelect: (v) => setState(() => _s.overspeedOutput = v),
              ),
              _ToggleRow(
                label: 'Aşırı Hız Buzzer Kontrolü',
                value: _s.buzzerOverspeedControl ?? false,
                onChanged: (v) => setState(() => _s.buzzerOverspeedControl = v),
              ),
              _ToggleRow(
                label: 'Aşırı Hız TCO1',
                value: _s.overspeedTco1 ?? false,
                onChanged: (v) => setState(() => _s.overspeedTco1 = v),
              ),
              _SelectRow(
                label: 'TCO1 İşleme Bilgisi',
                value: _s.tco1HandlingInfo ?? 'Yok',
                options: const ['Yok', 'Kart', 'Kağıt', 'Kart ve Kağıt'],
                onSelect: (v) => setState(() => _s.tco1HandlingInfo = v),
              ),
              _NumberRow(
                label: 'CAN A Sync Jump',
                value: _s.canASyncJump?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'CAN A Sync Jump',
                  (_s.canASyncJump ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'CAN A Sync Jump', min: 0, max: 255, onValid: (value) => setState(() => _s.canASyncJump = value)),
                ),
              ),
              _NumberRow(
                label: 'CAN C Sync Jump',
                value: _s.canCSyncJump?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'CAN C Sync Jump',
                  (_s.canCSyncJump ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'CAN C Sync Jump', min: 0, max: 255, onValid: (value) => setState(() => _s.canCSyncJump = value)),
                ),
              ),
              _ToggleRow(
                label: 'CAN A Açık/Kapalı',
                value: _s.canAOnOff ?? false,
                onChanged: (v) => setState(() => _s.canAOnOff = v),
              ),
              _ToggleRow(
                label: 'CAN C Açık/Kapalı',
                value: _s.canCOnOff ?? false,
                onChanged: (v) => setState(() => _s.canCOnOff = v),
              ),
              _NumberRow(
                label: 'Kart Geçerlilik — Kontrol Kartı',
                value: _s.cardExpiryControl?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'Kontrol Kartı Geçerlilik (gün, 0-250)',
                  (_s.cardExpiryControl ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'Kontrol Kartı Geçerlilik', min: 0, max: 250, onValid: (value) => setState(() => _s.cardExpiryControl = value)),
                ),
              ),
              _NumberRow(
                label: 'Kart Geçerlilik — Sürücü Kartı',
                value: _s.cardExpiryDriver?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'Sürücü Kartı Geçerlilik (gün, 0-250)',
                  (_s.cardExpiryDriver ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'Sürücü Kartı Geçerlilik', min: 0, max: 250, onValid: (value) => setState(() => _s.cardExpiryDriver = value)),
                ),
              ),
              _NumberRow(
                label: 'Kart Geçerlilik — Atölye Kartı',
                value: _s.cardExpiryWorkshop?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'Atölye Kartı Geçerlilik (gün, 0-250)',
                  (_s.cardExpiryWorkshop ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'Atölye Kartı Geçerlilik', min: 0, max: 250, onValid: (value) => setState(() => _s.cardExpiryWorkshop = value)),
                ),
              ),
              _NumberRow(
                label: 'Kart Geçerlilik — Şirket Kartı',
                value: _s.cardExpiryCompany?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'Şirket Kartı Geçerlilik (gün, 0-250)',
                  (_s.cardExpiryCompany ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'Şirket Kartı Geçerlilik', min: 0, max: 250, onValid: (value) => setState(() => _s.cardExpiryCompany = value)),
                ),
              ),
              _NumberRow(
                label: 'Kart Geçerlilik — Kalibrasyon',
                value: _s.cardExpiryCalibration?.toString() ?? '—',
                onEdit: () => _showEditDialog(
                  'Kalibrasyon Geçerlilik (gün, 0-250)',
                  (_s.cardExpiryCalibration ?? 0).toString(),
                  (v) => _applyValidatedNumber(v, label: 'Kalibrasyon Geçerlilik', min: 0, max: 250, onValid: (value) => setState(() => _s.cardExpiryCalibration = value)),
                ),
              ),
            ]),

            const SizedBox(height: 20),
            _SectionHeader(title: 'STC8250\'ye Özel Ek Ayarlar', tag: 'Yalnızca STC8250'),
            const SizedBox(height: 8),
            Opacity(
              opacity: _disableMilitaryDimmer ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _disableMilitaryDimmer,
                child: _SettingsCard(children: [
                  _NumberRow(
                    label: 'CAN C TCO1',
                    value: _s.canCTco1?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'CAN C TCO1 (0-127)',
                      (_s.canCTco1 ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'CAN C TCO1', min: 0, max: 127, onValid: (value) => setState(() => _s.canCTco1 = value)),
                    ),
                  ),
                  _NumberRow(
                    label: 'Arka Işık Seviyesi',
                    value: _s.backlightLevel?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'Arka Işık Seviyesi (0-255)',
                      (_s.backlightLevel ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'Arka Işık Seviyesi', min: 0, max: 255, onValid: (value) => setState(() => _s.backlightLevel = value)),
                    ),
                  ),
                  _SelectRow(
                    label: 'Batarya Seçeneği',
                    value: _s.backlightBattery ?? '24V',
                    options: const ['24V', '12V'],
                    onSelect: (v) => setState(() => _s.backlightBattery = v),
                  ),
                  _ToggleRow(
                    label: 'Çıkış Mili Hızı Etkin',
                    value: _s.outputShaftSpeedEnable ?? false,
                    onChanged: (v) => setState(() => _s.outputShaftSpeedEnable = v),
                  ),
                  _NumberRow(
                    label: 'CAN A Örnekleme Noktası',
                    value: _s.canASample?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'CAN A Örnekleme Noktası (0-11)',
                      (_s.canASample ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'CAN A Örnekleme Noktası', min: 0, max: 11, onValid: (value) => setState(() => _s.canASample = value)),
                    ),
                  ),
                  _NumberRow(
                    label: 'CAN C Örnekleme Noktası',
                    value: _s.canCSample?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'CAN C Örnekleme Noktası (0-11)',
                      (_s.canCSample ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'CAN C Örnekleme Noktası', min: 0, max: 11, onValid: (value) => setState(() => _s.canCSample = value)),
                    ),
                  ),
                  _SelectRow(
                    label: 'IMS CAN PGN',
                    value: _s.imsCanPgn ?? 'PGN 65215',
                    options: const ['PGN 65215', 'PGN 65256'],
                    onSelect: (v) => setState(() => _s.imsCanPgn = v),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Gelişmiş Ayarlar', tag: 'Yalnızca STC8255'),
            const SizedBox(height: 8),
            Opacity(
              opacity: _disableAdvanced ? 0.4 : 1.0,
              child: IgnorePointer(
                ignoring: _disableAdvanced,
                child: _SettingsCard(children: [
                  _SelectRow(
                    label: 'GNSS Anten',
                    value: _s.gnssAntenna ?? 'İç',
                    options: const ['İç', 'Dış'],
                    onSelect: (v) => setState(() => _s.gnssAntenna = v),
                  ),
                  _ToggleRow(
                    label: 'Periyodik DAGS',
                    value: _s.periodicDags ?? false,
                    onChanged: (v) => setState(() => _s.periodicDags = v),
                  ),
                  _ToggleRow(
                    label: 'Kart Var/Yok Uyarı Çıkışı',
                    value: _s.cardExistenceWarning ?? false,
                    onChanged: (v) => setState(() => _s.cardExistenceWarning = v),
                  ),
                  _ToggleRow(
                    label: 'N Profil Kaydı',
                    value: _s.nProfileRegistry ?? false,
                    onChanged: (v) => setState(() => _s.nProfileRegistry = v),
                  ),
                  _NumberRow(
                    label: 'N Hız Profilleri (15 değer, virgülle)',
                    value: _s.nSpeedProfiles == null ? '—' : _s.nSpeedProfiles!.join(','),
                    onEdit: () => _showEditDialog(
                      'N Hız Profilleri — 15 değer, virgülle ayrılmış (0-65535)',
                      _s.nSpeedProfiles?.join(',') ?? '',
                      (v) => _applyValidatedIntList(v, label: 'N Hız Profilleri', min: 0, max: 65535, onValid: (values) => setState(() => _s.nSpeedProfiles = values)),
                    ),
                  ),
                  _ToggleRow(
                    label: 'V Profil Kaydı',
                    value: _s.vProfileRegistry ?? false,
                    onChanged: (v) => setState(() => _s.vProfileRegistry = v),
                  ),
                  _NumberRow(
                    label: 'V Hız Profilleri (15 değer, virgülle)',
                    value: _s.vSpeedProfiles == null ? '—' : _s.vSpeedProfiles!.join(','),
                    onEdit: () => _showEditDialog(
                      'V Hız Profilleri — 15 değer, virgülle ayrılmış (0-255)',
                      _s.vSpeedProfiles?.join(',') ?? '',
                      (v) => _applyValidatedIntList(v, label: 'V Hız Profilleri', min: 0, max: 255, onValid: (values) => setState(() => _s.vSpeedProfiles = values)),
                    ),
                  ),
                  _NumberRow(
                    label: 'N Faktörü',
                    value: _s.nFactor?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'N Faktörü (2000-64000)',
                      (_s.nFactor ?? 2000).toString(),
                      (v) => _applyValidatedNumber(v, label: 'N Faktörü', min: 2000, max: 64000, onValid: (value) => setState(() => _s.nFactor = value)),
                    ),
                  ),
                  _ToggleRow(
                    label: 'D1 Durumu Etkin',
                    value: _s.d1Enable ?? false,
                    onChanged: (v) => setState(() => _s.d1Enable = v),
                  ),
                  _ToggleRow(
                    label: 'D2 Durumu Etkin',
                    value: _s.d2Enable ?? false,
                    onChanged: (v) => setState(() => _s.d2Enable = v),
                  ),
                  _SelectRow(
                    label: 'Motor Hızı Kaynağı',
                    value: _s.engineSpeedSource ?? 'Devre Dışı',
                    options: const ['Devre Dışı', 'CAN-A', 'CAN-C', 'C3 Rev'],
                    onSelect: (v) => setState(() => _s.engineSpeedSource = v),
                  ),
                  _NumberRow(
                    label: 'CAN Protokolü P1',
                    value: _s.canProtocolP1?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'CAN Protokolü P1 (0-255)',
                      (_s.canProtocolP1 ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'CAN Protokolü P1', min: 0, max: 255, onValid: (value) => setState(() => _s.canProtocolP1 = value)),
                    ),
                  ),
                  _NumberRow(
                    label: 'CAN Protokolü P2',
                    value: _s.canProtocolP2?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'CAN Protokolü P2 (0-255)',
                      (_s.canProtocolP2 ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'CAN Protokolü P2', min: 0, max: 255, onValid: (value) => setState(() => _s.canProtocolP2 = value)),
                    ),
                  ),
                  _ToggleRow(
                    label: 'CAN A Sonlandırma',
                    value: _s.canATermination ?? false,
                    onChanged: (v) => setState(() => _s.canATermination = v),
                  ),
                  _ToggleRow(
                    label: 'CAN C Sonlandırma',
                    value: _s.canCTermination ?? false,
                    onChanged: (v) => setState(() => _s.canCTermination = v),
                  ),
                  _NumberRow(
                    label: 'RDDW in Sleep (ham değer)',
                    value: _s.rddwInSleep?.toString() ?? '—',
                    onEdit: () => _showEditDialog(
                      'RDDW in Sleep (0-255, doküman formatı belirtmiyor)',
                      (_s.rddwInSleep ?? 0).toString(),
                      (v) => _applyValidatedNumber(v, label: 'RDDW in Sleep', min: 0, max: 255, onValid: (value) => setState(() => _s.rddwInSleep = value)),
                    ),
                  ),
                  _ToggleRow(
                    label: 'DAGS Buzzer Kontrolü',
                    value: _s.dagsBuzzerControl ?? false,
                    onChanged: (v) => setState(() => _s.dagsBuzzerControl = v),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CalColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CalColors.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: CalColors.accent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'STC8255\'e özel ayarlar STC8250 donanımında "GEÇERSİZ" olarak gösterilir ve yazılamaz.',
                      style: TextStyle(fontSize: 12, color: CalColors.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Kaydediliyor...' : 'Tüm Değişiklikleri Kaydet', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Ham girdiyi doğrular; geçersizse state'i değiştirmeden bir SnackBar ile
  // net hata mesajı gösterir (bkz. SPRINT_BACKLOG.md H12).
  void _applyValidatedNumber(
    String raw, {
    required String label,
    required int min,
    required int max,
    required void Function(int) onValid,
  }) {
    try {
      final value = ParameterValidator.validateNumberInRange(raw, label: label, min: min, max: max);
      onValid(value);
    } on ParamValidationException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Virgülle ayrılmış 15 tam sayı listesini doğrular (N/V Hız Profilleri).
  void _applyValidatedIntList(
    String raw, {
    required String label,
    required int min,
    required int max,
    required void Function(List<int>) onValid,
  }) {
    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label: Virgülle ayrılmış tam olarak 15 değer girilmelidir.'),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final values = parts.map((p) => ParameterValidator.validateNumberInRange(p, label: label, min: min, max: max)).toList();
      onValid(values);
    } on ParamValidationException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: CalColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEditDialog(String label, String initial, void Function(String) onSave) {
    final controller = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CalColors.primary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CalColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable row widgets ──────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String tag;

  const _SectionHeader({required this.title, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalColors.outline, letterSpacing: 0.8),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: CalColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
          child: Text(tag, style: TextStyle(fontSize: 11, color: CalColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CalColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalColors.outlineVariant),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              children[i],
              if (i < children.length - 1) Divider(height: 1, indent: 16, endIndent: 0, color: CalColors.outlineVariant),
            ],
          );
        }),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: CalColors.onSurface))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: CalColors.accent,
            activeTrackColor: CalColors.accent.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final void Function(String) onSelect;

  const _SelectRow({required this.label, required this.value, required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: CalColors.onSurface))),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) { if (v != null) onSelect(v); },
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _NumberRow({required this.label, required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: CalColors.onSurface))),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CalColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CalColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: TextStyle(fontSize: 14, color: CalColors.primary, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 14, color: CalColors.outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
