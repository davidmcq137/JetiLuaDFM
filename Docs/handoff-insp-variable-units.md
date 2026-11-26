# Handoff: DFM-InsP telemetry variables in the pilot's units

Written 2026-11-26 in the Mac session on the iOS app (dfmBleApp), for the
Linux session that runs TestMX. Branch: `dev`.

## The bug

DFM-InsP converts telemetry to the pilot's units for **gauges**, but not
for **Lua variables** whose source is a sensor. So a variable holds the
sensor's raw value, in whatever unit the sensor sends.

This breaks what `DFM-InsP/Docs/en-units.md` promises: "all lua variable
operations are done in the default units". Its own example is glide
ratio, with speed and vario both in m/s.

A real case is in SensorE's config (`SensorE/sensorEmulator.jsn`):
"SMTEK Airspeed" sends `kmh` and "SMTEK Vario" sends `m/s`. With a variable
`vario` on the vario and a gauge on the airspeed, `GlideRatio_val()`
divides km/h by m/s, and the ratio comes out 3.6 times too big. Sensors
whose units the pilot can change (SM-Modellbau's GPS, for example) make
this common.

## Where it is (DFM-InsP/DFM-InsP.lua, as of 0.95.1122d)

- **`getSensorByID(SeId, SePa)`**, about line 451: what gauges use. It
  calls `system.getSensorByID` and then the local `convertUnits(sensor)`.
  That converts within a units group (`units.type`, `units.toNative`,
  about lines 104-136) to `InsP.settings.units[type]`, with °C/°F as a
  special case. It also handles the TX's own telemetry (SeId 0, SePa > 0).
- **`getSensorValue(SeId, SePa)`**, about line 439: returns the raw
  `value`, from `system.getSensorValueByID` if the firmware has it (a
  cheaper call), else from `system.getSensorByID`. It does no conversion.
- **`setVariables()`**, about line 939: for a variable whose `source` is
  "Sensor", it does `local v = getSensorValue(id, pa)`. **This is the
  line to change.**
- **About line 2996:** the loop that fills `lua.env[InsP.sensorLalist[i]]`
  (sensor values by label) also uses `getSensorValue`. Check whether
  formulas can reach `lua.env` sensor names. If they can, the same bug
  applies there, and it should get the same fix.

## The change

In `setVariables`, read a sensor variable through the converting path:

```lua
local s = getSensorByID(id, pa)
local v = s and s.value
if v then InsP.variables[i].value = v end
```

`getSensorByID` returns nil for an invalid sensor, so `v` stays nil and
the variable keeps its last value, as now. Do the same at line 2996 if it
applies.

## Decided (with the user)

- **Treat it as a bug fix.** Every sensor variable converts, with no
  per-variable switch.
- **Accept that old workarounds break, and say so in the release notes.**
  A pilot who wrote `S1 / 3.6` to work around the bug will now get the
  conversion twice and must remove it.
- **The iOS app does the same:** it converts once where telemetry is
  read, so gauges and variables agree. Keep the two apps consistent: same
  unit tables, same default units.

## Check before committing

1. **CPU.** `getSensorValueByID` was likely chosen because it's cheap;
   `getSensorByID` builds the full sensor table. `setVariables` does at
   most `doPerLoop` = 6 variables per call. Measure the loop time with
   TestMX before and after, with several sensor variables. If the cost is
   a problem, a cheaper option: keep `getSensorValueByID` for the value,
   look up the unit once per sensor (it doesn't change), and apply the
   same conversion arithmetic.
2. **A TestMX test,** on a SensorE config with a `kmh` airspeed:
   - a "Sensor" variable on it reads in m/s (the default units);
   - after changing the speed default to km/h, it reads in km/h;
   - a `GlideRatio_val()` gauge with a `vario` variable gives the right
     ratio.
   Add it to `TestMX/test/run-tests.sh` next to the DFM-InsP sequencer
   tests.
3. **The existing tests still pass:** `TestMX/test/run-tests.sh`.

## Release notes and version

- Bump `InsPVersion` (major.minor.MMDD plus a letter for each build that
  day) and add a line to the history block at the top of DFM-InsP.lua.
  Also update the version in `DFM-InsP.html`, as the note under the
  history block says.
- **Release note, roughly:** "Lua variables taken from a sensor are now
  converted to your default units, as the Units help always said, the
  same as gauges. If you divided or multiplied a variable to fix its
  units yourself (for example S1 / 3.6 for km/h), remove that, or the
  value will now be converted twice."
- `Docs/en-units.md` already describes the fixed behaviour. Check
  `Docs/en-luavariables.md` for anything that suggests converting by
  hand.

---

# Follow-ups (added 2026-11-26, after 0.95.1126a)

0.95.1126a did the units change above, and fixed mph (0.44704). Two
smaller items are left, to decide in the Linux session.

## 1. The other rounded unit factors

| Unit | Table now | Exact |
|---|---|---|
| km/h, kmh | 0.2778 | 1/3.6 = 0.277778 (0.01% off) |
| kt. | 0.51444 | 1852/3600 = 0.514444 |
| mi. | 1609.34 | 1609.344 |

Small, but free to fix. The iOS app (dfmBleApp `Telemetry/Units.swift`)
uses the exact values.

## 2. The running average in seconds (proposal)

**Now, on the TX:** a Lua variable's avgtype 2 is
`var.avg = (var.value - var.avg) / var.avgnumber + var.avg` in
`setVariables`, once per update of that variable. How long N updates
take depends on how often the variable is updated: `setVariables` does
`doPerLoop` = 6 variables per loop, so with more variables each one
updates less often, and the loop rate varies with CPU load
(en-editlua.md hedges: "20-30 times per second"). So the same N smooths
over different times on different models, and changes when a pilot
adds variables.

**In the iOS app:** the running average is set in seconds and uses the
real time between updates, so a setting means the same at any update
rate:

```
avg += (value - avg) * (1 - exp(-dt / seconds))
```

For dt much smaller than `seconds`, that's the TX's formula with
N = seconds / dt. It starts at the first value and restarts at a reset,
as on the TX.

**The proposal: the same on the TX,** so a setting means the same on
both and stops depending on the number of variables:

```lua
local now = system.getTimeCounter()               -- ms
local dt = (now - (var.avgT or now)) / 1000
if var.avgSeconds and var.avgSeconds > 0 then
   var.avg = var.avg + (var.value - var.avg) * (1 - math.exp(-dt / var.avgSeconds))
end
var.avgT = now
```

- Reset `avgT` with the average (the min/max reset switch, start-up).
- **Settings:** the "More" menu's N becomes seconds (0.1 to 60 in the
  iOS app). Existing models' `avgnumber` is a count of updates:
  convert once on load (seconds = N / 25 is close to the help's 20-30
  per second), or keep `avgnumber` working and add `avgSeconds`. Either
  way, mention it in the release notes, as with the units change.
- **Docs:** en-editlua.md's "a value of 30 for N will give
  approximately a 1s averaging time" becomes a time in seconds.
- **Test:** with TestMX, a variable stepping 0 to 10 should reach
  10 * (1 - e^-1) = 6.32 one `seconds` after the step, whatever
  `doPerLoop` and the number of variables. The iOS app has the same
  test (dfmBleAppTests `PilotVariableTests.runningAverage`).

The user's view: the approach is reasonable; decide in the Linux
session whether to make the change.
