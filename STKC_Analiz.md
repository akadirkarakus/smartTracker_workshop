# STKC — SmartTrack Tachograph Calibration Device: Complete Technical Reference

> **Audience:** Developers working on the `takograpp_d1` Flutter app.  
> **Source:** Reverse-engineered from `/Users/akadir/Desktop/SmartTrack/STKC` firmware source code.  
> **Purpose:** This document captures every protocol detail, data model, communication flow, and timing constraint needed to implement a compatible mobile calibration tool.

---

## Table of Contents

1. [Project Summary](#1-project-summary)
2. [Directory Structure](#2-directory-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [K-LINE Physical Layer & Tachograph Wakeup](#4-k-line-physical-layer--tachograph-wakeup)
5. [Frame Format — ISO 14230 / KWP2000](#5-frame-format--iso-14230--kwp2000)
6. [Diagnostic Services (SIDs)](#6-diagnostic-services-sids)
7. [Data Identifier (DID) Reference Table](#7-data-identifier-did-reference-table)
8. [Communication Flows](#8-communication-flows)
9. [Timing Constraints](#9-timing-constraints)
10. [Data Models & Variable Catalogue](#10-data-models--variable-catalogue)
11. [Security / PIN Flow](#11-security--pin-flow)
12. [Diagnostic Test Routines](#12-diagnostic-test-routines)
13. [Error / NRC Code Table](#13-error--nrc-code-table)
14. [Flash Storage Layout](#14-flash-storage-layout)
15. [Relevance to Flutter Project](#15-relevance-to-flutter-project)

---

## 1. Project Summary

**STKC** (SmartTrack Tachograph Calibration) is an **embedded firmware** for a dedicated hardware calibration device that communicates with digital tachographs installed in commercial vehicles.

| Attribute | Value |
|-----------|-------|
| **Type** | Embedded C firmware, real-time |
| **MCU** | TI Tiva **TM4C129EKCPDT** (ARM Cortex-M4F @ 120 MHz) |
| **RTOS** | TI SYS/BIOS 6.46 (TI-RTOS) via XDCtools |
| **Build system** | TI Code Composer Studio (CCS) + Makefile |
| **Compiler** | TI ARM Compiler v16.9.0 LTS, Thumb-2, -O2 |
| **Display** | 320×240 monochrome TFT LCD (EPI0 parallel bus) |
| **Keypad** | 5×4 matrix keypad |
| **Source files** | 109 C/H files, ~46 700 lines of code |
| **Languages** | Turkish, English, Spanish, Ukrainian (runtime selectable) |

### Supported Tachograph Models

| Model | Variant | Optional Settings Count |
|-------|---------|------------------------|
| Aselsan STC8250 | Primary | 19 |
| Aselsan STC8255 | Extended | 30 |
| VDO DTCO1381 | — | — |
| Stoneridge | — | — |
| EFAS3 | — | — |

### Core Capabilities

- Read/write calibration parameters via ISO 14230 (KWP2000) K-LINE protocol
- PIN-based security access (seed-key challenge-response)
- Hardware test suite (display, clock, speed, buzzer, smart card readers, keypad)
- W-Constant auto-measurement using onboard photo sensor
- Motion sensor pairing
- Diagnostic Trouble Code (DTC) read/clear
- Optional/advanced settings (CAN, backlight, speed profiles, IMS source)
- Calibration report generation
- Workshop name & serial number stored in on-chip flash

---

## 2. Directory Structure

```
STKC/
├── main.c                          # Entry point → hardware init → BIOS_start()
├── main.cfg                        # TI-RTOS task/semaphore/clock configuration (XDC)
├── Generic.h                       # All #defines: menu IDs, key codes, session types, NRCs
├── Global_Defs.c                   # Global variable definitions
├── Texts.h                         # Multi-language UI strings (~50 KB)
├── Callbacks.c / Callbacks.h       # GPIO interrupt service routines (EXIT key, photo sensor)
├── tm4c129ekcpdt.cmd               # Linker script (memory map for TM4C129)
│
├── Board/                          # Hardware Abstraction Layer (HAL)
│   ├── Board.h                     # TI-RTOS board pin definitions
│   ├── EK_TM4C129EXL.c/h           # Reference board config
│   ├── Terminus_KOI8_RU_STKC.c/h  # STKC custom board config
│   └── Pinmux.c/h                  # GPIO multiplexer setup
│
├── Interfaces/                     # Peripheral drivers
│   ├── Kline/                      # K-LINE protocol core (28 files)
│   │   ├── Kline_Port.c/h          # UART0 baudrate, open/close, read/write
│   │   ├── Requests.c/h            # High-level command sequences (all Flows)
│   │   ├── Conversions.c/h         # Unit conversion & BCD/ASCII encoding
│   │   ├── Cal1_Functions.c/h      # CAL1 parameter read/write helpers
│   │   ├── Cal2_Functions.c/h      # CAL2 date/time/nation helpers
│   │   ├── Cal3_Functions.c/h      # CAL3 extended parameter helpers
│   │   ├── Init_Functions.c/h      # Session initialization helpers
│   │   ├── Execute_Cal[1-3]_Functions.c/h  # Multi-step calibration workflows
│   │   ├── Check_Functions.c/h     # Post-write validation helpers
│   │   ├── Write_Functions.c/h     # Frame serialization helpers
│   │   └── Display_Functions.c/h  # Format data for TFT display
│   ├── TFT/                        # TFT LCD driver
│   ├── Flash_SPI/                  # SPI flash (serial number, workshop name, settings)
│   ├── Motion_Sensor/              # Pulse-count input for W-constant measurement
│   ├── PhotoSensor_FlexiSwitch/    # Optical wheel-speed sensor
│   ├── Buzzer/                     # Audio feedback
│   ├── Dig_Pot/                    # Digital potentiometer (adjustable resistor)
│   ├── Power_Input_Switch/         # Power management
│   ├── COM/                        # Generic serial (UART2 debug/secondary)
│   └── Calio/                      # CAN/LIN adapter interface
│
├── Services/                       # KWP2000 / ISO 14230 service implementations
│   ├── Communication_Services/     # Start_Communication, Stop_Communication, Tester_Present
│   ├── Management_Services/        # Security_Access, Start_Diagnostic_Session
│   ├── Data_Transmission_Services/ # Read_Data_By_Identifier, Write_Data_By_Identifier
│   ├── Control_Test_Pulses/        # Input_Output_Control_By_Identifier
│   └── DTC/                        # DTC_Access (read/clear fault codes)
│
├── Screen_Functions/               # UI module per main menu item (12 modules)
│   ├── Calib1/                     # CAL1 screen + K-LINE read/write (VRN, VIN, odometer…)
│   ├── Calib2/                     # CAL2 screen (date/time, UTC, nation)
│   ├── DTC/                        # DTC viewer screen
│   ├── Info/                       # Firmware info & software upgrade
│   ├── MS/                         # Motion sensor pairing screen
│   ├── Option/                     # Optional settings screen (CAN, backlight, etc.)
│   ├── Pin/                        # PIN entry screen
│   ├── Report/                     # Calibration report screen
│   ├── Settings/                   # Device settings (backlight, buzzer, language)
│   ├── Test/                       # Hardware test suite screens
│   ├── VehicleModels/              # (Conditional) vehicle model database
│   └── WMeasure/                   # W-Constant auto-measurement screen
│
├── Tasks/                          # TI-RTOS task function declarations
│   ├── Tasks.c/h                   # Task entry points (one per menu screen)
│   └── General/Calendar_Check.c/h # Date validity checker
│
└── Documentation/
    ├── CalibrationMessages.md      # Complete K-LINE protocol reference (Flows 1–21)
    ├── CalibrationDeviceMenu.md    # UI menu structure & navigation
    └── 76IE-8250-0004_STKC8250_UserManual_RevB.pdf
```

---

## 3. Architecture Overview

### RTOS Task Model

Each main menu screen runs as a **separate TI-RTOS task** that blocks on a semaphore. A keypad scanner task detects key presses, sets a global `Key_Pressed` variable, and posts the appropriate semaphore to wake the target task.

```
Boot → main.c hardware init → BIOS_start()
  └─ Spawns ~20 tasks (one per menu + KeypadScanFxn + InspectionFxn + SPITaskFxn + …)
       All tasks start BLOCKED on their semaphore

KeypadScanFxn (10 ms tick)
  └─ Detects keypress
  └─ Sets Key_Pressed = KEY_xxx
  └─ Semaphore_post(semaphore_for_current_menu)
  └─ Target menu task unblocks → executes action → re-blocks
```

### Semaphore Map (abbreviated)

| Semaphore | Task woken |
|-----------|-----------|
| `semaphore1_MAIN_MENU` | `MainMenuFxn` |
| `semaphore2_CAL_GEN1_MENU` | `CalGen1MenuFxn` |
| `semaphore3_CAL_GEN2_MENU` | `CalGen2MenuFxn` |
| `semaphore4_OPTIONAL_MENU` | `OptionalMenuFxn` |
| `semaphore5_WMEASURE_MENU` | `WMeasureMenuFxn` |
| `semaphore6_TEST1_MENU` | `Test1MenuFxn` |
| `semaphore10_TrigKLINETX` | K-LINE transmit trigger |
| `semaphore11_TrigKLINERX` | K-LINE receive trigger |
| `semaphore17_PIN_Entry` | `PINEntryFxn` |
| `semaphore22_T2CCP0_…` | W-Constant timer capture |

### Layer Dependency

```
Screen_Functions/   ← user input & display
        ↓
Interfaces/Kline/Requests.c  ← high-level K-LINE flows
        ↓
Services/           ← KWP2000 frame builders (StartComm, RDBI, WDBI, …)
        ↓
Interfaces/Kline/Kline_Port.c  ← UART0 open/close, baudrate, read/write
        ↓
TI DriverLib UART   ← hardware registers
```

---

## 4. K-LINE Physical Layer & Tachograph Wakeup

### Hardware Assignment

| UART | Purpose | Baud rates used |
|------|---------|-----------------|
| UART0 | K-LINE bus (primary) | 360 baud (wakeup) → 10 400 baud (normal) |
| UART2 | Secondary / debug | 9 600 baud |

### Wakeup Sequence

The ISO 14230 slow-init wakeup is a **single null byte (0x00)** transmitted at 360 baud, followed by a baudrate change to 10 400 baud.

```c
// From Screen_Functions/Calib1/Kline_Functions.c
void Generate_KLINE_Wakeup_Pattern()
{
    Open_UART0();
    Open_UART2();
    Change_KLINE_Baudrate(360);   // Set to slow init speed
    output_KLINE = 0x00;
    UART_write(UART0_Handle, &output_KLINE, 1);
    // Caller switches to 10400 baud and waits 23 ms before first frame
}
```

**Full Physical Init Sequence:**
1. `Generate_KLINE_Wakeup_Pattern()` — send 0x00 at **360 baud**
2. `Change_KLINE_Baudrate(10400)` — switch to **10 400 baud**
3. `Task_sleep(23)` — wait **23 ms** for tachograph to become ready
4. Send first KWP2000 frame (StartCommunication)

### UART Configuration Parameters

| Parameter | Value |
|-----------|-------|
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |
| Flow control | None |
| Echo | Disabled |
| Read timeout | 250 ms (P2max) |
| Write timeout | 5 ms (P4min) |

---

## 5. Frame Format — ISO 14230 / KWP2000

### Request Frame

```
Byte:  0     1       2       3    4    5…N   N+1
      [FMT] [TADDR] [SADDR] [LEN][SID][DATA][CS]
       0x80  0xEE    0xF0    n    sid  ...   sum

FMT   = 0x80 (standard) or 0x81 (StartCommunication only — 1-byte length in header)
TADDR = 0xEE  — tachograph (ECU target address)
SADDR = 0xF0  — calibration device (source address)
LEN   = number of DATA bytes (not counting FMT/TADDR/SADDR/LEN/CS)
SID   = service identifier byte
DATA  = service-specific payload
CS    = (sum of all preceding bytes) mod 256
```

### Response Frame

```
Byte:  0     1       2       3    4         5…N   N+1
      [FMT] [SADDR] [TADDR] [LEN][SID+0x40][DATA][CS]
       0x80  0xF0    0xEE    n    sid|0x40  ...   sum

SADDR and TADDR are swapped compared to the request.
Positive response SID = request SID | 0x40
Negative response: SID = 0x7F, DATA[0] = original SID, DATA[1] = NRC
```

### Checksum Calculation

```c
unsigned short cs = 0;
for (int i = 0; i < frame_len - 1; i++) cs += frame[i];
frame[frame_len - 1] = cs & 0xFF;
```

### StartCommunication Frame (special case)

StartCommunication uses `FMT=0x81` (length encoded in FMT low nibble) rather than 0x80:

```
TX: 81 EE F0 81 E0 <CS>    (5 bytes total)
```

---

## 6. Diagnostic Services (SIDs)

### Service Reference Table

| SID (hex) | Service Name | Direction | Session Required |
|-----------|-------------|-----------|-----------------|
| `0xE0` | StartCommunication | Request | any |
| `0x82` | StopCommunication | Request | any |
| `0x10` | StartDiagnosticSession | Request | any |
| `0x22` | ReadDataByIdentifier (RDBI) | Request | Standard (0x81) |
| `0x2E` | WriteDataByIdentifier (WDBI) | Request | Programming (0x85) |
| `0x27` | SecurityAccess | Request | Standard (0x81) |
| `0x31` | RoutineControl | Request | Adjustment (0x87) |
| `0x3E` | TesterPresent | Request | any (keep-alive) |
| `0x7F` | NegativeResponse | Response | — |

### Positive Response SIDs (response = request | 0x40)

| Request SID | Response SID | Meaning |
|-------------|-------------|---------|
| `0xE0` | `0xC0` | StartCommunication OK |
| `0x82` | `0xC2` | StopCommunication OK |
| `0x10` | `0x50` | StartDiagnosticSession OK |
| `0x22` | `0x62` | RDBI data follows |
| `0x2E` | `0x6E` | WDBI accepted |
| `0x27` | `0x67` | SecurityAccess seed/key OK |
| `0x31` | `0x71` | RoutineControl result |

### Diagnostic Session Types (SID 0x10 sub-functions)

| Sub-function | Name | Usage |
|-------------|------|-------|
| `0x81` | StandardDiagnosticSession | Default — read-only operations |
| `0x85` | ECUProgrammingSession | Required for all WDBI writes |
| `0x87` | ECUAdjustmentSession | Required for test routines (0x31) |

### StartCommunication Request Format

```
81 EE F0 81 E0 CS
```

### StartDiagnosticSession Request Format

```
80 EE F0 02 10 <session_type> CS
Example (Programming): 80 EE F0 02 10 85 <CS>
```

### ReadDataByIdentifier Request Format

```
80 EE F0 03 22 <DID_HIGH> <DID_LOW> CS
Example (VIN 0xF190): 80 EE F0 03 22 F1 90 <CS>
Response:             80 F0 EE <LEN> 62 F1 90 <data bytes> <CS>
```

### WriteDataByIdentifier Request Format

```
80 EE F0 <LEN> 2E <DID_HIGH> <DID_LOW> <data bytes> CS
LEN = 3 + len(data)
Example (W-Constant 0xF91D, value=0x1234):
  80 EE F0 05 2E F9 1D 12 34 <CS>
Response: 80 F0 EE 03 6E F9 1D <CS>
```

### SecurityAccess Request Format

```
Request Seed:  80 EE F0 03 27 7D 04 <CS>
Response:      80 F0 EE <LEN> 67 7D <seed bytes> <CS>

Send Key:      80 EE F0 <LEN> 27 7E <PIN bytes> <CS>
Response (OK): 80 F0 EE 02 67 7E <CS>
Response (NG): 80 F0 EE 03 7F 27 <NRC> <CS>
```

---

## 7. Data Identifier (DID) Reference Table

### CAL1 Parameters

| DID | Name | Size | Type / Unit | R/W |
|-----|------|------|-------------|-----|
| `0xF190` | VehicleIdentificationNumber (VIN) | 17 bytes | ASCII | R/W |
| `0xF97E` | VehicleRegistrationNumber (VRN) | 14 bytes | ASCII | R/W |
| `0xF97D` | VehicleRegistrationNation | 3 bytes | ISO 3166 code (e.g. "TUR") | R/W |
| `0xF912` | HighResOdometer | 4 bytes | km, unsigned int | R/W |
| `0xF92C` | SpeedAuthorized (speed limit) | 2 bytes | km/h | R/W |
| `0xF918` | K-Constant (recording equipment) | 2 bytes | imp/km | R/W |
| `0xF91D` | W-Vehicle Characteristic Constant | 2 bytes | imp/km | R/W |
| `0xF91C` | L-TyreCircumference | 2 bytes | mm/8 | R/W |
| `0xF921` | TyreSize | 15 bytes | ASCII string | R/W |
| `0xF922` | NextCalibrationDate | 3 bytes | BCD (DD MM YY) | R/W |

### CAL2 Parameters

| DID | Name | Size | Type / Unit | R/W |
|-----|------|------|-------------|-----|
| `0xF90B` | CurrentDateTime | 8 bytes | BCD (sec min hr DoW day mon yr utcMin utcHr) | R/W |
| `0xF90D` | UTC_MinuteOffset | 1 byte | minutes signed | R/W |
| `0xF90E` | UTC_HourOffset | 1 byte | hours signed (−12 … +12) | R/W |
| `0xF91A` | NumberOfTeethOnPhonicWheel | 2 bytes | unsigned | R/W |
| `0xF913` | TripDistance | 4 bytes | km | R |

### CAL3 Parameters

| DID | Name | Size | Type / Unit | R/W |
|-----|------|------|-------------|-----|
| `0xF90C` | ResetHeartBeat | 1 byte | 0=off, 1=on | R/W |
| `0xF990` | DownloadPeriod_Card | 1 byte | days (0–250) | R/W |
| `0xF991` | DownloadPeriod_VU | 1 byte | days (0–250) | R/W |
| `0xF994` | PrewarningTime_Card1Download | 1 byte | days (0–250) | R/W |
| `0xF995` | PrewarningTime_TachoDownload | 1 byte | days (0–250) | R/W |
| `0xF996` | PrewarningTime_CalibWarning | 1 byte | days (0–250) | R/W |

### Optional Settings (DID range `0xFD00`–`0xFD53`)

| DID | Name | Size | Notes |
|-----|------|------|-------|
| `0xFD00` | SpeedometerFactor | 4 bytes | 1–60 000 |
| `0xFD01` | N_Factor | 4 bytes | 2000–64 000 |
| `0xFD02`–`0xFD10` | N_Profile[0–14] | 2 bytes each | 15 engine speed profiles |
| `0xFD11`–`0xFD1F` | V_Profile[0–14] | 2 bytes each | 15 vehicle speed profiles |
| `0xFD20` | B7_Recognize | 1 byte | 0/1 |
| `0xFD21` | Military_Dimmer | 1 byte | 0/1 |
| `0xFD22` | IMS_Source | 1 byte | 0=disabled, 1=CAN_A, 2=CAN_C, 4=GPS |
| `0xFD23` | CAN_A_Baudrate | 1 byte | |
| `0xFD24` | CAN_C_Baudrate | 1 byte | |
| `0xFD25` | CAN_A_SamplingPoint | 1 byte | |
| `0xFD26` | Backlight_Option | 1 byte | 0=disable … 6=menu |
| `0xFD27` | DistanceUnit | 1 byte | 0=km, 1=miles |
| `0xFD28` | Language_Change | 1 byte | |
| … | (STC8255 extends to 0xFD53) | | |

---

## 8. Communication Flows

> **Commit-Trigger Rule (CRITICAL):** Every write flow sends a **second `StartCommunication`** immediately after the `WriteDataByIdentifier` response. This second `StartComm` is the signal that causes the tachograph to **flush the written value to non-volatile memory**. Omitting it leaves the value in volatile RAM — it will be lost on power cycle.

### Flow 1 — Security Access (PIN Authentication)

```
Physical wakeup: 0x00 @ 360 baud → 10400 baud → wait 23 ms

TX: 81 EE F0 81 E0 <CS>               StartCommunication
RX: C0 ... (or C1)

TX: 80 EE F0 02 10 81 <CS>            StartDiagnosticSession (Standard)
RX: 50 ...

TX: 80 EE F0 03 27 7D 04 <CS>         SecurityAccess — Request Seed
RX: 67 7D <seed bytes>

TX: 80 EE F0 <N+2> 27 7E <PIN[0..N]> <CS>   SecurityAccess — Send Key
RX: 67 7E                               SUCCESS
 or 7F 27 35                            FAIL (invalid key)
 or 7F 27 36                            FAIL (max attempts exceeded)

TX: 80 EE F0 01 82 E1 <CS>            StopCommunication
RX: C2 ...
```

**Notes:**
- PIN is entered by the operator as ASCII key presses on the device keypad.
- Maximum 3 attempts before `0x36 ExceededNumberOfAttempts`.
- Successful PIN authentication is required before any write operation.

---

### Flow 2 — CAL1: Read All Calibration Parameters

```
Wakeup → 10400 baud → 23 ms delay

TX: 81 EE F0 81 E0 <CS>               StartCommunication
RX: C1 ...

TX: 80 EE F0 03 22 F1 90 <CS>         RDBI VIN
RX: 62 F1 90 <17 bytes ASCII>

TX: 80 EE F0 03 22 F9 7E <CS>         RDBI VRN
RX: 62 F9 7E <14 bytes ASCII>

TX: 80 EE F0 03 22 F9 7D <CS>         RDBI VehicleRegistrationNation
RX: 62 F9 7D <3 bytes>

TX: 80 EE F0 03 22 F9 12 <CS>         RDBI Odometer
RX: 62 F9 12 <4 bytes>

TX: 80 EE F0 03 22 F9 2C <CS>         RDBI SpeedLimit
RX: 62 F9 2C <2 bytes>

TX: 80 EE F0 03 22 F9 18 <CS>         RDBI K-Constant
RX: 62 F9 18 <2 bytes>

TX: 80 EE F0 03 22 F9 1D <CS>         RDBI W-Constant
RX: 62 F9 1D <2 bytes>

TX: 80 EE F0 03 22 F9 1C <CS>         RDBI TyreCircumference
RX: 62 F9 1C <2 bytes>

TX: 80 EE F0 03 22 F9 21 <CS>         RDBI TyreSize
RX: 62 F9 21 <15 bytes ASCII>

TX: 80 EE F0 03 22 F9 22 <CS>         RDBI NextCalibrationDate
RX: 62 F9 22 <3 bytes BCD>

TX: 80 EE F0 03 22 F9 0B <CS>         RDBI CurrentDateTime
RX: 62 F9 0B <8 bytes BCD>

TX: 80 EE F0 01 82 E1 <CS>            StopCommunication
RX: C2 ...
```

All parameters are read in a single session to minimize connection time.

---

### Flow 3 — CAL1: Write a Single Parameter

```
Wakeup → 10400 baud → 23 ms delay

TX: 81 EE F0 81 E0 <CS>                           StartCommunication
RX: C1 ...

TX: 80 EE F0 02 10 85 <CS>                        StartDiagnosticSession (Programming 0x85)
RX: 50 ...

TX: 80 EE F0 <LEN> 2E <DID_H> <DID_L> <data> <CS>  WDBI — write parameter
RX: 6E <DID_H> <DID_L>

⚠️  TX: 81 EE F0 81 E0 <CS>                       StartCommunication — COMMIT TRIGGER
RX: C1 ...    (this persists value to NVM)

TX: 80 EE F0 03 22 <DID_H> <DID_L> <CS>           RDBI — read back to verify
RX: 62 <DID_H> <DID_L> <data>                     (compare with written value)

TX: 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (Standard 0x81)
RX: 50 ...

TX: 80 EE F0 01 82 E1 <CS>                        StopCommunication
RX: C2 ...
```

**Special case — W-Constant on Stoneridge:** when writing W-Constant, also write K-Constant to the same value.

---

### Flow 4 — CAL2: Write Date & Time

```
Wakeup → 10400 baud → 23 ms delay

TX: 81 EE F0 81 E0 <CS>                           StartCommunication
RX: C1 ...

TX: 80 EE F0 02 10 85 <CS>                        StartDiagnosticSession (Programming)
RX: 50 ...

TX: 80 EE F0 03 22 F9 0B <CS>                     RDBI — read current DateTime
RX: 62 F9 0B <8 bytes>

[ Calculate Δt between device time and tachograph time ]
[ If Δt > 20 minutes: re-write W-Constant as part of recalibration ]
  TX: 80 EE F0 03 22 F9 1D <CS>                   RDBI W-Constant
  TX: 80 EE F0 05 2E F9 1D <W_H> <W_L> <CS>       WDBI W-Constant (write same value back)

TX: 80 EE F0 0A 2E F9 0B <8 bytes new time> <CS>  WDBI — write new DateTime
RX: 6E F9 0B

⚠️  TX: 81 EE F0 81 E0 <CS>                       StartCommunication — COMMIT TRIGGER
RX: C1 ...

TX: 80 EE F0 03 22 F9 0B <CS>                     RDBI — verify
RX: 62 F9 0B <8 bytes>

TX: 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (Standard)
TX: 80 EE F0 01 82 E1 <CS>                        StopCommunication
```

**DateTime encoding (8 bytes BCD):**
```
Byte 0: Seconds (BCD)
Byte 1: Minutes (BCD)
Byte 2: Hours (BCD)
Byte 3: Day-of-Week (1=Mon … 7=Sun)
Byte 4: Day (BCD)
Byte 5: Month (BCD)
Byte 6: Year (BCD, 2-digit)
Byte 7: UTC offset minutes or flags
```

---

### Flow 5 — CAL2: Write UTC Offset

```
Same structure as Flow 3 but:
- Write DID 0xF90D (UTC Minute Offset, 1 byte)
- Write DID 0xF90E (UTC Hour Offset, 1 byte signed)
- COMMIT TRIGGER after each WDBI, or after both
- Verify both back
```

---

### Flow 6 — CAL3: Write Prewarning Times

```
Wakeup → Programming session (0x85)

TX: 80 EE F0 04 2E F9 94 <val> <CS>    WDBI PrewarningCard1Download (0xF994)
RX: 6E F9 94

TX: 80 EE F0 04 2E F9 95 <val> <CS>    WDBI PrewarningTachoDownload (0xF995)
RX: 6E F9 95

TX: 80 EE F0 04 2E F9 96 <val> <CS>    WDBI PrewarningCalibWarning (0xF996)
RX: 6E F9 96

⚠️  TX: 81 EE F0 81 E0 <CS>            StartCommunication — COMMIT TRIGGER (for all 3)
RX: C1 ...

[ Verify F994, F995, F996 via RDBI ]

TX (Standard session) → StopCommunication
```

---

### Flow 7 — CAL3: Write Download Periods

```
Same structure as Flow 6 but writes:
- 0xF990 (DownloadPeriod_Card)
- 0xF991 (DownloadPeriod_VU)
Followed by single COMMIT TRIGGER, then verify both.
```

---

### Flow 8 — Write Optional Settings

Optional settings occupy DIDs `0xFD00`–`0xFD53`. The write sequence is identical to Flow 3 but can batch multiple WDBI requests before the single commit trigger:

```
Programming session
→ WDBI 0xFDxx <value>
→ WDBI 0xFDyy <value>
→ … (all changed optional params)
⚠️ StartCommunication (COMMIT TRIGGER)
→ RDBI each changed DID (verify)
→ Standard session → StopCommunication
```

---

## 9. Timing Constraints

| Timing Parameter | Value | Notes |
|----------------|-------|-------|
| Wakeup baudrate | **360 baud** | Slow init per ISO 14230 |
| Normal baudrate | **10 400 baud** | K-LINE standard operational speed |
| Post-wakeup stabilization | **23 ms** | `Task_sleep(23)` before first frame |
| Inter-message delay | **60 ms** | `Task_sleep(60)` between each request |
| P2max (response timeout) | **250 ms** | UART read timeout on receive |
| P4min (inter-byte gap) | **5 ms** | UART write timeout |
| TesterPresent interval | **< 5 s** | Or session times out |

---

## 10. Data Models & Variable Catalogue

### CAL1 Variables

| Variable | C type | DID | Max size | Notes |
|----------|--------|-----|----------|-------|
| `VRN[20]` | `unsigned char[]` | `0xF97E` | 14 bytes | ASCII, null-terminated |
| `VIN[20]` | `unsigned char[]` | `0xF190` | 17 bytes | ASCII, null-terminated |
| `Odometer_Read_Hex` | `unsigned int` | `0xF912` | 4 bytes | km |
| `Speed_Limit_Read_Hex` | `unsigned char` | `0xF92C` | 1–2 bytes | km/h |
| `K_Constant_Read_Hex` | `unsigned short` | `0xF918` | 2 bytes | imp/km |
| `W_Constant_Read_Hex` | `unsigned short` | `0xF91D` | 2 bytes | imp/km |
| `TyreCircum_Read_Hex` | `unsigned short` | `0xF91C` | 2 bytes | mm/8 |
| `TyreSize[16]` | `unsigned char[]` | `0xF921` | 15 bytes | ASCII |
| `Month/Day/Year_Read_Hex` | `unsigned char` | `0xF922` | 3 bytes | BCD next-cal date |

### CAL2 Variables

| Variable | C type | DID | Notes |
|----------|--------|-----|-------|
| `STC_Hour/Min/Day/Month/Year_Read_Hex` | `unsigned char` | `0xF90B` | BCD current time/date |
| `UTC_Read_Counter` | `signed char` | `0xF90E` | ±hours |
| `UTC_Min_Read_Hex` | `unsigned char` | `0xF90D` | minutes |
| `PPROOS_Read_Hex` | `unsigned short` | — | Pulses per rev output shaft |
| `RegMemState[5]` | `unsigned char[]` | `0xF97D` | ISO country code (e.g., "TUR") |
| `CodePage_Selection` | `unsigned char` | — | Character encoding |

### CAL3 Variables

| Variable | C type | DID | Notes |
|----------|--------|-----|-------|
| `Reset_HeartBeat_Read_Hex` | `unsigned char` | `0xF90C` | 0=off, 1=on |
| `TCO1_Priority_Read_Hex` | `unsigned char` | — | 0–7 |
| `TCO1_Rep_Rate_Read_Hex` | `unsigned char` | — | 20ms or 50ms |
| `Trip_Distance_Read_Hex` | `unsigned int` | `0xF913` | km |
| `Number_of_Teeth_Read_Hex` | `unsigned short` | `0xF91A` | phonic wheel teeth |
| `Prewarning_Times_Card1_Download_Read_Hex` | `unsigned char` | `0xF994` | 0–250 days |
| `Prewarning_Times_Tacho_Download_Read_Hex` | `unsigned char` | `0xF995` | 0–250 days |
| `Prewarning_Times_Calb_Warning_Read_Hex` | `unsigned char` | `0xF996` | 0–250 days |
| `Down_Period_Card_Download_Period_Read_Hex` | `unsigned char` | `0xF990` | 0–250 days |
| `Down_Period_VU_Download_Period_Read_Hex` | `unsigned char` | `0xF991` | 0–250 days |

### DTC Variables

```c
unsigned char DTCHighByte[256];
unsigned char DTCMiddleByte[256];
unsigned char DTCLowByte[256];
unsigned char statusOfDTC[256];      // Status mask per DTC
unsigned short DTC_Turn;             // Number of DTCs read
unsigned char ExtendedDTCMap[90][5]; // Extended data per DTC
```

### Optional Settings Variables (STC8255, 30 settings)

```c
unsigned short Options_Record_Read_Hex_8255[30];       // Raw values read from tachograph
unsigned char  Options_Record_selection_Values_8255[30]; // Mapped UI selection indices

unsigned int  Speedometer_Factor_Read_Hex;   // 1–60000
unsigned int  N_Factor_Read_Hex;             // 2000–64000
unsigned short N_Profile_Read_Hex[15];       // Engine speed profiles
unsigned short V_Profile_Read_Hex[15];       // Vehicle speed profiles
unsigned char B7_Recognize_Read_Hex;
unsigned char Military_Dimmer_Read_Hex;
unsigned char IMS_Source_Read_Hex;           // 0=disabled,1=CAN_A,2=CAN_C,4=GPS
unsigned char CAN_A_Baudrate_Read_Hex;
unsigned char CAN_C_Baudrate_Read_Hex;
unsigned char CAN_A_Sampling_Point_Read_Hex;
unsigned char Backlight_Option_Read_Hex;
unsigned char Distance_Unit_Read_Hex;        // 0=km, 1=miles
unsigned char Language_Change_Read_Hex;
```

### Communication Buffers

```c
unsigned char KLINE_TX_buffer[100];  // Outgoing frame buffer
unsigned char KLINE_RX_buffer[100];  // Incoming response buffer
unsigned char Read_Error_Flag;       // Set on timeout or negative response
unsigned char Compare_Error_Flag;    // Set when read-back mismatches write value
```

---

## 11. Security / PIN Flow

The PIN authentication uses KWP2000 **SecurityAccess (SID 0x27)** with a seed-key challenge-response:

1. Device requests a **seed** from the tachograph (`subFunction = 0x7D`, securityAccessType `0x04`).
2. Tachograph responds with a seed value.
3. Operator types PIN on the keypad; the PIN bytes are sent as the **key** (`subFunction = 0x7E`).
4. Tachograph validates the key.

```
Request seed:  80 EE F0 03 27 7D 04 <CS>
Response:      80 F0 EE <N+2> 67 7D <N seed bytes> <CS>

Send key:      80 EE F0 <K+2> 27 7E <K key/PIN bytes> <CS>
Accept:        80 F0 EE 02 67 7E <CS>
Reject:        80 F0 EE 03 7F 27 35 <CS>    (0x35 = InvalidKey)
Lockout:       80 F0 EE 03 7F 27 36 <CS>    (0x36 = ExceededNumberOfAttempts)
```

**Implementation notes:**
- The device allows **maximum 3 attempts** before NRC 0x36 locks the session.
- PIN bytes are ASCII-encoded characters from the keypad matrix.
- A successful PIN unlocks `_isPinAuthenticated` flag; calibration writes are gated behind this flag.

---

## 12. Diagnostic Test Routines

All test routines use **SID 0x31 RoutineControl** with subfunction:
- `0x01` = StartRoutine
- `0x02` = StopRoutine
- `0x03` = RequestRoutineResults

**Session required:** ECUAdjustmentSession (`0x87`)

### Routine ID Table

| Routine ID | Name | Notes |
|------------|------|-------|
| `0x014F` | MOTION_SENSOR_VEHICLE_UNIT_PAIRING | Pairs motion sensor with VU |
| `0x0150` | DISPLAY_TEST | TFT/display test pattern |
| `0x0151` | LCD_NEGATIVE_MODE_TEST | Invert display test |
| `0x0152` | PRINTER_TEST | Built-in printer test |
| `0x0153` | HARDWARE_TEST | General hardware self-test |
| `0x0154` | SMART_CARD_READER_TEST | Card reader functional test |
| `0x0156` | BUTTON_TEST_LOOP | Keypad/button validation loop |
| `0x0157` | BATTERY_LEVEL | Read battery voltage level |
| `0x0158` | DATA_MEMORY_INTEGRITY | Check data memory CRC |
| `0x0159` | SOFTWARE_INTEGRITY | Verify firmware checksum |
| `0x015A` | BUZZER_TEST | Activate audible buzzer |

### Routine Frame Format

```
TX: 80 EE F0 04 31 <sub> <RI_H> <RI_L> <CS>
     sub = 01 (start), 02 (stop), 03 (get results)
     RI  = routine ID (2 bytes)

Example — Start Display Test:
     80 EE F0 04 31 01 01 50 <CS>

Response:
     80 F0 EE 04 71 <sub> <RI_H> <RI_L> [result bytes] <CS>
```

---

## 13. Error / NRC Code Table

Negative responses arrive as: `7F <request_SID> <NRC>`

| NRC (hex) | Meaning | Common cause |
|-----------|---------|-------------|
| `0x10` | GeneralReject | Generic failure |
| `0x12` | SubFunctionNotSupported | Unsupported sub-function byte |
| `0x13` | IncorrectMessageLength | Frame length wrong |
| `0x22` | ConditionsNotCorrectOrRequestSequenceError | Wrong session for this service |
| `0x24` | RequestSequenceError | Steps executed out of order |
| `0x31` | RequestOutOfRange | DID or value out of bounds |
| `0x35` | InvalidKey | Wrong PIN / key in SecurityAccess |
| `0x36` | ExceededNumberOfAttempts | Too many failed PIN attempts |
| `0x78` | RequestCorrectlyReceivedResponsePending | Processing, retry |
| `0x7A` | DeviceControlLimitsExceeded | RoutineControl value out of hardware limits |

---

## 14. Flash Storage Layout

The TM4C129 on-chip flash is used for persistent device configuration:

| Address | Size | Content |
|---------|------|---------|
| `0x0FC0000` | 11 bytes + 1 CRC | STKC Serial Number |
| `0x0F80000` | 82 bytes | Workshop Name (80 bytes ASCII + null + CRC) |
| `0x0F40000` | 8 bytes + 1 CRC | STKC Settings Array (see below) |

### Settings Array Layout (8 bytes)

| Index | Content | Values |
|-------|---------|--------|
| `[0]` | Language | 0=Turkish, 1=English, 2=Spanish, 3=Ukrainian |
| `[1]` | PhotoSensor/Switch Type | 0=Switch, 1=Matt, 2=Lontex |
| `[2]` | Backlight Intensity | 5–120 |
| `[3]` | Buzzer | 0=Off, 1=On |
| `[4]` | Auto Clock Date Adjust | 0=Off, 1=On |
| `[5]` | Roller Port type | 0=Switch, 1=Bluetooth |
| `[6]` | Range High byte | 20–10 000 m (combined with [7]) |
| `[7]` | Range Low byte | |
| `[8]` | CRC byte | Sum of [0..7] mod 256 |

---

## 15. Relevance to Flutter Project

This section maps STKC firmware concepts to their counterparts in the `takograpp_d1` Flutter project.

| STKC Concept | Flutter Equivalent | File |
|---|---|---|
| K-LINE frame builder (`KLINE_TX_buffer` assembly) | `KLineFrame` builder | `lib/kline/kline_frame.dart` |
| Frame parser (`KLINE_RX_buffer` processing) | `KLineFrameBuffer` chunked parser | `lib/kline/kline_frame.dart` |
| DID constants (`0xF190`, `0xF97E`, etc.) | `KLineRecords` class | `lib/kline/kline_records.dart` |
| Tachograph address `0xEE`, source `0xF0` | `KLineSid`, `KLineSession` constants | `lib/kline/kline_records.dart` |
| Diagnostic session types (0x81, 0x85, 0x87) | `KLineSession` enum | `lib/kline/kline_records.dart` |
| Service SIDs (0x22, 0x2E, 0x27, 0x31…) | `KLineSid` constants | `lib/kline/kline_records.dart` |
| Routine IDs (0x014F–0x015A) | `KLineRoutineIds` constants | `lib/kline/kline_records.dart` |
| Wakeup + session flows (Flows 1–21) | `KLineService` methods | `lib/kline/kline_service.dart` |
| Parameter encode/decode (BCD, ASCII, etc.) | `KLineCodec` | `lib/kline/kline_codec.dart` |
| Commit-trigger rule | Documented in architecture | `CLAUDE.md` |
| PIN/SecurityAccess | (to implement) uses `KLineService` | |
| Bluetooth SPP transport | `ClassicBluetoothService` / BLE | `lib/bluetooth/services/` |
| `KLINE_TX_buffer` / `KLINE_RX_buffer` | `SPP_DATA` virtual channel | `KLineService` via `BleConnectionRepository` |

### Key Insights for Flutter Development

1. **Wakeup over BLE:** The STKC device uses UART directly at 360 baud. In the Flutter app, the BLE adapter bridges BLE ↔ K-LINE, so the wakeup byte (0x00) must be sent as a raw SPP_DATA write — the adapter handles the baudrate switching. The `KLineService` already does this.

2. **Commit-Trigger is mandatory:** Every write flow must send a second `StartCommunication` after `WriteDataByIdentifier`. Without it, the written value lives only in the tachograph's volatile RAM.

3. **Checksum is simple additive:** Sum all bytes (excluding checksum byte itself) mod 256. No CRC, no XOR.

4. **Session management:** Always call `StartDiagnosticSession(0x85)` before writes, then return to `Standard(0x81)` before `StopCommunication`. Reads work in Standard session.

5. **Response timeout:** Use 250 ms as the hard timeout for any read after a write. The tachograph may send `NRC 0x78` (ResponsePending) which means "wait and retry" — handle this with a retry loop up to ~5 seconds.

6. **DID byte order:** All multi-byte values are **big-endian** (MSB first). The STKC code always builds `(value >> 8) & 0xFF` as the first data byte.

7. **TyreCircumference encoding:** The wire value is `actual_mm / 8`. Decode: `wire_value * 8 = mm`.

8. **Odometer encoding:** 4-byte unsigned big-endian, unit = km.

9. **W-Constant write on Stoneridge:** When writing W-Constant, also write the same value to K-Constant (DID `0xF918`). This is a Stoneridge-specific hardware quirk.

---

*Document generated from STKC firmware source code analysis — 2026-06-26*
