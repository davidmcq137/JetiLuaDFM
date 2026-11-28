# Claude sessions: one per app

Written 2026-11-27 at the user's request, for every Claude Code session that
works on this repo (the Linux sessions and the Mac session on the iOS app).

## What we are doing

The user runs **one Claude Code session per app**, named after it:

| Session | Machine | Covers |
|---|---|---|
| DFM-Maps | Linux | DFM-Maps / DFM-MapsL, the Maps side of jetiluadfm.app |
| DFM-InsP | Linux | DFM-InsP and its tests |
| DFM-Rscu | Linux | DFM-Rscu and its flight tests with Harry |
| DFM-BLE | Linux | DFM-BLE (TX side) and the ESP32 bridge (~/dfmBleESP) |
| iOS app (dfmBleApp) | Mac | the iOS app; ports of app logic (e.g. InsP variables) |

New sessions for other apps follow the same pattern. Shared tools (TestMitter,
SensorE, SensorL, UIDriver, `TestMX/test/run-tests.sh`) have no session of
their own; the app session that needs a change makes it.

## How to proceed

1. **One session active at a time.** All Linux sessions share one working
   tree (`~/JS`, seen as `~/.config/JETI-Studio/Emulator/Apps`) and the `dev`
   branch, and one memory folder. The user switches sessions by saying so
   ("I am going over to DFM-BLE now").
2. **Start from your app's START HERE note** in memory (e.g.
   `dfm-maps-start-here.md`). Before the user switches away, bring it up to
   date: version, what's done, what's open.
3. **Before editing, run `git status`.** Another session may have left work in
   progress. Commit only the files your session changed, and commit or push
   only when the user asks.
4. **Changing a shared tool:** run the whole suite (`run-tests.sh`), and say
   what changed in the commit message so the other sessions see it.
5. **Work for another app** noticed in your session (e.g. an InsP bug found
   while working on Maps): fix it only if it's small and the user asks.
   Otherwise leave a memory note for that app's session.
6. **Between the Mac and Linux:** the sessions don't share memory. Hand work
   over in `Docs/handoff-<topic>.md` (as `handoff-insp-variable-units.md`
   did), committed and pushed, and reply in `handoff-<topic>-reply.md`.
7. **Pilot apps** (Maps, InsP, Rscu, ...): no code change without the user's
   OK; a new version letter per push that changes the app.
8. **Emulator:** don't drive the user's display (:1); use a separate X display.
   For a single TestMitter run, create `Apps/<App>.lua` only if it's missing,
   and remove only a link you created.

## Where things are

- Memory (Linux): `~/.claude/projects/-home-davidmcq--config-JETI-Studio-Emulator-Apps/memory/`,
  index `MEMORY.md`, its own git repo (push on request).
- Handoffs between machines: `Docs/handoff-*.md` in this repo.
- Tests: `TestMX/test/run-tests.sh`; each app's UIDriver scripts are in
  `<App>/UIDriver/`, fixtures in `TestMX/fixtures/`.
