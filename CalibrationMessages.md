# SmartTrack Inc. Confidential

**K-LINE Calibration Message Reference**

*Tachograph Calibration Device — Protocol Documentation*

---

> **CONFIDENTIAL:** This document is intended solely for authorized SmartTrack Inc. customers.
> Distribution or disclosure to third parties is prohibited without prior written consent.

---

# K-LINE Messages — Tachograph Calibration Device

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.00 | 2026-06-23 | Initial release for the standard (base) firmware. Documents the generic STKC calibration K-LINE protocol common to all hardware variants (STC8250 / STC8255). |

---

## Calibration Message Sequence Flows

Every K-LINE transaction begins with the same physical layer setup:

```
Physical Layer Wakeup   → send 0x00 at 360 baud (ISO 14230 wakeup)
Switch to 10400 baud
Wait 23 ms
```

Each message is followed by a 60 ms inter-message delay unless noted otherwise.

---

### Regarding K-LINE Communication Session Handling

Each K-LINE transaction with the tachograph must be a self-contained sequence: a physical-layer wakeup pattern (`0x00` at 360 baud), followed by **StartCommunication**, the service request(s), and finally **StopCommunication**. This is required for every individual operation — reads and writes alike — because the tachograph may enter a low-power state between transactions and does not maintain a persistent open session. A single StartCommunication/StopCommunication pair for the entire calibration flow is not sufficient.

For write operations, there is an additional requirement: after the **WriteDataByIdentifier** request and before the read-back verification, a second **StartCommunication** must be issued. This intermediate StartCommunication serves as a commit trigger that causes the tachograph to persist the newly written value to non-volatile memory. If this step is omitted, the value will only be held in volatile memory and will not survive a power cycle. The full sequence for a write operation is therefore: Wakeup → StartCommunication → StartDiagnosticSession(Programming) → WriteDataByIdentifier → StartCommunication (commit) → ReadDataByIdentifier (verify) → StartDiagnosticSession(Standard) → StopCommunication.

---

### Flow 1 — Security Access (PIN Entry)

**Triggered:** Once per workshop session, before any write operation is allowed.

The PIN is entered by the operator on the device keypad and transmitted as ASCII in the **SendKey** message. The PIN length is variable (`PIN_Index` bytes); the `LEN` byte is `PIN_Index + 2`.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                                      StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 81 <CS>                              StartDiagnosticSession (Standard)
RX ← 50 ...

TX → 80 EE F0 02 27 7D 04                                SecurityAccess — RequestSeed
RX ← 67 7D <seed bytes...>

TX → 80 EE F0 <PIN_len+2> 27 7E <PIN ASCII...> <CS>      SecurityAccess — SendKey (operator-entered PIN)
[Wait 1000 ms — tachograph PIN decoding time]
RX ← 67 7E                        (positive)
     or 7F 27 <NRC>               (negative)
     [If NRC=0x78: retry receiving until final response arrives]

TX → 80 EE F0 01 82 E1                                   StopCommunication
RX ← C2 ...
```

---

### Flow 2 — CAL1: Read All Calibration Data
**Triggered:** On entry to Calibration 1 screen.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0              StartCommunication
RX ← C1 ...

TX → 80 EE F0 03 22 F1 90 <CS>  RDBI 0xF190 — VIN
RX ← 62 F1 90 <17 bytes>

TX → 80 EE F0 03 22 F9 0B <CS>  RDBI 0xF90B — CurrentDateTime
RX ← 62 F9 0B <8 bytes>

TX → 80 EE F0 03 22 F9 12 <CS>  RDBI 0xF912 — Odometer
RX ← 62 F9 12 <4 bytes>

TX → 80 EE F0 03 22 F9 18 <CS>  RDBI 0xF918 — K-Constant
RX ← 62 F9 18 <2 bytes>

TX → 80 EE F0 03 22 F9 1C <CS>  RDBI 0xF91C — Tyre Circumference
RX ← 62 F9 1C <2 bytes>

TX → 80 EE F0 03 22 F9 1D <CS>  RDBI 0xF91D — W-Constant
RX ← 62 F9 1D <2 bytes>

TX → 80 EE F0 03 22 F9 21 <CS>  RDBI 0xF921 — Tyre Size
RX ← 62 F9 21 <15 bytes>

TX → 80 EE F0 03 22 F9 22 <CS>  RDBI 0xF922 — Next Calibration Date
RX ← 62 F9 22 <3 bytes>

TX → 80 EE F0 03 22 F9 2C <CS>  RDBI 0xF92C — Speed Limit
RX ← 62 F9 2C <2 bytes>

TX → 80 EE F0 03 22 F9 7D <CS>  RDBI 0xF97D — Registering Member State
RX ← 62 F9 7D <3 bytes>  (ISO country code, e.g. `54 55 52` = "TUR")

TX → 80 EE F0 03 22 F9 7E <CS>  RDBI 0xF97E — VRN
RX ← 62 F9 7E <14 bytes>

TX → 80 EE F0 01 82 E1           StopCommunication
RX ← C2 ...
```

---

### Flow 3 — CAL1: Write a Single Parameter
**Triggered:** When user confirms a modified calibration value (VIN, VRN, Odometer, Speed Limit, K/W-Constant, Tyre Circumference, Tyre Size, Next Calibration Date, etc.).

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <session> <CS>                StartDiagnosticSession (ECUProgrammingSession)
RX ← 50 ...

TX → 80 EE F0 <len> 2E <RID_H> <RID_L> <data...> <CS>
                                                   WDBI — write parameter value
