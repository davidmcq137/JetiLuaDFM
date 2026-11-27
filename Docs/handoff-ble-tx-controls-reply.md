# Handoff reply: TX controls are on the air (DFM-BLE (Lua) 0.7)

Written 2026-11-26 in the Linux session, for the Mac session on the iOS
app (JAFO, repo dfmBleApp). It answers `handoff-ble-tx-controls.md`.
Branch `dev`; DFM-BLE is `AppsNotShipped/DFM-BLE/DFM-BLE.lua`.

## What changed from your plan: two sensors, not one

The user and I split the controls into **two EX sensors**. The reason: EX
value ids are 4 bits. Ids of 16 and up need an escape byte that is still
untested (Studio Mobile showed nothing for a 23-value sensor), and your plan
put the 8th switch on param 16. With two sensors, every param is 1-8, and
each sensor has room to grow.

It is **pure EX** on purpose. These are ordinary EX sensors (text packets for
the name, labels and units, data packets for the values, CRC8), decoded
exactly like a MUI or a GPS. If JETI ever lets Lua send on the TX's telemetry
stream (0x3A01 or 0x3A02), JAFO sees the same bytes and needs no change. Only
the DFM-BLE (Lua) to ESP32 serial link would be replaced.

## The sensors

Sensor id = device << 16 | manufacturer. Our manufacturer is **0xA400**.

| Sensor | EX manufacturer | EX device | Name (param 0) |
|---|---|---|---|
| 0x0001A400 | 0xA400 | 0x0001 | `TX controls` |
| 0x0002A400 | 0xA400 | 0x0002 | `TX switches` |
| 0x0003A400 | 0xA400 | 0x0003 | reserved for timers, later |

On the wire, manufacturer and device are little-endian, as for any sensor:
`00 A4 01 00` and `00 A4 02 00`.

**All values:** EX type int14, **1 decimal**, unit `%`. Raw = round(v ×
1000), where v is -1 to 1 from the TX, so the values run from -100.0 to
100.0 %.

**TX controls (device 1):**

| param | label | source |
|---|---|---|
| 1-8 | `P1` ... `P8` | `system.getInputs("P1" ... "P8")` |

All 8 are described whenever "Send TX controls" is on (the default). A
control that the TX doesn't have sends no value, but its param still stays
the same.

**TX switches (device 2):**

| param | label | source |
|---|---|---|
| 1-8 | the switch's label from the TX, e.g. `Sa`, `Sc` (JETI writes them in mixed case) | switch box 1-8 in DFM-BLE's "TX controls" menu page, `system.getInputsVal(sw)` |

- The pilot picks the switches. **Param = box number.** Unassigned boxes are
  left out, so params can have gaps: switches in boxes 1 and 3 send params 1
  and 3 only.
- If no box is assigned, the sensor isn't sent at all.
- The boxes take proportional controls too, so a value can sit anywhere from
  -100 to 100, not only at ±100. A switch used as a switch reads -100 or 100.
- Two boxes can carry the same label (for example SA at two positions), so
  key them by param, not label.

**Rate:** with every other value, every 200 ms. The Describe set is resent
every 10 s, and at once when the pilot changes a switch box.

## Tested (emulator → ESP32 → iPhone)

- **The rig:** DFM-BLE (Lua) 0.7 in the emulator feeds the second ESP32 over
  its USB port (ttyACM0). The ESP32 runs dfmBleESP 1f00cb1 and checks every
  frame's CRC.
- **What happened:** with two switches assigned, DFM-BLE reported 5 sensors
  and 20 values (3 real sensors with 10 values, plus 8 + 2). The status rows
  showed "Phone receiving" and 0 serial errors.
- **Not checked yet:** JAFO's own lists. That is yours: "TX controls" and
  "TX switches" should appear, P5 should follow emulator slider 5, and an
  assigned switch should flip between -100.0 and 100.0.

## For JAFO

- **Nothing new is needed to receive them.** They are plain EX sensors on
  0x3A02.
- **Optional:** show sensors with manufacturer 0xA400 as the TX's own,
  first in the pickers. Any manufacturer in 0xA400-0xA41F is ours.
- **Variables:** a link of sensor + param is stable across restarts, menu
  changes and switch re-assignments, as long as the pilot keeps the switch
  in the same box.

## Later

- **Timers** will be device 3. They will be the TX's own timers through
  JETI's newer Lua timer calls, not DFM-HUD's home-made ones. They will be
  sent as int22 seconds with unit `s` (not the EX time type, which can't go
  negative). They come after sticks and switches work in JAFO.
- **EX encoding in Lua** (the ESP32 then becomes a byte pass-through) is
  liked as an idea, but it stays on the ESP32 for now.
- **0x3A01:** this is unchanged from the design note. It is decided with
  JETI.
