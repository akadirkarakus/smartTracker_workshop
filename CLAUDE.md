# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter run                          # Run on connected device/emulator
flutter run --dart-define=BT_TRANSPORT=ble   # Force BLE transport
flutter run --dart-define=BT_TRANSPORT=classic  # Force Classic Bluetooth (default)
flutter analyze                      # Static analysis / lint
flutter test                         # Run all tests
flutter test test/widget_test.dart   # Run a single test file
flutter build apk                    # Android release build
flutter build ios                    # iOS release build
```

## Architecture

This is a Flutter tachograph (digital speed recorder) app targeting iOS and Android, written in Turkish. Entry point: `lib/main.dart` → `RoleSelectionScreen`.

### Role-based navigation

Two roles are selected at launch:
- **Şoför (Driver)** → `MonitorScreen` — real-time dashboard fed by `TachographSimulator`
- **Servis (Service technician)** → `CalibrationScreen` — multi-tab calibration tool with PIN auth

### Layer structure

```
lib/
├── main.dart
├── models/
│   ├── tachograph_data.dart   # TachographData + DriverActivity enum
│   └── calibration_data.dart  # CalParam, DtcCode, ComponentTest, RecentReport, ServiceSettings, OptionalSettings, CalColors
├── services/
│   └── tachograph_simulator.dart  # Stream<TachographData> at 1 s tick, enforces AB 561/2006 limits
├── screens/
│   ├── monitor_screen.dart        # Driver dashboard (uses TachographSimulator)
│   ├── calibration_screen.dart    # Service tool (IndexedStack of 5 tabs)
│   ├── ble_scan_screen.dart       # Transport selector + scan + device list
│   ├── ble_terminal_screen.dart   # Raw BT terminal after connecting
│   ├── test_log_screen.dart       # In-app log viewer (AppLogger, only visible when testModeEnabled)
│   └── calibration/
│       ├── tabs/                  # dashboard_tab, calibration_params_tab, diagnostics_tab, reports_tab, service_settings_tab
│       ├── edit_parameter_screen.dart
│       ├── pin_entry_screen.dart
│       ├── w_constant_measurement_screen.dart
│       ├── motion_sensor_pairing_screen.dart
│       └── optional_settings_screen.dart
├── bluetooth/
│   ├── config/bluetooth_config.dart   # Factory functions + BtTransport enum; transport set at compile time via BT_TRANSPORT env var
│   ├── repositories/                  # BleScannerRepository, BleConnectionRepository (abstract interfaces)
│   ├── services/                      # FlutterBluePlus (BLE), ClassicBluetooth, SimulatedConnection implementations
│   └── models/                        # BleDeviceResult, BleGattService, LogEntry
├── kline/
│   ├── kline_service.dart   # KLineService — implements Flows 1–21 from CalibrationMessages.md
│   ├── kline_frame.dart     # KLineFrame (builder), KLineResponse, KLineFrameBuffer (chunked SPP parser)
│   ├── kline_codec.dart     # KLineCodec — encode/decode for every parameter type
│   └── kline_records.dart   # Constants: KLineRecords (record IDs), KLineSession, KLineSid,
│                            #            KLineRoutineIds, KLineRoutineSelect, KLineTiming, KLineNrc
└── core/
    ├── exceptions/          # Typed BleException hierarchy (BleAdapterException, BlePermissionException, etc.)
    └── app_logger.dart      # AppLogger singleton — only logs when testModeEnabled = true; capacity 500 entries
```

### K-LINE protocol layer

`KLineService` takes a `BleConnectionRepository` and communicates through two virtual channel names regardless of transport:
- `notifyStream('SPP_DATA')` — incoming bytes from the tachograph
- `writeCharacteristic('SPP_DATA', frame)` — outgoing bytes to the tachograph

The frame format is KWP2000 / ISO 14230 (`[FMT][TADDR=0xEE][SADDR=0xF0][LEN][SID][DATA...][CS]`). Full protocol reference is in `CalibrationMessages.md`; known integration risks are in `PossibleProblems.md`.

**Write commit rule** — every write flow (Flows 3–7) sends a second `StartCommunication` after `WriteDataByIdentifier`. This second StartComm acts as the trigger that causes the tachograph to persist the value to non-volatile memory. Omitting it leaves the value in volatile RAM only.

### Key design decisions

- **No state management library** — screens use `setState` + `StreamSubscription` directly.
- **Bluetooth transport** is selected at compile time via `--dart-define=BT_TRANSPORT=classic|ble`. At runtime users can override via the transport selector in `BleScanScreen`. A simulated transport (`BtTransport.simulated`) is available for testing without hardware.
- **iOS platform constraint** — Classic Bluetooth SPP requires the `ExternalAccessory` framework and MFi certification. On iOS, K-LINE communication is only possible over BLE (the adapter must bridge BLE↔K-LINE). This is not a code limitation — it is an iOS/hardware requirement.
- **TachographSimulator** enforces EU regulation AB 561/2006 limits: max 4 h 30 min continuous driving, 90 km/h speed limit for violation counting.
- **CalibrationScreen** uses `IndexedStack` (not `Navigator`) for its 5 tabs, with a custom back-navigation that returns to the previous tab index rather than popping the route.
- **Two colour palettes**: `MonitorScreen` uses inline `const Color(...)` constants defined at file scope; `CalibrationScreen` uses the `CalColors` class from `calibration_data.dart`.
- **PIN authentication** gates calibration writes inside `CalibrationScreen` via `_isPinAuthenticated`.
- **AppLogger** is a global singleton; it only records entries when `testModeEnabled` is `true`, so it has zero overhead in normal use. `TestLogScreen` subscribes to `AppLogger.instance.stream` to display live entries.