RX ← 6E <RID_H> <RID_L>

   [Special case — W-Constant on STONERIDGE hardware:]
   TX → 80 EE F0 05 2E F9 18 <K_H> <K_L> <CS>    WDBI 0xF918 — K-Constant (same value)
   RX ← 6E F9 18

TX → 81 EE F0 81 E0                               StartCommunication (triggers VU internal save)
RX ← C1 ...

TX → 80 EE F0 03 22 <RID_H> <RID_L> <CS>          RDBI — read back to verify
RX ← 62 <RID_H> <RID_L> <data...>

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 4 — CAL2: Write Date & Time
**Triggered:** When user sets the tachograph clock.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <session> <CS>                StartDiagnosticSession (ECUProgrammingSession)
RX ← 50 ...

TX → 80 EE F0 03 22 F9 0B <CS>                    RDBI 0xF90B — read current DateTime
RX ← 62 F9 0B <8 bytes>

   [If time delta > 20 min → full recalibration; if NOT time-adjustment only:]
   TX → 80 EE F0 03 22 F9 1D <CS>                 RDBI 0xF91D — read W-Constant
   RX ← 62 F9 1D <2 bytes>
   TX → 80 EE F0 05 2E F9 1D <W_H> <W_L> <CS>    WDBI 0xF91D — write W-Constant back
   RX ← 6E F9 1D

TX → 80 EE F0 <len> 2E F9 0B <8 bytes data> <CS>  WDBI 0xF90B — write new DateTime
RX ← 6E F9 0B

TX → 81 EE F0 81 E0                               StartCommunication (triggers VU save)
RX ← C1 ...

TX → 80 EE F0 03 22 F9 0B <CS>                    RDBI 0xF90B — read back to verify
RX ← 62 F9 0B <8 bytes>

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 5 — CAL2: Write UTC Offset
**Triggered:** When user sets the UTC timezone offset.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                                StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <session> <CS>                 StartDiagnosticSession (ECUProgrammingSession)
RX ← 50 ...

TX → 80 EE F0 04 2E F9 0D <min_offset> <CS>        WDBI 0xF90D — UTC Minute Offset
RX ← 6E F9 0D

TX → 80 EE F0 04 2E F9 0E <hour_offset> <CS>       WDBI 0xF90E — UTC Hour Offset
RX ← 6E F9 0E

[Wait 1000 ms]

TX → 80 EE F0 03 22 F9 0D <CS>                     RDBI 0xF90D — verify
RX ← 62 F9 0D <1 byte>

TX → 80 EE F0 03 22 F9 0E <CS>                     RDBI 0xF90E — verify
RX ← 62 F9 0E <1 byte>

TX → 81 EE F0 81 E0                                StartCommunication (triggers VU save)
RX ← C1 ...

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 6 — CAL3: Write Prewarning Times
**Triggered:** When user sets card/tacho/calibration prewarning thresholds.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                                StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <session> <CS>                 StartDiagnosticSession (ECUProgrammingSession)
RX ← 50 ...

TX → 80 EE F0 04 2E F9 94 <val> <CS>               WDBI 0xF994 — Prewarning Card1 Download
RX ← 6E F9 94

TX → 80 EE F0 04 2E F9 95 <val> <CS>               WDBI 0xF995 — Prewarning Tacho Download
RX ← 6E F9 95

TX → 80 EE F0 04 2E F9 96 <val> <CS>               WDBI 0xF996 — Prewarning Calibration Warning
RX ← 6E F9 96

TX → 81 EE F0 81 E0                                StartCommunication (triggers VU save)
RX ← C1 ...

TX → 80 EE F0 03 22 F9 94 <CS>                     RDBI 0xF994 — verify
RX ← 62 F9 94 <1 byte>

TX → 80 EE F0 03 22 F9 95 <CS>                     RDBI 0xF995 — verify
RX ← 62 F9 95 <1 byte>

TX → 80 EE F0 03 22 F9 96 <CS>                     RDBI 0xF996 — verify
RX ← 62 F9 96 <1 byte>

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 7 — CAL3: Write Download Periods
**Triggered:** When user sets card and VU download period thresholds.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                                StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <session> <CS>                 StartDiagnosticSession (ECUProgrammingSession)
RX ← 50 ...

TX → 80 EE F0 04 2E F9 91 <val> <CS>               WDBI 0xF991 — Download Period VU
RX ← 6E F9 91

TX → 80 EE F0 04 2E F9 90 <val> <CS>               WDBI 0xF990 — Download Period Card
RX ← 6E F9 90

TX → 81 EE F0 81 E0                                StartCommunication (triggers VU save)
RX ← C1 ...

TX → 80 EE F0 03 22 F9 90 <CS>                     RDBI 0xF990 — verify
RX ← 62 F9 90 <1 byte>

TX → 80 EE F0 03 22 F9 91 <CS>                     RDBI 0xF991 — verify
RX ← 62 F9 91 <1 byte>

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 8 — Motion Sensor (MS) Pairing
**Triggered:** When user initiates motion sensor — vehicle unit pairing.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                                StartCommunication
RX ← C1 ...

TX → 80 EE F0 02 10 <ECUAdjustmentSession> <CS>    StartDiagnosticSession (Adjustment)
RX ← 50 ...

TX → 80 EE F0 04 31 01 <RID_H> <RID_L> <CS>        RoutineControl — startRoutine
     (MOTION_SENSOR_VEHICLE_UNIT_PAIRING)
RX ← 71 ...

TX → 80 EE F0 04 31 03 <RID_H> <RID_L> <CS>        RoutineControl — requestRoutineResults
RX ← 71 03 ... <result byte>

[Repeat every 250 ms until result = MSPAIR_SUCCESS or CONDITIONS_NOT_CORRECT]
TX → 80 EE F0 04 31 03 <RID_H> <RID_L> <CS>
RX ← 71 03 ... <result>
...

