# Handoff: DFM-BLE (Lua) 0.10, timers on a DS-24 I

Written 2026-11-27 in the Linux session, for the Mac session on the iOS
app (JAFO, repo dfmBleApp). It follows `handoff-ble-tx-timers-reply.md`
(DFM-BLE 0.9). Branch `dev`, commit a11a936; DFM-BLE is
`AppsNotShipped/DFM-BLE/DFM-BLE.lua`.

**Nothing to change in JAFO.** This note is so you know where "TX timers"
values come from on each TX.

## What changed

JETI's `timer` library exists only on the DC/DS-24 II from firmware 6.05.
On every other TX (the DS-24 I, older firmware), DFM-BLE 0.9 sent no
timers at all. 0.10 gives those TXs **two timers of DFM-BLE's own**, a
rewrite of the ones DFM-HUD had.

| | TX with the timer library | TX without it |
|---|---|---|
| Timers | the TX's own, 1-10, read only | DFM-BLE's own, 1-2 |
| Set up in | the TX's Timers menu | DFM-BLE → TX controls → Timers |
| Sensor | 0xDF03A41F "TX timers" | the same |
| Params | the TX's timer number | 1 or 2 |
| Labels | `T<n>` or `T<n> <name>` | `T1`, `T2` |
| Encoding | int22, 1 decimal, unit `s`, signed | the same |

- **Behaviour matches the TX's timers:** up or down from a start time
  (minutes and seconds), and a count-down goes negative past zero. A
  stopped timer holds its time. A Reset switch puts it back to its start
  time, also while running. With no Run switch, a timer always runs.
- **Off by default:** a pilot ticks Timer 1 and/or 2 on DFM-BLE's Timers
  page. A timer that's off isn't described or sent, so the sensor can be
  missing, or have only param 2.
- **The running time isn't saved:** each timer starts again from its
  start time when DFM-BLE loads.
- **A TX never mixes the two kinds.** The library decides which one is
  used.

## For JAFO

- Show them exactly like the TX's timers (`m:ss`, a minus sign below
  zero), as you already do.
- **A link to "TX timers" param 1 means a different timer** on a DS-24 I
  than on a 24 II, but each model is flown on one TX, so this doesn't
  matter in practice.

## Tested

The test was in the DS-24 II emulator (6.06), with a test flag that forces
DFM-BLE's own timers, through the ESP32 to JAFO. Run and stop on Sf, going
past zero, and reset while running all worked. **JAFO showed T1** under
TX timers. With the flag off, the TX's own timers came back. **Not yet run
on a real DS-24 I.**

## Also in 0.10 (Lua side only)

DFM-BLE's "Values sent" page now lists its own sensors (TX controls,
switches, timers) first, as JAFO does, and has a scroll bar.
