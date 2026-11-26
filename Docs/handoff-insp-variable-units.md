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
