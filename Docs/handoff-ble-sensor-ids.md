# Handoff: new EX ids for DFM-BLE's own sensors

Written 2026-11-26 in the Mac session on the iOS app (JAFO, repo
dfmBleApp), for the Linux session. It follows
`handoff-ble-tx-controls-reply.md` (DFM-BLE (Lua) 0.7). Branch `dev`.

## The problem

DFM-BLE 0.7 sends its sensors as EX manufacturer **0xA400**, devices
**1, 2 and 3** (TX controls, TX switches, timers later). JETI's EX spec
(v1.07) says:

> For third party devices you are free to use the upper part of a serial
> number within range 0xA400 - 0xA41F. The lower part of a serial number
> should be used in a manner it ensures uniqueness of the whole serial
> number.

So 0xA400-0xA41F isn't ours: it's shared by **every** third-party maker,
hobbyists included, and device numbers 1, 2, 3 are the likeliest anyone
picks. A pilot's own sensor at 0xA400:0001 would clash with "TX
controls", and JAFO (or Studio Mobile) would mix the two sensors' values.

## The change (decided with the user)

| Sensor | EX manufacturer | EX device | Sensor id (device << 16 \| manufacturer) | Wire bytes |
|---|---|---|---|---|
| TX controls | 0xA41F | 0xDF01 | 0xDF01A41F | `1F A4 01 DF` |
| TX switches | 0xA41F | 0xDF02 | 0xDF02A41F | `1F A4 02 DF` |
| timers (later) | 0xA41F | 0xDF03 | 0xDF03A41F | `1F A4 03 DF` |

- 0xA41F is the top of the shared range (less used than 0xA400), and
  0xDF.. ("DF" for DFM) is unlikely as a device number.
- **Everything else stays as in 0.7:** names, params 1-8, labels, int14,
  1 decimal, %, rates.
- Keep the ids as constants in one place in DFM-BLE.lua: they change
  again if JETI assigns us a manufacturer ID (below).
- **Check Lua's sensor ids can't collide:** DFM-BLE skips real sensors
  whose id doesn't pack into 4 bytes (`packId`); make sure a real sensor
  that happens to be 0xDF01A41F can't arrive, or just let ours win.
- Bump DFM-BLE to 0.8, with a history line.

## JAFO

**Already changed** (dfmBleApp, `SensorKey.fromTX` in
`JAFO/Telemetry/ExPacket.swift`): JAFO lists 0xA41F:0xDF01-0xDF03 first,
as the TX's own, and treats 0xA400:1-3 as anyone's sensors. Until DFM-BLE
0.8 runs, the TX sensors still arrive, but they aren't listed first.

**For pilots:** a JAFO variable or gauge linked to a 0.7 TX sensor
(0xA400:...) won't follow the new ids; it needs linking again. Only the
user has linked any so far.

## Test (on the rig)

1. DFM-BLE 0.8 in the emulator, through the ESP32, to JAFO.
2. JAFO's telemetry list starts with "TX controls" then "TX switches".
3. P5 follows emulator slider 5; an assigned switch flips -100.0 / 100.0.
4. Studio Mobile (if handy) shows the same two sensors.

## Later: our own manufacturer ID

The user will ask JETI to assign DFM an EX manufacturer ID. When it
comes, both sides change their constants once more (and JAFO keeps
accepting 0xA41F:0xDF0x for a release, so old DFM-BLE copies still list
first).
