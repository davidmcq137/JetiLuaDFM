# Testing JETI Lua apps: UIDriver, SensorE/SensorL and FakeFW

This is the how-to for the test tools in this repo. It explains how the
pieces fit together, how to run the tests, and how to write new ones. The
complete reference for each tool stays in the comment at the top of its
source file; this guide links there rather than repeating it:

| Reference | Where |
|---|---|
| UIDriver: every script step, config.jsn, app hooks | header of [`UIDriver/UIDriver.lua`](../UIDriver/UIDriver.lua) |
| FakeFW: command line, module API, what is modelled | header of [`FakeFW/fakefw.lua`](fakefw.lua) |
| The unattended runner and its options | header of [`FakeFW/fakefw-uid.lua`](fakefw-uid.lua) |
| Fixtures (test data) | [`FakeFW/fixtures/README.txt`](fixtures/README.txt) |
| Fake Engo glasses (DFM-HUD's serial port) | header of [`FakeFW/devices/engo.lua`](devices/engo.lua) |
| SensorE (simulated sensors and flight) | [`SensorE/SensorE.txt`](../SensorE/SensorE.txt) |
| SensorL (log replay) | [`SensorL/README.txt`](../SensorL/README.txt) |
| The test suite, with working examples | [`FakeFW/test/run-tests.sh`](test/run-tests.sh) |

Paths below are relative to the emulator's `Apps/` folder
(`~/.config/JETI-Studio/Emulator/Apps`, the repo root) unless they start
with `Apps/`, which means they're run from the parent folder.

---

## 1. The pieces

```
           script (Apps/<App>/UIDriver/*.jsn)
                         |
                     UIDriver  ---- presses keys, sets widgets, reads the
                         |          screen, checks app state, announcements
   +---------------------+----------------------+
   |                     |                      |
 the app under test   SensorE or SensorL    (other apps)
                         |
                  fake sensors: simulated flight (SensorE)
                  or a replayed flight log (SensorL)

 all of it runs inside either
   - the JETI Studio emulator (dc-sim2), by hand, in real time, or
   - FakeFW, a fake firmware: unattended, faster than real time, in CI
```

- **UIDriver** is a Lua app that drives another app (the *target*) from a
  JSON script. It wraps the target's form and telemetry callbacks, so
  script steps run inside them: it can press keys, set widgets, follow
  links, press telemetry buttons, answer questions, move controls, fake
  sensor values and faults, and check what the app draws, announces and
  exposes. Results go to `Apps/<App>/UIDriver/result.log`. It runs only
  in the emulator or under FakeFW; on a real TX it does nothing.
- **SensorE** replaces the sensor API with simulated sensors, including
  a GPS flight simulator. Its configs live in `Apps/<App>/SensorE/`.
  Scripts can pause it, step it, move the GPS position and set its time.
- **SensorL** replaces the sensor API with a recorded flight log (for
  example `Log/20190926/16-56-45.log`). Only one of SensorE and SensorL
  can run at a time.
- **FakeFW** is a fake DC/DS firmware written in Lua. It loads apps,
  runs them with a virtual clock (much faster than real time), plays a
  chosen TX (a *device profile*), keeps tests away from the pilot's
  working files, and reports CPU use. It runs under a JETI-like desktop
  Lua (32-bit numbers, like the TX), so arithmetic behaves as on the TX.

**Which to use when**

| You want to... | Use |
|---|---|
| watch it, or check things only a person can judge ("did the map zoom in?") | the emulator, by hand |
| run a script unattended, quickly, on every push | FakeFW (`fakefw-uid.lua`) |
| check behaviour on a TX you don't have (DS-24 fw 5.08, DS-16) | FakeFW with that profile |
| find out what a real TX does | neither: run EnvDump, FontDump or GpsTest on the TX |

The same script runs in both places. Steps that need a person (`confirm`)
are skipped under FakeFW and counted as *skipped*, never passed.

---

## 2. Quick start

### 2.1 One-time setup

1. **The JETI-like Lua.** FakeFW needs Lua 5.3.1 built with `LUA_32BITS`
   and `LUA_FLOORN2I`, with the `type()` fix:
   `~/lua-5.3.1-Jeti-typefix/src/lua`. (CI builds `fazzone/lua_jeti` with
   `FakeFW/test/ltm-typefix.patch` instead.)
2. **The C helper.** Build it once, and again whenever that Lua changes:
   ```sh
   sh FakeFW/build.sh            # makes FakeFW/fakefw_c.so (gitignored)
   ```
   It supplies GPS maths in doubles (as the TX does), the wall clock and
   sleep.
3. **App links.** Apps load from `Apps/<App>.lua`, a gitignored link to
   the app's folder. `run-tests.sh` makes the ones it needs; for others:
   ```sh
   ln -s DFM-Maps/DFM-Maps.lua DFM-Maps.lua
   ```

### 2.2 Run the whole suite

From the emulator folder (the parent of `Apps/`):

```sh
cd ~/.config/JETI-Studio/Emulator
Apps/FakeFW/test/run-tests.sh            # optional argument: path to a lua
```

Each test prints `PASS:` or `FAIL:`. The exit code is the number of
failures. CI (`.github/workflows/main.yml`) runs the same script on every
push to dev, beta and master, and on pull requests. A push to beta or
master deploys only if the tests pass.

### 2.3 Run one script under FakeFW

```sh
cd ~/.config/JETI-Studio/Emulator
~/lua-5.3.1-Jeti-typefix/src/lua Apps/FakeFW/fakefw-uid.lua \
    --app DFM-Maps --script nofly-test.jsn \
    --fixture maps-bds458 --model FakeFW
```

The console shows every log line (`[UID] ...`), then the
`==== DONE: n steps run, n PASS, n FAIL ... ====` line, then FakeFW's
report (CPU per callback, serial traffic, `RESULT: PASS/FAIL`). The exit
code is 0 only if the script finished with no FAIL and no app raised an
error. Add `--keep` to keep the run folder (and print where it is), or
`--out file` to copy the result log out.

### 2.4 Run the same script in the emulator

1. Add UIDriver, SensorE (or SensorL) and the target to the model's Lua
   apps in the emulator.
2. Open **Applications > UIDriver**, pick the App, the Script and Mode
   *play*, then leave the menu. The choice is saved in
   `UIDriver/selection.jsn`.
3. If the script starts with `waitForm`, open the target's menu yourself.
   Nobody can open a form from Lua.
4. Watch it run. The step counter shows in the form title. Results are
   in `Apps/<App>/UIDriver/result.log` and in the emulator's console.
5. Set Mode back to *off* when you're done, or the script runs again the
   next time the apps load.

Mode *record* writes your own key presses and widget changes to
`rec-<date>-<time>.jsn`, a playable script. It's a quick way to start a
new test.

---

## 3. Writing a test

### 3.1 Where things go

```
Apps/<App>/
  UIDriver/
    my-test.jsn       the script
    config.jsn        optional settings for this app's scripts
    result.log        written by each run (gitignored)
  SensorE/            this app's SensorE configs (optional; variants in subfolders)
FakeFW/
  fixtures/<name>/    test data, laid out like the SD card (see 3.5)
  test/run-tests.sh   add the new test here so CI runs it
```

Test data never goes inside an app folder except `UIDriver/` and
`SensorE/`. The release build copies app folders whole, so anything else
there would ship to pilots.

### 3.2 A script, step by step

A script is `{"steps": [ ... ]}`, one object per step, run in order. Here
is the start of `DFM-Maps/UIDriver/nofly-test.jsn`, with what each part
does:

```json
{"steps": [
  {"log": "DFM-Maps no-fly test: field BDS458 or BDS320 ..."},
  {"waitForm": true},
  {"waitSub": 1},
  {"waitMessage": "Current location", "anyTime": true},
  {"expectState": "maps.activeField", "oneOf": ["BDS458", "BDS320"]},
  {"expectState": "noFly.polygons", "value": 2},
```

- `log` writes a line to the result log. Use it to explain each part of
  the test: it's the only commentary a JSON script can have.
- `waitForm` waits for the target's menu to open. In the emulator you
  open it; under FakeFW the runner opens it at 1 s.
- `waitSub` waits for a subform; `waitMessage` waits for a
  `system.messageBox`. `anyTime` accepts one that came before this step.
- `expectState` reads the app's internals through a hook the app exposes
  (see 3.3). `oneOf` accepts any of several values.

```json
  {"link": "Settings >>"},
  {"waitSub": 6},
  {"set": "Show No Fly Zones", "value": true},
  {"link": "<<< Back to main menu"},
  {"waitSub": 1},
  {"key": "KEY_ESC"},
  {"waitClosed": true},
  {"waitTelem": 1},
```

- Widgets are found by the label in their row (`form.addLabel`), links
  by their text. If a label isn't found, the log lists the labels that
  are on the form.
- `set` feeds a value through the widget's own change callback, as the
  firmware does when a person edits it.
- `key` presses a key in the form; `waitClosed` waits until the form has
  closed; `waitTelem` waits until telemetry window 1 is showing.

```json
  {"setInput": "P8", "value": -1},
  {"sensorPause": true},
  {"sensorPosition": {"lat": "41.340050", "lon": "-74.430933"}},
  {"wait": 2000},
  {"expectState": "noFly.inside", "value": false},
  {"sensorPosition": {"lat": "41.339862375", "lon": "-74.429253371", "east": -3}},
  {"waitAudio": "no_fly"},
  {"waitVibration": "left", "profile": 3},
```

- `setInput` moves a stick or slider, for the target and for SensorE.
  Here P8 is SensorE's speed slider.
- `sensorPause` freezes SensorE; `sensorPosition` holds the GPS at a
  point, optionally offset in metres. Write lat/lon as strings (see 6.3).
- `waitAudio` and `waitVibration` wait for the target to announce
  something. Add `"absent": true, "for": "3s"` to require that nothing
  comes.

To find what is on the screen while writing a script, use
`{"dumpText": true}`. It logs every text and image of the next frame with
its x, y.

### 3.3 Letting the app show its internals (app hooks)

Many checks are easier against the app's own variables than against
pixels. The app exposes them only when UIDriver is present. On a TX
`system.UIDriver` is nil, so the cost there is one nil test:

```lua
local function init()
   ...
   local uid = system.UIDriver
   if uid then
      uid.expose("maps", function()
         return {activeField = activeField, imageWidth = Screen.image_width_px}
      end)
   end
end
```

- `expose(name, getter)`: scripts read `"maps.activeField"` with
  `expectState`, `remember` or `onlyIf`. The getter runs only when a step
  asks.
- `check(cond, msg)`: an in-app assertion. A false `cond` is a FAIL
  charged to the step that was running.
- `event(name, value)`: something happened (an image loaded, a lap
  ended). Scripts wait for it with `waitEvent`.

Keep hooks free of side effects. They don't run on the TX, so a hook that
changes something makes the emulator behave differently from the TX.

### 3.4 Steps that only apply to some TXs: `onlyIf`

Any step can carry `onlyIf`. If the app state doesn't match, the step is
logged as SKIP, with the reason. For example, DFM-Maps draws Mag: and
Width: only with the 458 px maps, and fw 5.08 has no telemetry buttons:

```json
{"expectText": "Mag:", "win": 1, "onlyIf": {"state": "maps.imageWidth", "value": 458}},
{"telemButton": "NoFly", "onlyIf": {"state": "maps.telemButtons", "value": true}},
```

Skip a whole group of steps together if they depend on each other: if a
step moves the GPS into a zone, the step that expects the "leaving"
announcement must be skipped with it.

### 3.5 Test data: fixtures and settings presets

Under `fakefw-uid.lua` an app never sees the pilot's working files
(`M-*.jsn` settings, maps, logs, `selection.jsn`). Reads come from three
*layers*, first match wins:

1. the run folder, a temp folder holding everything this run wrote;
2. the fixtures named with `--fixture`, in the order given;
3. the files under `Apps/` that git doesn't ignore: code, Lang, audio,
   App.json, committed test data.

Writes always go to the run folder, so a test can't change the working
data. CI sees exactly the same files, because it has only what git has.

There are two kinds of fixture, each in `FakeFW/fixtures/<name>/`, laid
out like the SD card (`Apps/DFM-Maps/...`):

- **Field data**, made from the working data by a script:
  `sh FakeFW/fixtures/maps-bds.sh 458` makes `maps-bds458` (the Black
  Dirt field with the 458 px maps), and `... 320` makes `maps-bds320`.
  Field data only, no settings.
- **Settings presets**, written by hand, holding only the settings the
  test needs. `maps-tri/Apps/DFM-Maps/M-FakeFW.jsn` is just
  `{"triEnabled": true}`; the app's init defaults fill in the rest.

Stack them, preset first: `--fixture maps-tri,maps-bds458`. Fixtures use
the model name `FakeFW` (`--model FakeFW`), never the pilot's own.

**To find out what an app needs**, run it with `--trace` and no fixture.
Every file access is logged as `run`, `fixture`, `apps`, `hidden` or
`missing`. The `hidden` lines are working files the app wanted: those
are what a fixture has to supply.

### 3.6 Choosing a TX: device profiles

`-p <profile>` picks the TX FakeFW plays. List them with
`lua Apps/FakeFW/fakefw.lua -p list`:

| Profile | Plays | Source of the numbers |
|---|---|---|
| `emu-ds24ii-606` (default) | the JETI Studio 6.06 emulator as a DS-24 II | EnvDump, FontDump, GpsTest on the emulator |
| `ds24ii-606` | a real DS-24 II on 6.06 | partly guessed; Harry's FontDump/EnvDump still to come |
| `ds24-508` | a DS-24 on fw 5.08 | EnvDump, FontDump, GpsTest on the pilot's TX |
| `ds16-506` | a mono DS-16 on 5.06 | EnvDump, FontDump on the pilot's TX |

A profile sets:
- the device name and the emulator flag;
- screen, form and telemetry window sizes;
- key and font constants;
- `gps.getString` (6.06) or `getStrig` (5.08);
- `declareGlobal` and off-screen rendering (DS-24 II only);
- which libraries an app can see. A real TX has no `debug`, `os` or
  `coroutine`; the emulator has them.
- string collation, `package.path`, and where the clock starts.

TX profiles report "not the emulator" to `getDeviceType()`. UIDriver,
SensorE and SensorL check `system.FakeFW`, which FakeFW sets, so they
still run on TX profiles.

A test that matters on both TX generations should run on both, as the
Maps tests do (`maps-bds458` on `emu-ds24ii-606`, `maps-bds320` on
`ds24-508`). Expect some steps to need `onlyIf` (see 3.4).

### 3.7 More than one app, controls and sensors

```sh
... fakefw-uid.lua --app DFM-TimG --script hud-test.jsn --sensor SensorL \
    --also DFM-HUD --controls P5=-0.5,P6=0.1,SA=-1 --target-first --form Geriatric
```

- `--sensor SensorE|SensorL|none` picks the sensor app (default SensorE).
  SensorL replays the log named in the app's `UIDriver/config.jsn`
  (`"sensorLog"`); SensorE uses the app's `SensorE/` config, or
  `"sensorConfig"` there.
- `--also A,B` loads more apps after the target. Here DFM-HUD reads
  TimG's shared times.
- `--controls` sets sticks, sliders and switches (-1..1; unset ones read 0).
- `--target-first` starts the target before the sensor app and UIDriver.
- `--form <label>` names the form to open when the label differs from
  the app name; `--no-form` opens none. An app that does its work only
  while its form is closed (DFM-HUD sending gauges) needs `--no-form`.

### 3.8 Faking hardware on a serial port

`--serial PORT=DEVICE` attaches `FakeFW/devices/DEVICE.lua` to a serial
port. Without one, every port is a *null device*: it opens, accepts
writes and throws them away, and nothing is ever read, so an app runs as
if its hardware were plugged in. The run report shows the bytes written
to each port.

`engo` plays Russell's ESP32 bridge and the ActiveLook (Engo) glasses
behind it. It answers config list, config write, config select, battery
and version, and can send the bridge's disconnect, touch and
flow-control messages as timed events. Its state is exposed to the
script as `engo`:

```json
{"waitMessage": "Transfer complete", "anyTime": true, "timeout": "40s"},
{"expectState": "engo.lastWrite", "value": "DFM-HUD v8"},
{"waitText": "85%", "win": 2, "timeout": "20s"},
{"expectState": "engo.counts.x05", "min": 8},
{"expectState": "engo.bad", "value": 0},
```

DFM-HUD opens `ttyUSB0` in the emulator and `COM1` on a TX, so the port
name follows the profile (see the engo-test lines in `run-tests.sh`).

A new device is a Lua module with `new(options)` returning a table with
`attach(api)`, `write(bytes)`, and optionally `frame(now)`, `state()` and
`summary()`. `api.send(bytes)` queues bytes for the app's `serial.onRead`
callback; they're delivered at the start of the next frame. See the
header of `fakefw.lua` (`FW.serialDevice`) and `devices/engo.lua`.

### 3.9 Adding the test to CI

Add a block to `FakeFW/test/run-tests.sh`, following the existing ones:
run the runner, call `ok` with the DONE line on success, and on failure
call `bad` and show the tail of the output. Run the suite locally, then
push to dev and check the run with `gh run list --branch dev` and
`gh run view <id> --log`.

---

## 4. Script language: steps by task

This section is a map; the full detail of every step and option is in the
header of `UIDriver/UIDriver.lua`.

| Task | Steps |
|---|---|
| Wait for the UI | `waitForm`, `waitSub`, `waitClosed`, `waitTelem`, `wait` |
| Operate the form | `set`, `expect`, `expectSub`, `link`, `key`, `button`, `answer`, `close`, `restore` |
| Telemetry windows | `telemKey`, `telemButton`, `expectTelemButton` |
| Read the screen | `expectText`, `expectNoText`, `waitText`, `expectImage`, `expectNoImage`, `waitImage`, `dumpText` (`"win": 1`, `"region"`, `"exact"`) |
| App internals | `expectState` (`value`, `min`/`max`, `tol`, `oneOf`, `notValue`), `remember` ... `"$name"`, `waitEvent` |
| Announcements | `waitMessage`, `waitAudio`, `waitNumber`, `waitVibration`, `waitBeep` (`"absent": true, "for": "3s"`) |
| Controls | `setInput`, `clearInput`, `expectControl`, `waitControl` |
| Sensors | `setSensor` (values, `"valid": false` faults), `clearSensor`, `waitSensor`, `expectSensor` |
| SensorE / SensorL | `sensorPause`, `sensorStep`, `sensorTime`, `waitSensorTime`, `sensorPosition`, `sensorVars`, `sensorField` |
| CPU | `cpuStart`, `cpuCheck` |
| People | `confirm` (SKIP when unattended), `note` |
| Structure | `log`, `repeat`, `"onlyIf"` on any step, `"timeout"` and `"gap"` on any step |

Durations are numbers (ms) or strings with units: `"500ms"`, `"90s"`,
`"1m30s"`, `"2:55"`. Text matches ignore case and match part of the text
unless `"exact": true`. A script can carry its own `{"config": {...}}`
(step gap, default timeout, stop on fail ...), which overrides the app's
`UIDriver/config.jsn`.

**Results.** Each check logs PASS or FAIL. Other steps log `ok`.
`onlyIf` and unattended `confirm` steps log SKIP. The run ends with:

```
==== DONE: 112 steps run, 26 PASS, 0 FAIL, 69 ok, 17 skipped; app checks: 11 passed, 0 failed ====
```

"app checks" counts the app's own `uid.check` calls. A run fails if any
step FAILed, any app check failed, or the script didn't finish.

---

## 5. FakeFW reference

### 5.1 Two ways to run it

- **`fakefw-uid.lua`** runs a UIDriver script: sandboxed, with fixtures,
  pass/fail. This is the one to use for tests. Options: see its header,
  and section 3 above.
- **`fakefw.lua` directly** loads apps, runs their init, then runs them
  for `-t` seconds and prints the report:
  ```sh
  ~/lua-5.3.1-Jeti-typefix/src/lua Apps/FakeFW/fakefw.lua -p ds24-508 -t 2 EnvDump
  ```
  This runs **without** file layers: apps read and write the real files.
  That's fine for tools like EnvDump, GpsTest and FontDump, which write
  only their own output. Don't use it for an app that saves settings.

### 5.2 Writing your own driver

For something a script can't do, use FakeFW as a module (see
`fakefw-uid.lua` for a complete example):

