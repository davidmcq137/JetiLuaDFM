# Handoff reply: TX timers are on the air (DFM-BLE (Lua) 0.9)

Written 2026-11-26 in the Linux session, for the Mac session on the iOS
app (JAFO, repo dfmBleApp). It answers `handoff-ble-tx-timers.md`.
Branch `dev`; DFM-BLE is `AppsNotShipped/DFM-BLE/DFM-BLE.lua`.

## Done as asked

Sensor 0xDF03A41F (EX manufacturer 0xA41F, device 0xDF03), name `TX timers`.

| | |
|---|---|
| param | the TX's timer number, 1-10 |
| label | `T<n> <name>`; just `T<n>` if the name is empty **or already is `T<n>`** (so a timer named "T1" is `T1`, not `T1 T1`) |
| type | int22, 1 decimal, unit `s`, signed |
| raw | ms / 100, rounded |

- **Read only.** DFM-BLE uses `timer.getByID(1..10)`, `getName`, `getType`
  and `getRawTime`. It creates, starts and stops nothing.
- **Every timer that exists is sent** every 200 ms with the other values.
  The list is re-read on the 10 s Describe cycle, so a new or renamed timer
  appears within 10 s.
- **Older firmware:** without the `timer` library (before 6.05, and every
  non-24 II), the sensor isn't sent at all.
- **The "Send TX controls" switch** in DFM-BLE's menu turns the timers off
  too, along with the controls and switches.
- **EX type on the wire:** the ESP32 sends each value in the smallest EX
  type that holds it, so a short time can arrive as int14 and widen to
  int22 as it grows. Decode by the type in each packet, as JAFO already
  does.

## Answers (DS-24 II emulator, firmware 6.06)

The test timers were T1, a count-down from 0:20 on switch Sf, and T2, a
count-up with no switch.

1. **Count-down timers give the time left,** exactly what the TX shows:
   20000, then 17047, 12029, 7017, 1993 ms. There's no need to know the
   start time.
2. **Past zero, the time goes negative:** -3035, then -5982 ms, while the
   TX screen showed **-0:00:05.9**. JAFO gets -6.0 s (raw -60).
3. **A stopped timer holds its time,** for both kinds.
4. **Count-up:** 1886690 ms while the screen showed 0:31:26.6.
5. **`getType` says "Standard" for both** the count-down and the count-up,
   so it can't tell them apart. JAFO doesn't need to: show the value as it
   comes.
6. **Differs from the API doc:** `getRawTime(h)` with no lap id returns
   **"R"**, not "T", and the number is milliseconds, not 100 ms. DFM-BLE
   accepts either letter as ms. **Still to check on a real DS-24 II.**

## For JAFO

As in your handoff: show 0xDF03 values as `m:ss` (`h:mm:ss` from an hour,
a minus sign below zero), and as seconds in variables and formulas. The TX
itself shows tenths (`-0:00:05.9`), if you want to match it.

## Tested so far

DFM-BLE (Lua) 0.9 in the emulator, through the ESP32, to the iPhone. It
showed 22 values (20 + 2 timers) with "Phone receiving". **JAFO's display
of them is not checked yet:** that's yours.

## The 6.05 globals note

Already handled: the DFM apps moved from `sharedVar` to `declareGlobal` on
2026-11-19, after `sharedVar` crashed on 6.05's sandboxed Lua. SensorE's
hook is a field on the shared `system` table and works on the 6.06
emulator.
