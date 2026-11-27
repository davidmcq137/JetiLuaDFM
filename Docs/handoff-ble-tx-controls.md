# Handoff: DFM-BLE (Lua) sends the TX's controls

Written 2026-11-26 in the Mac session on the iOS app (JAFO, repo
dfmBleApp), for the Linux session that runs DFM-BLE in the emulator.
Branch: `dev`. DFM-BLE is `AppsNotShipped/DFM-BLE/DFM-BLE.lua`.

## Goal

The pilot's variables in JAFO can come from TX controls (sticks, sliders,
switches), as DFM-InsP's "Control" variables do on the TX. A DS-24 II's
BLE sends only sensors, so DFM-BLE sends the controls itself.

## How: one more sensor

DFM-BLE describes the controls as **one extra sensor**, through the
frames it already sends (Describe 0x22, Values 0x23). The ESP32 turns it
into EX packets like any other sensor, and JAFO already treats every EX
sensor as a source for variables, gauges and the glasses. **No ESP32 or
JAFO change is needed to start.**

- **Sensor id:** `0x0001A400`, which the ESP32 splits into EX
  manufacturer 0xA400 (our range is 0xA400-0xA41F) and device 0x0001.
  Lua's real sensor ids never fall in that range.
- **Name (param 0):** "TX controls".
- **Values:**

| param | label | what | type | dec | unit |
|---|---|---|---|---|---|
| 1-8 | P1 ... P8 | `system.getInputs("P1")` ... | int14 (1) | 1 | % |
| 9-16 | the switch's label (`system.getSwitchInfo(sw).label`), else Sw1 ... | switches the pilot assigns in DFM-BLE's menu, `system.getInputsVal(sw)` | int14 (1) | 1 | % |

  - **Scaling:** -1 to 1 becomes raw = round(v * 1000) with 1 decimal,
    so -100.0 to 100.0 %, well inside int14 (±8191). Proportional
    switches work the same way.
  - **Unassigned switches** are left out of Describe; nothing is sent
    for them.
  - **Keep the params fixed** (P3 is always param 3, the first switch
    always 9): JAFO saves links as sensor + param, so a pilot's
    variables survive restarts and menu changes.
- **Rate:** with the other values, every `SEND_MS` (200 ms). That's fine
  for a spotter's display. Raise it only if the Linux session finds a
  reason to.
- **Re-describe** when the pilot changes the switch assignments (the
  sensor key changes, as for a new sensor list).
- **Menu:** up to 8 switch input boxes (`form.addInputbox(sw, true, ...)`),
  saved with `system.pSave`. Maybe an on/off for "Send TX controls",
  default on.

## Check

1. **In the emulator:** P1-P8 come from the emulator's sliders. DFM-BLE's
   values page should show the "TX controls" sensor moving with them.
2. **With the rig** (DFM-BLE → GPIO serial → ESP32 → BLE → iPhone): in
   JAFO, the telemetry list should show "TX controls" with P1-P8 and the
   assigned switches. A JAFO variable on P5 should follow the slider, as
   should a gauge linked to it.
3. **The ESP32's table:** MAX_SENSORS 16, MAX_VALUES 32 per sensor, so
   16 values fit. Watch its status line for link errors when the extra
   sensor is described.

## Later (not now)

- **3A01:** the design note puts TX extras on characteristic 0x3A01,
  "the TX's own telemetry". The ESP32 has only 0x3A02 today. It could
  route sensors 0xA400-0xA41F to a new 0x3A01 characteristic, a small
  firmware change, and JAFO already subscribes to 0x3A01 and decodes it
  the same way. It only matters for a real DS-24 II, where DFM-BLE would
  need a JETI Lua call to send anything over BLE. Decide that with JETI.
- **Other TX-only values,** as further params or another device id
  (0xA400 device 2 ...): timers, logical switches (L1 ...), trims, the
  TX's own GPS distance or alarms.

## The JAFO side

The Mac session tests that JAFO picks the sensor up, and may tidy the
pickers (TX controls first, labelled as the TX's).