```lua
local FW = dofile("Apps/FakeFW/fakefw.lua")
FW.setup{profile = "ds24-508", seed = 1, sandbox = true, fixture = {"maps-bds320"}}
FW.controls = {P5 = -0.5}
FW.load{"SensorE", "DFM-Maps"}
FW.initApps()
FW.onFrame(function(now) ... end)      -- every frame, before the apps' loops
FW.run(60 * 1000)                      -- 60 s of TX time
os.exit(FW.finish())                   -- report; 0 = pass
```

Other calls include `FW.openForm(label)`, `FW.key(code)`,
`FW.app(name).env` (an app's environment), `FW.superglobal(name)`,
`FW.readFile` and `FW.writeFile` (through the layers),
`FW.serialDevice(port, dev)` and `FW.fail(msg)`.

### 5.3 Time and CPU

- **The virtual clock.** FakeFW owns the clock. A frame comes every
  20–30 ms (loop period plus jitter), and forms and telemetry windows are
  redrawn every 40 ms (a guess, not measured on a TX yet). `getTimeCounter`, `getTime` and `getDateTime` all
  read the same clock, and time moves forward while Lua runs (by counting
  instructions). A 20-minute flight takes seconds. Add `--paced` to the
  direct command line to run in real time.
- **The emulator profile's clock starts negative**
  (`getTimeCounter()` begins at −1,000,000,000), as the real emulator's
  often does. TX profiles start near zero.
- **The CPU report** lists each app callback's calls, maximum and
  average time, and how often it went over the 10 ms budget (times
  `--mult`). It is **report only**: the instruction cost isn't calibrated
  against a TX yet, so nothing fails or is killed for CPU.

### 5.4 What is not modelled

- Pixels: nothing is rendered. UIDriver sees the text and images an app
  draws, not what they look like. Real fonts' sizes are modelled
  (`lcd.getTextWidth`/`getTextHeight`).
- Real telemetry timing (sensors update about every 200 ms with varying
  latency on a TX). Values come from SensorE or SensorL when they're
  asked for.
- The firmware's own form editing (rotary knob, focus): `set` calls the
  widget's callback directly.
- Calibrated CPU cost and image load times (planned: Harry's prof.log
  and ImgTest runs).
- The HUD's serial input, except through a device model (`--serial`).

---

## 6. Gotchas

### 6.1 The clock

- **Never compare `getTimeCounter()` with 0**, and never start a timer
  variable at 0 (`local nextT = 0` ... `if now > nextT`). The emulator's
  clock often starts negative, and then such a timer never fires. Start
  timers from `system.getTimeCounter()` in `init()`. Only differences
  between two readings are safe. DFM-TimG (e27fc89) and DFM-HUD 0.02
  (a0761eb) were fixed for exactly this; the engo-test found HUD's.
- `os.clock` is float32 on the TX: useless for long times.

### 6.2 TX differences that break apps

- **Key and font constants differ between firmware versions:** on 5.08
  `KEY_UP` = 256, on 6.06 it is 512. Always use the names (`KEY_UP`,
  `FONT_MINI`), never the numbers.
- **Screen width:** 320 on the DS-24 and older, 480 on the DS-24 II.
  Right-aligning with a hard-coded width breaks on one of them.
- **No `debug`, `os` or `coroutine` on a real TX.** Code like
  `os.setlocale("C")` needs a guard (`if os and os.setlocale`).
- **No telemetry buttons on 5.08** (`system.setTelemetryButton` is nil),
  and no `declareGlobal` before 6.05 (and none on the DS-24 at all).
- **`gps.getString` is spelt `gps.getStrig` on 5.08.** Use
  `(gps.getString or gps.getStrig)`.

### 6.3 Numbers

- Numbers are 32-bit floats on the TX and under FakeFW. JSON numbers
  decode as floats too: a latitude in JSON is about 0.3 m off. Keep
  coordinates as strings and pass them to `gps.newPoint`; scripts do the
  same in `sensorPosition`.
- With `LUA_FLOORN2I`, `math.tointeger` floors, and a float compared with
  an integer is floored first (`0.5 == 0` is true). Use `x % 1 == 0.0`
  to test for whole numbers.
- `string.format("%d", 2.7)` is fine on the TX (it floors); it isn't a
  crash.

### 6.4 Running tests

- **Never run a script against the working data.** Use `fakefw-uid.lua`
  (always sandboxed), not your own unsandboxed driver; Maps rewrote a
  pilot settings file that way once. In the emulator, use a test model,
  not the pilot's.
- **One emulator at a time.** Two copies share the config folder. Close
  your emulator before an unattended emulator run.
- **Don't send keystrokes to the pilot's display.** Unattended emulator
  runs go on a separate X display (Xephyr); the "Yes" button is held
  with the mouse there.
- **A script that leaves the menu stops**, unless a `waitClosed`, `note`
  or `waitForm` step is waiting. To have the tester close the form, use
  `waitClosed`.
- **Apps that keep their own copy of `lcd.drawText`**
  (`local drawText = lcd.drawText`) can't be seen by text steps.
- **Some apps stop working while their form is open** (DFM-Maps does no
  GPS or no-fly work, DFM-HUD sends no gauges). Close the form
  (`KEY_ESC` + `waitClosed`), or run FakeFW with `--no-form`.
- **Each announcement satisfies only one wait.** A `waitAudio` counts
  announcements since the last action step started, unless
  `"anyTime": true`.

---

## 7. The current suite

`FakeFW/test/run-tests.sh` runs 16 tests in about 12 s:

| Test | Checks |
|---|---|
| GpsTest on `emu-ds24ii-606` and `ds24-508` | GPS maths match the emulator's and the DS-24's output line for line |
| EnvDump on three profiles | the environment an app sees matches the measured one (constants, libraries, sizes) |
| FontDump on three profiles | text sizes match the measured fonts |
| DFM-TimG `timg-test`, `hud-test` | timer logic on the Georgia Jets log (SensorL); `hud-test` with the real DFM-HUD reading TimG's times |
| DFM-Maps `nofly-test`, `maps-smoke` | no-fly zones, announcements, stick shake, map view and triangle, on the 458 maps (emulator profile) and the 320 maps (DS-24 5.08) |
| DFM-HUD `engo-test` on `emu-ds24ii-606` and `ds24ii-606` | glasses handshake, config upload, battery polls and well-formed gauge frames, against the fake Engo glasses |