TX → 80 EE F0 02 10 81 <CS>                        StartDiagnosticSession (StandardDiagnosticSession)
RX ← 50 ...

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Flow 9 — Read Individual Parameter (single field refresh)
**Triggered:** When a calibration screen refreshes a single field from the tachograph.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
RX ← C1 ...

TX → 80 EE F0 03 22 <RID_H> <RID_L> <CS>          RDBI — one or more record IDs
RX ← 62 <RID_H> <RID_L> <data...>
[repeat for each record ID required]

TX → 80 EE F0 01 82 E1                             StopCommunication
RX ← C2 ...
```

---

### Overall Calibration Session Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Flow 1 — Security Access (PIN)                                │
│    StartComm → StartSession(Standard) → RequestSeed →           │
│    SendKey(operator PIN) → [wait] → StopComm                    │
│                                                                 │
│ 2. Flow 2 — CAL1 Read All                                       │
│    StartComm → RDBI×11 → StopComm                               │
│                                                                 │
│ 3. Flow 3 — CAL1 Write (one per changed parameter)              │
│    StartComm → StartSession(Programming) → WDBI →              │
│    StartComm → RDBI(verify) → StartSession(Standard) →         │
│    StopComm                                                     │
│                                                                 │
│ 4. Flow 4 — CAL2 Date/Time Write (if clock changed)             │
│    StartComm → StartSession(Programming) → RDBI(F90B) →        │
│    [WDBI(F91D)] → WDBI(F90B) → StartComm → RDBI(F90B) →       │
│    StartSession(Standard) → StopComm                           │
│                                                                 │
│ 5. Flow 5–7 — CAL2 UTC / CAL3 Prewarning / Download Period     │
│    (as needed, same write→verify pattern)                       │
│                                                                 │
│ 6. Flow 8 — MS Pairing (if motion sensor replaced)              │
│    StartComm → StartSession(Adjustment) → RoutineControl loop   │
│    → StartSession(Standard) → StopComm                         │
└─────────────────────────────────────────────────────────────────┘
```

> **Note:** The second `StartCommunication` inside write flows (Flows 3–7) is not a re-init — it acts as a trigger that causes the tachograph to internally commit the just-written value to non-volatile memory.

---

## Test Menu Flows

All tests open an **ECUAdjustmentSession** and send **TesterPresent** keepalive messages during execution to prevent session timeout.

> **Note:** The Photo Sensor / Flexi Switch test has no K-line messages — it uses local GPIO hardware only.

---

### Flow 10 — Clock Test

The tachograph outputs 1 Hz RTC pulses on the calibration I/O line. The device captures 12 pulse periods using its internal timestamp counter (120 MHz) and computes the 24-hour equivalent clock drift.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 03 22 F1 92 06                      RDBI 0xF192 — HW Version (version check)
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 05 2F F9 60 03 03 F1               IOCP — Enable RTC Output

