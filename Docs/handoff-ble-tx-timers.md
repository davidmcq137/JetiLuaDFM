# Handoff: DFM-BLE (Lua) sends the TX's timers

Written 2026-11-26 in the Mac session on the iOS app (JAFO, repo
dfmBleApp), for the Linux session. It follows the TX controls work
(DFM-BLE 0.8). Branch `dev`.

## Goal

The pilot sets up timers on the TX as usual (Timers/Sensors → Timers).
JAFO shows them: in the telemetry list, in panel text boxes, on the
glasses, and as variables for formulas. **DFM-BLE only reads them.** It
doesn't create, start or stop any timer, and makes no Lua timers.

## JETI's timer calls

`Docs/JETI DCDS_Lua_API_1.7.pdf` (March 2026), pages 120-131, the
`timer` library. **Since firmware V6.05, DC/DS-24 II only.**

- `timer.getByID(id)`: id 1-10 are the TX's own timers (11-20 are Lua
  timers: not used). Returns a handle, or nil if that timer isn't set up.
- `timer.getName(handle)`, `timer.getType(handle)` ("Standard",
  "FreeRunning", "Laps", "Lua").
- `timer.getRawTime(handle)`: returns `"T", ms`, the timer's current time
  in milliseconds (with a lap id: `"R", n`, a lap time in units of
  100 ms: "R 72" is 7.2 s; laps aren't used now).
- `timer.isRunning(handle)`, `timer.getRoundCount(handle)`.

**Check first:** does the Linux emulator have the `timer` library? It is
new in 6.05. If not, guard every call (`if timer and timer.getByID
then`), so DFM-BLE still runs on older firmware and in the emulator, and
the timers need a real DS-24 II with 6.05 to test.

## The sensor

| | |
|---|---|
| Sensor id | 0xDF03A41F (EX manufacturer 0xA41F, device 0xDF03) |
| Name (param 0) | `TX timers` |
| param | the timer's number, 1-10 |
| label | `T<n> <name>`, e.g. `T3 Flight`, cut to 31 characters; `T<n>` if the name is empty |
| type | int22 (4) |
| decimals | 1 (tenths of a second): raw = ms / 100, rounded |
| unit | `s` |

- **Every timer that exists** (`getByID` not nil) is described and sent,
  every `SEND_MS` like the other values. Ten int22 values is ~40 bytes per
  200 ms.
- **The param is the TX's timer number,** so a pilot who picks timer 3 in
  JAFO keeps it however the timers are renamed. Re-describe on the 10 s
  cycle, so a new name or a newly set-up timer appears.
- **Signed:** if a count-down timer's time goes past zero (the TX keeps
  counting into negative), send it negative. int22 with 1 decimal holds
  about ±58 hours.
- **Not now:** lap times, running state, Lua timers 11-20.

## To find out on a TX

1. **Count-down timers:** does `getRawTime` return the time left (what
   the TX shows) or the time elapsed? JAFO should show what the TX
   shows. If it's elapsed, can the countdown's start time be read? The API
   has no call for a native timer's target time.
2. **Past zero:** does a count-down's raw time go negative?
3. **Free-running and stopped timers:** the time is held while stopped
   (expected).

Write the answers into the reply handoff: JAFO's display depends on them.

## The JAFO side (Mac session, after this works)

Values from 0xA41F:0xDF03 show as `m:ss` (`h:mm:ss` from an hour, a
minus sign below zero) wherever JAFO shows a value. In variables and
formulas they stay seconds. Add 0xDF03 to nothing: `SensorKey.fromTX`
already lists it, so "TX timers" sorts with the TX's other sensors.

## Also in 6.05 (separate from timers)

The API says (page 4): from 6.05, **each Lua app's global variables are
its own**. A global stays inside the app that defined it, and
`declareGlobal(name, value)` makes one shared by all apps. Any DFM app
that shares state through globals (SensorE's `system.SensorE` hook? apps
reading another app's globals?) needs checking on 6.05.
