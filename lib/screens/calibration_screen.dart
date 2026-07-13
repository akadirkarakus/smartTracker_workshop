import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bluetooth/models/ble_device_result.dart';
import '../bluetooth/models/log_entry.dart';
import '../bluetooth/repositories/ble_connection_repository.dart';
import '../core/app_logger.dart';
import '../kline/kline_codec.dart';
import '../kline/kline_records.dart';
import '../kline/kline_service.dart';
import '../kline/parameter_validation.dart';
import '../models/calibration_data.dart';
import 'ble_scan_screen.dart';
import 'calibration/tabs/calibration_params_tab.dart';
import 'calibration/tabs/dashboard_tab.dart';
import 'calibration/tabs/diagnostics_tab.dart';
import 'calibration/tabs/reports_tab.dart';
import 'calibration/tabs/service_settings_tab.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  static const _settingsPrefsKey = 'service_settings';

  int _tabIndex = 0;
  bool _isPinAuthenticated = false;
  BleDeviceResult? _connectedDevice;
  BleConnectionRepository? _btRepo;
  KLineService? _klineService;

  late final List<CalParam> _params;
  late final List<DtcCode> _dtcCodes;
  late final List<ComponentTest> _tests;
  late final List<RecentReport> _reports;
  late ServiceSettings _settings;

  String? _deviceHwNumber;
  String? _deviceHwVersion;
  String? _deviceSwVersion;
  String? _deviceSerial;

  @override
  void initState() {
    super.initState();
    _params = defaultCalParams();
    _dtcCodes = defaultDtcCodes();
    _tests = defaultTests();
    _reports = defaultReports();
    _settings = ServiceSettings();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsPrefsKey);
    if (raw == null) return;
    final loaded = ServiceSettings.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    if (!mounted) return;
    setState(() => _settings = loaded);
    AppLogger.instance.setTestMode(_settings.testModeEnabled);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsPrefsKey, jsonEncode(_settings.toMap()));
  }

  @override
  void dispose() {
    AppLogger.instance.cancelBridges();
    _klineService?.dispose();
    _btRepo?.dispose();
    super.dispose();
  }

  void _updateParam(String id, String value) {
    setState(() {
      final idx = _params.indexWhere((p) => p.id == id);
      if (idx != -1) _params[idx].value = value;
    });
  }

  void _onDtcsRead(List<DtcCode> codes) {
    setState(() {
      _dtcCodes
        ..clear()
        ..addAll(codes);
    });
  }

  Future<bool> _writeCalParam(String id, String value) async {
    if (_klineService == null) return false;
    final param = _params.firstWhere((p) => p.id == id);
    final normalized = ParameterValidator.validate(param, value);
    try {
      switch (id) {
        case 'utc_offset':
          await _klineService!.writeUtcOffset(_parseUtcOffsetMinutes(normalized));
        case 'datetime':
          await _klineService!.writeDateTime(
            DateTime.parse(normalized),
            _currentUtcOffsetCounter(),
            _currentUtcOffsetCounter(),
          );
        case 'prewarning_card1':
        case 'prewarning_tacho':
        case 'prewarning_cal':
          await _writePrewarning(id, normalized);
        case 'download_period_vu':
        case 'download_period_card':
          await _writeDownloadPeriod(id, normalized);
        default:
          final int recordId;
          final List<int> bytes;
          switch (id) {
            case 'vrn':
              recordId = KLineRecords.vrn;
              bytes = KLineCodec.encodeVrn(normalized);
            case 'vin':
              recordId = KLineRecords.vin;
              bytes = KLineCodec.encodeVin(normalized);
            case 'member_state':
              recordId = KLineRecords.memberState;
              bytes = KLineCodec.encodeMemberState(normalized);
            case 'reg_date':
              recordId = KLineRecords.vrd;
              bytes = KLineCodec.encodeVehicleRegDate(DateTime.parse(normalized));
            case 'tyre_size':
              recordId = KLineRecords.tyreSize;
              bytes = KLineCodec.encodeTyreSize(normalized);
            case 'tyre_circ':
              recordId = KLineRecords.tyreCircumference;
              bytes = KLineCodec.encodeTyreCircumference(int.parse(normalized));
            case 'k_constant':
              recordId = KLineRecords.kConstant;
              bytes = KLineCodec.encodeKConstant(int.parse(normalized));
            case 'w_constant':
              recordId = KLineRecords.wConstant;
              bytes = KLineCodec.encodeWConstant(int.parse(normalized));
            case 'pproos':
              recordId = KLineRecords.pproos;
              bytes = KLineCodec.encodePproos(int.parse(normalized));
            case 'teeth_count':
              recordId = KLineRecords.teethCount;
              bytes = KLineCodec.encodeTeethCount(int.parse(normalized));
            case 'speed_limit':
              recordId = KLineRecords.speedLimit;
              bytes = KLineCodec.encodeSpeedLimit(int.parse(normalized));
            case 'odometer':
              recordId = KLineRecords.odometer;
              bytes = KLineCodec.encodeOdometer(int.parse(normalized));
            case 'next_cal_date':
              recordId = KLineRecords.nextCalDate;
              bytes = KLineCodec.encodeNextCalDate(DateTime.parse(normalized));
            case 'ecu_install_date':
              recordId = KLineRecords.ecuInstallDate;
              bytes = KLineCodec.encodeEcuInstallDate(DateTime.parse(normalized));
            case 'trip_distance':
              recordId = KLineRecords.tripDistance;
              bytes = KLineCodec.encodeTripDistance(int.parse(normalized));
            case 'heartbeat':
              recordId = KLineRecords.resetHeartbeat;
              bytes = KLineCodec.encodeHeartbeat(normalized == 'ENABLED');
            case 'tco1_priority':
              recordId = KLineRecords.tco1Priority;
              bytes = KLineCodec.encodeTco1Priority(int.parse(normalized));
            case 'tco1_rate':
              recordId = KLineRecords.tco1RepRate;
              bytes = KLineCodec.encodeTco1RepRate(normalized == '50 ms');
            default:
              return false;
          }
          await _klineService!.writeParameter(recordId, bytes);
      }
      setState(() {
        final idx = _params.indexWhere((p) => p.id == id);
        if (idx != -1) _params[idx].value = normalized;
      });
      return true;
    } catch (e) {
      AppLogger.instance.log(
        'Write error [$id]: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
      return false;
    }
  }

  // Toplam dakika cinsindeki UTC farkını "+03:00" / "-05:00" biçimine çevirir.
  String _formatUtcOffsetMinutes(int totalMinutes) {
    final sign = totalMinutes < 0 ? '-' : '+';
    final abs = totalMinutes.abs();
    final hours = (abs ~/ 60).toString().padLeft(2, '0');
    final minutes = (abs % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  // "+03:00" / "-05:00" biçimindeki UTC farkını toplam dakikaya çevirir.
  int _parseUtcOffsetMinutes(String offset) {
    final sign = offset.startsWith('-') ? -1 : 1;
    final parts = offset.replaceFirst(RegExp(r'^[+-]'), '').split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return sign * (hours * 60 + minutes);
  }

  // Mevcut 'utc_offset' parametresinden datetime yazarken kullanılacak counter'ı türetir.
  int _currentUtcOffsetCounter() {
    final raw = _params.firstWhere((p) => p.id == 'utc_offset').value ?? '+00:00';
    return KLineCodec.utcOffsetCounter(_parseUtcOffsetMinutes(raw));
  }

  int _paramIntValue(String id) =>
      int.tryParse(_params.firstWhere((p) => p.id == id).value ?? '') ?? 0;

  Future<void> _writePrewarning(String changedId, String normalized) async {
    int valueOf(String id) => id == changedId ? int.parse(normalized) : _paramIntValue(id);
    await _klineService!.writePrewarningTimes(
      valueOf('prewarning_card1'),
      valueOf('prewarning_tacho'),
      valueOf('prewarning_cal'),
    );
  }

  Future<void> _writeDownloadPeriod(String changedId, String normalized) async {
    int valueOf(String id) => id == changedId ? int.parse(normalized) : _paramIntValue(id);
    await _klineService!.writeDownloadPeriods(
      valueOf('download_period_vu'),
      valueOf('download_period_card'),
    );
  }

  static const _tabLabels = ['Ana Sayfa', 'Kalibrasyon', 'Tanılama', 'Raporlar'];

  void _setTabIndex(int newIndex) {
    AppLogger.instance.log(
      'Tab: ${_tabLabels[_tabIndex]} → ${_tabLabels[newIndex]}',
      level: LogLevel.info,
      category: LogCategory.navigation,
    );
    setState(() => _tabIndex = newIndex);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: CalColors.background,
          appBar: AppBar(
            backgroundColor: CalColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Ayarlar',
              style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: CalColors.outlineVariant),
            ),
          ),
          body: ServiceSettingsTab(
            settings: _settings,
            onSettingsChanged: () {
              setState(() {});
              _saveSettings();
            },
            deviceModel: _deviceHwNumber,
            firmwareVersion: _deviceSwVersion,
            serialNumber: _deviceSerial,
            hwVersion: _deviceHwVersion,
            klineService: _klineService,
          ),
        ),
      ),
    );
  }

  void _clearDtcs() => setState(() => _dtcCodes.clear());

  void _openBleScan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BleScanScreen(
          onDeviceConnected: (device, repo) {
            final service = KLineService(repo);
            setState(() {
              _connectedDevice = device;
              _btRepo = repo;
              _klineService = service;
              _isPinAuthenticated = false;
            });
            AppLogger.instance.log(
              'Device connected: ${device.displayName}',
              level: LogLevel.success,
              category: LogCategory.bluetooth,
            );
            AppLogger.instance.cancelBridges();
            AppLogger.instance.bridgeStream(repo.logs);
            _loadDeviceData(service);
          },
        ),
      ),
    );
  }

  Future<bool> _loadDeviceData(KLineService service) async {
    AppLogger.instance.log(
      'Reading calibration data...',
      level: LogLevel.info,
      category: LogCategory.calibration,
    );
    try {
      final snapshot = await service.readAllCalibrationData();
      if (!mounted) return false;
      setState(() => _applySnapshot(snapshot));
      AppLogger.instance.log(
        'Calibration data loaded',
        level: LogLevel.success,
        category: LogCategory.calibration,
      );
      return true;
    } catch (e) {
      AppLogger.instance.log(
        'Data read error: $e',
        level: LogLevel.error,
        category: LogCategory.calibration,
      );
      return false;
    }
  }

  void _applySnapshot(CalibrationSnapshot snap) {
    void set(String id, String? val) {
      if (val == null) return;
      final idx = _params.indexWhere((p) => p.id == id);
      if (idx != -1) _params[idx].value = val;
    }

    set('vin',          snap.vin);
    set('vrn',          snap.vrn);
    set('member_state', snap.memberState);
    set('odometer',     snap.odometer?.toString());
    set('k_constant',   snap.kConstant?.toString());
    set('w_constant',   snap.wConstant?.toString());
    set('tyre_circ',    snap.tyreCircumference?.toString());
    set('tyre_size',    snap.tyreSize);
    set('speed_limit',  snap.speedLimit?.toString());
    set('pproos',       snap.pproos?.toString());
    set('teeth_count',  snap.teethCount?.toString());
    set('trip_distance', snap.tripDistance?.toString());
    set('heartbeat',    snap.heartbeatEnabled == null ? null : (snap.heartbeatEnabled! ? 'ENABLED' : 'DISABLED'));
    set('tco1_priority', snap.tco1Priority?.toString());
    set('tco1_rate',    snap.tco1Rate50ms == null ? null : (snap.tco1Rate50ms! ? '50 ms' : '20 ms'));
    set('prewarning_card1', snap.prewarningCard1Days?.toString());
    set('prewarning_tacho', snap.prewarningTachoDays?.toString());
    set('prewarning_cal',   snap.prewarningCalDays?.toString());
    set('download_period_vu',   snap.downloadPeriodVuDays?.toString());
    set('download_period_card', snap.downloadPeriodCardDays?.toString());
    if (snap.utcOffsetMinutes != null) {
      set('utc_offset', _formatUtcOffsetMinutes(snap.utcOffsetMinutes!));
    }
    if (snap.regDate != null) {
      set('reg_date', snap.regDate!.toIso8601String().substring(0, 10));
    }
    if (snap.ecuInstallDate != null) {
      set('ecu_install_date', snap.ecuInstallDate!.toIso8601String().substring(0, 10));
    }
    if (snap.nextCalDate != null) {
      set('next_cal_date', snap.nextCalDate!.toIso8601String().substring(0, 10));
    }
    if (snap.currentDateTime != null) {
      set('datetime', snap.currentDateTime!.toIso8601String());
    }

    _deviceHwNumber = snap.hwNumber ?? _deviceHwNumber;
    _deviceHwVersion = snap.hwVersionNumber ?? _deviceHwVersion;
    _deviceSwVersion = snap.swVersionNumber ?? _deviceSwVersion;
    _deviceSerial = snap.serialNumber ?? _deviceSerial;
  }

  void _disconnectDevice() {
    _klineService?.dispose();
    _btRepo?.dispose();
    setState(() {
      _connectedDevice = null;
      _btRepo = null;
      _klineService = null;
      _isPinAuthenticated = false;
      _deviceHwNumber = null;
      _deviceHwVersion = null;
      _deviceSwVersion = null;
      _deviceSerial = null;
      for (final p in _params) {
        p.value = null;
      }
      _dtcCodes.clear();
      for (final t in _tests) {
        t.status = TestStatus.idle;
        t.progress = 0;
      }
    });
    AppLogger.instance.log(
      'Device disconnected',
      level: LogLevel.info,
      category: LogCategory.bluetooth,
    );
  }

  void _updateTest(String id, TestStatus status, int progress) {
    setState(() {
      final idx = _tests.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _tests[idx].status = status;
        _tests[idx].progress = progress;
      }
    });
  }

  Widget _tab(int index, Widget child) {
    final active = _tabIndex == index;
    return AnimatedOpacity(
      opacity: active ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: IgnorePointer(ignoring: !active, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: CalColors.background,
        appBar: _buildAppBar(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _tab(0, DashboardTab(
              isPinAuthenticated: _isPinAuthenticated,
              onAuthChanged: (v) => setState(() => _isPinAuthenticated = v),
              onNavigate: _setTabIndex,
              reports: _reports,
              params: _params,
              dtcCodes: _dtcCodes,
              onWConstantWritten: (v) => _updateParam('w_constant', v),
              connectedDevice: _connectedDevice,
              onConnectDevice: () => _openBleScan(context),
              onDisconnectDevice: _disconnectDevice,
              klineService: _klineService,
            )),
            _tab(1, CalibrationParamsTab(
              params: _params,
              onParamChanged: _updateParam,
              isDeviceConnected: _connectedDevice != null,
              isSimulated: _connectedDevice?.isSimulated ?? false,
              onWriteParam: _klineService != null ? _writeCalParam : null,
              onRefresh: _klineService != null ? () => _loadDeviceData(_klineService!) : null,
            )),
            _tab(2, DiagnosticsTab(
              dtcCodes: _dtcCodes,
              onClearDtcs: _clearDtcs,
              onDtcsRead: _onDtcsRead,
              tests: _tests,
              onTestUpdate: _updateTest,
              isDeviceConnected: _connectedDevice != null,
              klineService: _klineService,
            )),
            _tab(3, ReportsTab(
              params: _params,
              tests: _tests,
              workshopName: _settings.workshopName,
            )),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFEEF0F8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Smart',
              style: TextStyle(color: Color(0xFF99D700)),
            ),
            TextSpan(
              text: ' Tracker',
              style: TextStyle(color: Color(0xFF919191)),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: 'ITCHighlander',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              color: Color(0x55000000),
              offset: Offset(0.5, 0.5),
              blurRadius: 0,
            ),
          ],
        ),
      ),
      actions: [
        if (_tabIndex == 0)
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: CalColors.onSurfaceVariant),
            onPressed: _openSettings,
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: CalColors.outlineVariant),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_outlined, Icons.home, 'Ana Sayfa'),
      (Icons.settings_input_component_outlined, Icons.settings_input_component, 'Kalibrasyon'),
      (Icons.build_circle_outlined, Icons.build_circle, 'Tanılama'),
      (Icons.assessment_outlined, Icons.assessment, 'Raporlar'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: CalColors.surface,
        border: Border(top: BorderSide(color: CalColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = _tabIndex == i;
              final (outlinedIcon, filledIcon, label) = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setTabIndex(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? filledIcon : outlinedIcon,
                          color: selected ? CalColors.primary : CalColors.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected ? CalColors.primary : CalColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