[Tachograph outputs 1 Hz RTC pulses on calibration I/O pin]
[Device captures 12 pulse periods. Every ~150 ms during capture:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[After 12 pulses captured or KEY_EXIT pressed:]
TX → 80 EE F0 04 2F F9 60 01 EB                  IOCP — Reset to Default
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

Clock drift result displayed as ±s/day equivalent (pass criterion: ≤ ±2 s/day).

---

### Flow 11 — Speed & Odometer Test

The device outputs speed pulses at three speeds sequentially (40 → 70 → 100 km/h, 300 seconds each) using the tachograph's K-constant. The tachograph's reported speed and odometer increment are read back and compared against the commanded values.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 03 22 F1 92 06                      RDBI 0xF192 — HW Version (version check)
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 05 2F F9 60 03 01 EF               IOCP — Enable Speed Signal Input
TX → 80 EE F0 03 22 F9 18 94                      RDBI 0xF918 — K-Constant (read, used to calculate pulse rate)
TX → 80 EE F0 03 22 F9 12 8E                      RDBI 0xF912 — Odometer (start value)

[Device outputs pulses at 40 km/h for 300 s. Every ~150 ms:]
TX → 80 EE F0 03 22 F9 02 7E                      RDBI 0xF902 — TachographVehicleSpeed (cyclic readback)
...

[4 second pause, then repeat at 70 km/h for 300 s:]
TX → 80 EE F0 03 22 F9 02 7E                      RDBI 0xF902 (cyclic)
...

[4 second pause, then repeat at 100 km/h for 300 s:]
TX → 80 EE F0 03 22 F9 02 7E                      RDBI 0xF902 (cyclic)
...

TX → 80 EE F0 03 22 F9 12 8E                      RDBI 0xF912 — Odometer (end value)
TX → 80 EE F0 04 2F F9 60 01 EB                  IOCP — Reset to Default
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

Speed error per step: `(V_measured − V_commanded) / V_commanded × 1000 ‰`
Odometer error: `(tachograph_delta_m − STKC_distance_m) / STKC_distance_m × 1000 ‰`

---

### Flow 12 — Display Test

The tachograph executes a self-test on its display. The operator observes the tachograph screen and confirms pass or fail on the device (F1 = Pass, F4 = Fail).

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 50 E5                   RoutineControl — startRoutine (DISPLAY_TEST 0x0150)

[Tachograph runs display test. Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[Operator presses F1 (Pass) or F4 (Fail):]
TX → 80 EE F0 05 31 02 01 50 01 E8               RoutineControl — stopRoutine (SUCCESSFUL)
  or
TX → 80 EE F0 05 31 02 01 50 00 E7               RoutineControl — stopRoutine (FAILED)

TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 13 — LCD Negative Mode Test

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 51 E6                   RoutineControl — startRoutine (LCD_NEGATIVE_MODE_TEST 0x0151)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[Operator presses F1 (Pass) or F4 (Fail):]
TX → 80 EE F0 05 31 02 01 51 01 E9               RoutineControl — stopRoutine (SUCCESSFUL)
  or
TX → 80 EE F0 05 31 02 01 51 00 E8               RoutineControl — stopRoutine (FAILED)

TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 14 — Printer Test

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 52 E7                   RoutineControl — startRoutine (PRINTER_TEST 0x0152)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[Operator presses F1 (Pass) or F4 (Fail):]
TX → 80 EE F0 05 31 02 01 52 01 EA               RoutineControl — stopRoutine (SUCCESSFUL)
  or
TX → 80 EE F0 05 31 02 01 52 00 E9               RoutineControl — stopRoutine (FAILED)

TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 15 — Hardware Test

The tachograph runs an internal hardware self-test and returns a `CONDITIONS_NOT_CORRECT` response when complete. No operator result confirmation is required.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 53 E8                   RoutineControl — startRoutine (HARDWARE_TEST 0x0153)

[Every ~150 ms until tachograph signals completion:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

TX → 80 EE F0 04 31 02 01 53 E9                   RoutineControl — stopRoutine
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 16 — Smart Card Reader Test

The slot number is passed as an extra byte in the startRoutine message. The operator observes the tachograph and confirms the result.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 05 31 01 01 54 01 EB               RoutineControl — startRoutine (SMART_CARD_READER_TEST 0x0154, slot 1)
  or
TX → 80 EE F0 05 31 01 01 54 02 EC               RoutineControl — startRoutine (slot 2)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[Operator presses F1 (Pass) or F4 (Fail):]
TX → 80 EE F0 05 31 02 01 54 01 EC               RoutineControl — stopRoutine (SUCCESSFUL)
  or
TX → 80 EE F0 05 31 02 01 54 00 EB               RoutineControl — stopRoutine (FAILED)

TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 17 — Keypad Test

The tachograph runs a button loop test. No stop routine is sent — the session is simply closed when the test ends.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 56 EB                   RoutineControl — startRoutine (BUTTON_TEST_LOOP 0x0156)

[Every ~150 ms until tachograph signals completion:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[No stopRoutine sent]
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 18 — Battery Level Test

The tachograph measures its internal backup battery level and displays the result on its own screen. The test runs until the tachograph signals completion (`CONDITIONS_NOT_CORRECT` response) or the operator presses EXIT.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 57 EC                   RoutineControl — startRoutine (BATTERY_LEVEL 0x0157)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

TX → 80 EE F0 04 31 02 01 57 ED                   RoutineControl — stopRoutine
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 19 — Data Memory Integrity Test

The tachograph verifies the integrity of its data memory (checksum / CRC check). Result is shown on tachograph display.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 58 ED                   RoutineControl — startRoutine (DATA_MEMORY_INTEGRITY 0x0158)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

TX → 80 EE F0 04 31 02 01 58 EE                   RoutineControl — stopRoutine
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 20 — Software Integrity Test

The tachograph verifies the integrity of its firmware (checksum / CRC check). Result is shown on tachograph display.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 59 EE                   RoutineControl — startRoutine (SOFTWARE_INTEGRITY 0x0159)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

TX → 80 EE F0 04 31 02 01 59 EF                   RoutineControl — stopRoutine
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Flow 21 — Buzzer Test

The tachograph activates its buzzer. No stop routine is sent.

```
[WAKEUP + 10400 baud]
TX → 81 EE F0 81 E0                               StartCommunication
TX → 80 EE F0 02 10 87 F7                          StartDiagnosticSession (ECUAdjustmentSession)
TX → 80 EE F0 04 31 01 01 5A EF                   RoutineControl — startRoutine (BUZZER 0x015A)

[Every ~150 ms:]
TX → 80 EE F0 02 3E 02 A0                         TesterPresent (no response)
...

[No stopRoutine sent]
TX → 80 EE F0 02 10 81 F1                          StartDiagnosticSession (Standard)
TX → 80 EE F0 01 82 E1                            StopCommunication
```

---

### Test Menu Routine Identifier Reference

| Routine ID | Hex | Test | Stop sent | Operator confirms result |
|------------|-----|------|-----------|--------------------------|
| DISPLAY_TEST           | `0x0150` | Display Test          | with result | Yes (F1/F4) |
| LCD_NEGATIVE_MODE_TEST | `0x0151` | LCD Negative Mode     | with result | Yes (F1/F4) |
| PRINTER_TEST           | `0x0152` | Printer Test          | with result | Yes (F1/F4) |
| HARDWARE_TEST          | `0x0153` | Hardware Test         | plain stop  | No          |
| SMART_CARD_READER_TEST | `0x0154` | Smart Card Test       | with result | Yes (F1/F4) |
| BUTTON_TEST_LOOP       | `0x0156` | Keypad Test           | none        | No          |
| BATTERY_LEVEL          | `0x0157` | Battery Level         | plain stop  | No          |
| DATA_MEMORY_INTEGRITY  | `0x0158` | Data Memory Integrity | plain stop  | No          |
| SOFTWARE_INTEGRITY     | `0x0159` | Software Integrity    | plain stop  | No          |
| BUZZER                 | `0x015A` | Buzzer Test           | none        | No          |

---

## Frame Format (ISO 14230 / KWP2000)

```
[FMT] [TADDR] [SADDR] [LEN] [SID] [DATA...] [CS]
```

| Field  | Value  | Description                             |
|--------|--------|-----------------------------------------|
| FMT    | `0x80` | Format byte (length in LEN byte)        |
| TADDR  | `0xEE` | Target: Tachograph ECU                  |
| SADDR  | `0xF0` | Source: Calibration device              |
| LEN    | N      | Number of bytes from SID to end of DATA |
| CS     | —      | Checksum: sum of all preceding bytes & 0xFF |

Every K-line message — request and response — is framed with this header and a trailing one-byte checksum. The `LEN` byte counts only the payload (`SID` plus `DATA`), not the header or the checksum.

**Worked example — StartDiagnosticSession (Standard):** the request frame `80 EE F0 02 10 81 F1` decodes as:

| Byte   | Field | Meaning                                          |
|--------|-------|--------------------------------------------------|
| `0x80` | FMT   | Standard format; length carried in the LEN byte  |
| `0xEE` | TADDR | Target = Tachograph ECU                          |
| `0xF0` | SADDR | Source = Calibration device                      |
| `0x02` | LEN   | 2 payload bytes follow (SID + 1 data byte)       |
| `0x10` | SID   | StartDiagnosticSession                           |
| `0x81` | DATA  | Sub-function = StandardDiagnosticSession (KWP2000) |
| `0xF1` | CS    | Checksum over the 6 preceding bytes              |

Checksum calculation: `0x80 + 0xEE + 0xF0 + 0x02 + 0x10 + 0x81 = 0x2F1`; keep the low byte → `0x2F1 & 0xFF = 0xF1`.

The KWP2000 (ISO 14230) session sub-functions used by this device are: **`0x81`** StandardDiagnosticSession, **`0x85`** ECUProgrammingSession (used before any write), **`0x87`** ECUAdjustmentSession (used by the Test Menu).

> **Fast-init exception:** the StartCommunication request (§1.1) uses `FMT=0x81`, which encodes the format and service in a single byte with no LEN field — e.g. `81 EE F0 81 E0`. All other messages use the `0x80` format shown above.

---

## 1. Communication Control

### 1.1 Start Communication

```
81 EE F0 81 E0
```
ISO 14230 fast-init header. FMT=`0x81` encodes both format and SID; no separate LEN byte.

---

### 1.2 Stop Communication

```
80 EE F0 01 82 E1
```

| Byte | Value  | Meaning           |
|------|--------|-------------------|
| SID  | `0x82` | StopCommunication |

---

## 2. Diagnostic Session Control — SID `0x10`

### 2.1 Start Diagnostic Session

```
80 EE F0 02 10 <Session_Type> <CS>
```

| Session_Type value | Name |
|---|---|
| `ECUProgrammingSession` | Programming session (write parameters) |
| `StandartDiagnosticSession` | Standard session (close programming) |
| `ECUAdjustmentSession` | Adjustment session (MS pairing) |

---

## 3. Tester Present — SID `0x3E`

### 3.1 Tester Present — No Response

```
80 EE F0 02 3E 02 A0
```
Sub-function `0x02` = suppress response. Sent one-way with no reply expected.

### 3.2 Tester Present — Response Required

```
80 EE F0 02 3E 01 9F
```
Sub-function `0x01` = response required.

---

## 4. Security Access — SID `0x27`

### 4.1 Request Seed

```
80 EE F0 02 27 7D 04
```
Sub-function `0x7D` = RequestSeed. Checksum `0x04` is the correct byte-sum of the header.

### 4.2 Send Key

```
80 EE F0 <PIN_len+2> 27 7E <PIN ASCII bytes...> <CS>
```
Sub-function `0x7E` = SendKey. The key is the workshop PIN **entered by the operator on the device keypad** and transmitted as ASCII (`PIN_Index` bytes). Sent with no response wait — response collected separately.

| Byte     | Value                  | Meaning                       |
|----------|------------------------|-------------------------------|
| [3]      | `PIN_Index + 2`        | LEN = PIN length + 2          |
| [4]      | `0x27`                 | SID                           |
| [5]      | `0x7E`                 | SendKey sub-function          |
| [6 …]    | `<PIN ASCII bytes>`    | operator-entered PIN (ASCII)  |

> **Variant note:** In the *Morocco* customer build this message carries a fixed factory PIN (`"85853124"`); in the standard firmware the PIN is whatever the operator types in.

---

## 5. Routine Control — SID `0x31`

> The specific routine identifiers used by the device tests (`0x0150`–`0x015A`) are catalogued in the **Test Menu Routine Identifier Reference** table at the end of the *Test Menu Flows* section.

### 5.1 Routine Control (no extra param)

```
80 EE F0 04 31 <select> <RID_H> <RID_L> <CS>
```

### 5.2 Routine Control with Result

```
80 EE F0 05 31 <select> <RID_H> <RID_L> <result> <CS>
```

### 5.3 Routine Control — Smart Card Slot

```
80 EE F0 05 31 <select> <RID_H> <RID_L> <slot_no> <CS>
```

| `select` | Meaning               |
|----------|-----------------------|
| `0x01`   | startRoutine          |
| `0x02`   | stopRoutine           |
| `0x03`   | requestRoutineResults |

---

## 6. DTC Services

### 6.1 Report Number of DTC by Status Mask — SID `0x19`

```
80 EE F0 03 19 01 09 84
```
Sub `0x01` = reportNumberOfDTCByStatusMask. Mask = `0x09`.

### 6.2 Report DTC by Status Mask — SID `0x19`

```
80 EE F0 03 19 02 09 85
```
Sub `0x02` = reportDTCByStatusMask. Mask = `0x09`.

### 6.3 Report Extended DTC — SID `0x19`

```
80 EE F0 06 19 06 00 FF <index> 0A <CS>
```
Sub `0x06` = reportDTCExtendedDataRecordByDTCNumber. DTC group `0x00FF`, record number `0x0A`.

### 6.4 Clear Diagnostic Information — SID `0x14`

```
80 EE F0 04 14 FF FF FF 73
```
GroupOfDTC = `0xFFFFFF` (clear all DTCs).

---

## 7. Read Data By Identifier — SID `0x22`

```
80 EE F0 03 22 <RID_H> <RID_L> <CS>
```

All Record IDs used:

| Record ID | Parameter Name |
|-----------|----------------|
| `0xF18A`  | SystemSupplierIdentifier |
| `0xF18B`  | ECUManufacturingDate |
| `0xF18C`  | ECUSerialNumber |
| `0xF190`  | VehicleIdentificationNumber (VIN) |
| `0xF192`  | SystemSupplierECUHWNumber |
| `0xF193`  | SystemSupplierECUHWVersionNumber |
| `0xF194`  | SystemSupplierECUSWNumber |
| `0xF195`  | SystemSupplierECUSWVersionNumber |
| `0xF196`  | ExhaustRegulationOrTypeApprovalNumber |
| `0xF19B`  | CalibrationDate |
| `0xF19D`  | ECUInstallationDate |
| `0xF902`  | TachographVehicleSpeed |
| `0xF90B`  | CurrentDateTime |
| `0xF90C`  | ResetHeartBeat |
| `0xF90D`  | AdjustLocalMinuteOffset |
| `0xF90E`  | AdjustLocalHourOffset |
| `0xF90F`  | PriorityLevelOfTCO1Message |
| `0xF912`  | HighResOdometer |
| `0xF913`  | HighResolutionTripDistance |
| `0xF914`  | ServiceComponentIdentification |
| `0xF915`  | ServiceDelayCalendarTimeBased |
| `0xF918`  | K-Constant (K-constantOfRecordingEquipment) |
| `0xF91A`  | NumberOfTeethOnPhonicWheel |
| `0xF91C`  | L-TyreCircumference |
| `0xF91D`  | W-VehicleCharacteristicConstant |
| `0xF91E`  | PulsesPerRevolutionOfOutputShaft (PPROOS) |
| `0xF920`  | TransmissionRepetitionRateOfTCO1Message |
| `0xF921`  | TyreSize |
| `0xF922`  | NextCalibrationDate |
| `0xF92C`  | SpeedAuthorised (Speed Limit) |
| `0xF97D`  | RegisteringMemberState (standard ISO/AETR country code) |
| `0xF97E`  | VehicleRegistrationNumber (VRN) |
| `0xF97F`  | VehicleRegistrationDate |
| `0xF990`  | DownloadPeriod — Card |
| `0xF991`  | DownloadPeriod — VU |
| `0xF992`  | DownloadPeriod (?) |
| `0xF994`  | PrewarningTimes — Card1 Download |
| `0xF995`  | PrewarningTimes — Tacho Download |
| `0xF996`  | PrewarningTimes — Calibration Warning |
| `0x8250`  | Options Record (series, read via loop) |
| `0x8255`  | Options Record (series, read via loop) |
| `0xFD00`–`0xFD1F` | Optional Settings block 0x00–0x1F |
| `0xFD22`  | Optional Setting |
| `0xFD23`  | Engine Speed Source |
| `0xFD30`  | CAN Protocols |
| `0xFD31`–`0xFD36` | CAN configuration settings |
| `0xFD3A`–`0xFD3E` | Optional Settings (incl. RDDW in Sleep) |
| `0xFD41`  | Periodic DAGS |
| `0xFD50`  | DAGS Buzzer Control |
| `0xFD51`  | Card Existence Warning Output |
| `0xFD52`  | Card Remote Download Activity |
| `0xFD53`  | GNSS Antenna |

---

## 8. Write Data By Identifier — SID `0x2E`

### 8.1 Write W-Constant (direct, no conversion)

```
80 EE F0 05 2E F9 1D <W_H> <W_L> <CS>
```
Record ID `0xF91D`. Writes W-constant as-is without string conversion.

---

### 8.2 Write Data By Identifier — Parametric

```
80 EE F0 <len> 2E <RID_H> <RID_L> <data...> <CS>
```

| Record ID | Parameter | Payload |
|-----------|-----------|---------|
| `0xF97E`  | VRN | 14 bytes ASCII |
| `0xF190`  | VIN | 17 bytes ASCII |
| `0xF92C`  | Speed Limit | 2 bytes (`SpeedLimit`, `0x00`) |
| `0xF912`  | Odometer | 4 bytes (32-bit BE) |
| `0xF918`  | K-Constant | 2 bytes BE |
| `0xF91D`  | W-Constant | 2 bytes BE |
| `0xF91C`  | Tyre Circumference | 2 bytes (value × 8) |
| `0xF921`  | Tyre Size | 15 bytes ASCII |
| `0xF922`  | Next Calibration Date | `Month`, `4*(Day-1)+2`, `Year` (3 bytes) |
| `0xF90B`  | Set Time & Date | 8 bytes: `0x00`, `Min`, `Hour`, `Month`, `4*(Day-1)+2`, `Year`, `LocalMinOffset`, `LocalHourOffset` |
| `0xF91E`  | PPROOS | 2 bytes BE (range 0–64255) |
| `0xF97D`  | Registration Member State | 3 bytes (ISO/AETR country abbreviation) |
| `0xF90D`  | UTC Minute Offset | 1 byte: `(UTC_Counter % 2) * 30 + 0x7D` |
| `0xF90E`  | UTC Hour Offset | 1 byte: `(UTC_Counter / 2) + 0x7D` |
| `0xF19D`  | ECU Installation Date | 3 bytes BCD: Year, Month, Day |
| `0xF97F`  | Vehicle Registration Date | 8 bytes: `00 00 00`, Month, `4*(Day-1)+2`, Year, `7D 7D` |
| `0xF90C`  | Reset HeartBeat | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xF90F`  | TCO1 Priority | 1 byte: `0x00` = Highest Priority, `0x01`–`0x06` = Priority 1–6, `0x07` = Lowest Priority |
| `0xF920`  | TCO1 Rep Rate | 1 byte: `0x00` = 20 ms, `0x01` = 50 ms |
| `0xF913`  | Trip Distance | 4 bytes (32-bit BE) |
| `0xF91A`  | Number of Teeth | 1 byte (range 0–250) |
| `0xF994`  | Prewarning — Card1 Download | 1 byte (days, range 0–250) |
| `0xF995`  | Prewarning — Tacho Download | 1 byte (days, range 0–250) |
| `0xF996`  | Prewarning — Calibration Warning | 1 byte (days, range 0–250) |
| `0xF991`  | Download Period VU | 1 byte (days, range 0–120) |
| `0xF990`  | Download Period Card | 1 byte (days, range 0–250) |

> **Variant note:** `0xF97D` (RegisteringMemberState) accepts only standard ISO/AETR country codes in this firmware. The custom `"MRC"` (Morocco, `0xFC`) code is defined only in the Morocco customer build.

---

### 8.3 Write Data By Identifier — Optional Parameter (`0xFD??`)

```
80 EE F0 <len> 2E <RID_H> <RID_L> <data...> <CS>
```
Payload is hardware-dependent — dispatches on tachograph hardware variant (`STC8250` or `STC8255`).

#### STC8250 Hardware Variant

| Record ID | Parameter | Payload |
|-----------|-----------|---------|
| `0xFD00` | Speedometer Factor | 2 bytes BE (range 1–60000) |
| `0xFD01` | B7 Recognize | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD02` | Card Expiry Dates | 5 bytes: Control Card, Driver Card, Workshop Card, Company Card, Calibration Expiry (0→250 if disabled) |
| `0xFD03` | CAN C On/Off | 2 bytes BE |
| `0xFD04` | Military Dimmer | 1 byte: `0x00` = Disabled, `0x01` = CAN-A, `0x03` = CAN-C |
| `0xFD05` | CAN C TCO1 | 2 bytes: `0xFF`, `CAN_C_TCO1 \| 0x80` |
| `0xFD06` | Overspeed Prewarning Time | 1 byte (seconds, range 0–60) |
| `0xFD07` | Ignition Options | 4 bytes: Driver Ign On, Co-Driver Ign On, Driver Ign Off, Co-Driver Ign Off |
| `0xFD08` | CAN A Baudrate & Sampling Point | 2 bytes: Baudrate idx (0=125, 1=250, 2=500, 3=1000 kbps), Sampling Point idx (0–11: 60–93.75%) |
| `0xFD09` | CAN C Baudrate & Sampling Point | 2 bytes: Baudrate idx (0=125, 1=250, 2=500, 3=1000 kbps), Sampling Point idx (0–11: 60–93.75%) |
| `0xFD0A` | Backlight & Battery Option | 2 bytes: Backlight, Battery (`0x01` = 24V, `0x02` = 12V) |
| `0xFD0B` | Distance Unit | 1 byte: `0x00` = Mile, `0x01` = km |
| `0xFD0C` | Language Change | 1 byte: `0x02` = By Card, `0x03` = By Card & Manual |
| `0xFD0D` | Overspeed Prewarning Output | 1 byte: `0x00` = Disabled, `0x01` = Display, `0x02` = Buzzer, `0x03` = Output, `0x04` = All |
| `0xFD0E` | Buzzer Overspeed Control | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD0F` | IMS Source | 1 byte: `0x00` = Disabled, `0x01` = CAN-A, `0x02` = CAN-C |
| `0xFD10` | Overspeed TCO1 | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD11` | Tripmeter Reset | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD12` | Output Shaft Speed Enable | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD13` | TCO1 Handling Info | 1 byte: `0x00` = None, `0x01` = Card, `0x02` = Paper, `0x03` = Card & Paper |
| `0xFD14` | CAN A Sample | 1 byte (sampling point index 0–11: 60–93.75%) |
| `0xFD15` | CAN A Sync Jump | 1 byte (raw value) |
| `0xFD16` | CAN C Sample | 1 byte (sampling point index 0–11: 60–93.75%) |
| `0xFD17` | CAN C Sync Jump | 1 byte (raw value) |
| `0xFD18` | IMS CAN PGN | 1 byte: `0x00` = PGN 65215, `0x01` = PGN 65256 |
| `0xFD19` | CAN A On/Off | 2 bytes BE |

#### STC8255 Hardware Variant

| Record ID | Parameter | Payload |
|-----------|-----------|---------|
| `0xFD10` | Backlight Source + levels | Variable 1–5 bytes depending on source mode (Disable/Menu/A2/Cabin) |
| `0xFD11` | Speedometer Factor | 2 bytes BE (range 1–60000) |
| `0xFD12` | N Profile Registry | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD13` | N Speed Profiles | 30 bytes (15 × 2-byte values) |
| `0xFD14` | V Profile Registry | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD15` | V Speed Profiles | 15 bytes |
| `0xFD16` | N Factor | 2 bytes BE (range 2000–64000) |
| `0xFD17` | IMS Source + optional PGN | Variable 1–2 bytes (PGN byte added for CAN A or CAN C) |
| `0xFD18` | Ignition Options | 4 bytes: Driver Ign On, Co-Driver Ign On, Driver Ign Off, Co-Driver Ign Off |
| `0xFD19` | Language Change | 1 byte: `0x02` = By Card, `0x03` = By Card & Manual |
| `0xFD1A` | Overspeed Prewarning Time | 1 byte (seconds, range 0–60) |
| `0xFD1B` | Overspeed Prewarning Output | 1 byte: `0x00` = Disabled, `0x01` = Display, `0x02` = Buzzer, `0x03` = Output, `0x04` = All |
| `0xFD1C` | B7 Recognize | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD1D` | D1/D2 State Enable | 2 bytes: State D1 Enable, State D2 Enable |
| `0xFD1E` | Distance Unit | 1 byte: `0x00` = Mile, `0x01` = km |
| `0xFD1F` | Buzzer Overspeed Control | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD22` | Card Expiry Dates | 5 bytes: Control Card, Driver Card, Workshop Card, Company Card, Calibration Expiry |
| `0xFD23` | Engine Speed Source | 1 byte: `0x00` = Disabled, `0x01` = CAN-A, `0x02` = CAN-C, `0x03` = C3 Rev |
| `0xFD30` | CAN Protocols | 2 bytes: Protocol P1, Protocol P2 |
| `0xFD31` | CAN A On/Off | 1 byte |
| `0xFD32` | CAN A Baudrate & Sampling Point | 2 bytes: Baudrate idx (0=125, 1=250, 2=500, 3=1000 kbps), Sampling Point idx (0–11: 60–93.75%) |
| `0xFD33` | CAN A Sync Jump | 1 byte (raw value) |
| `0xFD34` | CAN C On/Off | 1 byte |
| `0xFD35` | CAN C Baudrate & Sampling Point | 2 bytes: Baudrate idx (0=125, 1=250, 2=500, 3=1000 kbps), Sampling Point idx (0–11: 60–93.75%) |
| `0xFD36` | CAN C Sync Jump | 1 byte (raw value) |
| `0xFD3A` | Overspeed TCO1 | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD3B` | Tripmeter Reset | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD3C` | TCO1 Handling Info | 1 byte: `0x00` = None, `0x01` = Card, `0x02` = Paper, `0x03` = Card & Paper |
| `0xFD3D` | CAN Terminations | 2 bytes: CAN A Termination Enable, CAN C Termination Enable |
| `0xFD3E` | RDDW in Sleep | 1 byte |
| `0xFD41` | Periodic DAGS | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD50` | DAGS Buzzer Control | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD51` | Card Existence Warning Output | 1 byte: `0x00` = Disabled, `0x01` = Display, `0x02` = Display & Buzzer |
| `0xFD52` | Card Remote Download Activity | 1 byte: `0x00` = Disabled, `0x01` = Enabled |
| `0xFD53` | GNSS Antenna | 1 byte: `0x00` = Internal, `0x01` = External |

---

### 8.4 Write Option Setting (block write)

```
80 EE F0 <len> 2E <RID_H> <RID_L> <option bytes...> <CS>
```
Used for Record IDs `0x8250` and `0x8255` (tachograph option configuration blocks). Payload assembled field-by-field: speedometer factor, overspeed prewarning time, driver/co-driver ignition options, backlight settings, battery option, CAN A/C on/off and baudrate, sampling point, sync jump, TCO1 handling, IMS source, D1/D2 enable, card expiry options, N/V speed profiles, N-factor, download periods, etc.

---

## 9. IO Control By Identifier — SID `0x2F`

All use Data Identifier `0xF960`.

### 9.1 Enable Speed Signal Input (Calibration)

```
80 EE F0 05 2F F9 60 03 01 EF
```

### 9.2 Enable Speed Signal Output (Calibration)

```
80 EE F0 05 2F F9 60 03 02 F0
```

### 9.3 Enable RTC Output (Calibration)

```
80 EE F0 05 2F F9 60 03 03 F1
```

### 9.4 Reset to Default

```
80 EE F0 04 2F F9 60 01 EB
```
Two variants: one waits for a response, one does not.

| Byte [7] | ControlOption | Meaning |
|---|---|---|
| `0x01` | ReturnControlToECU | Reset to default |
| `0x03` | ShortTermAdjustment | Enable calibration I/O |

---

## Summary Table

| # | SID | Name |
|---|-----|------|
| 1 | `0x81` | StartCommunication |
| 2 | `0x82` | StopCommunication |
| 3 | `0x10` | DiagnosticSessionControl |
| 4 | `0x3E` | TesterPresent (no response) |
| 5 | `0x3E` | TesterPresent (response required) |
| 6 | `0x27` | SecurityAccess — RequestSeed |
| 7 | `0x27` | SecurityAccess — SendKey |
| 8 | `0x31` | RoutineControl |
| 9 | `0x31` | RoutineControl with result |
| 10 | `0x31` | RoutineControl with slot |
| 11 | `0x19` | ReadDTC — NumberByStatusMask |
| 12 | `0x19` | ReadDTC — ByStatusMask |
| 13 | `0x19` | ReadDTC — ExtendedDTC |
| 14 | `0x14` | ClearDiagnosticInformation |
| 15 | `0x22` | ReadDataByIdentifier |
| 16 | `0x2E` | WriteDataByIdentifier — W-Constant direct |
| 17 | `0x2E` | WriteDataByIdentifier — parameter |
| 18 | `0x2E` | WriteDataByIdentifier — Optional Parameter (`0xFD??`) |
| 19 | `0x2E` | WriteDataByIdentifier — Option Setting (`0x8250`/`0x8255`) |
| 20 | `0x2F` | IOControl — Enable Speed Input |
| 21 | `0x2F` | IOControl — Enable Speed Output |
| 22 | `0x2F` | IOControl — Enable RTC Output |
| 23 | `0x2F` | IOControl — Reset to Default |
