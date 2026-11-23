TestMitter fixtures: test data for TestMitter runs, kept out of the working data.

Each folder is laid out like a TX's SD card (Apps/<App>/...) and uses the
model name TestMX (M-TestMX.jsn, MF-TestMX.jsn-<field>.jsn), so a run never
needs the pilot's own files. TestMitter reads a run's files from its temp run
folder, then the fixtures in the order given (the first one that has a
file wins), then the Apps files git doesn't ignore; gitignored working
data is hidden. Everything lives under TestMX/ because the release build
copies each app's folder whole: test data in an app folder would ship.

Kinds:
- field data, made from the working data by a script of the same name
  (maps-bds.sh 458 or 320 makes maps-bds458 or maps-bds320): the map
  set and images, no settings
- settings presets, written by hand, holding only the settings a test
  needs (maps-tri: {"triEnabled": true}); Maps fills in the rest from its
  init defaults. List them first: --fixture maps-tri,maps-bds458
- old files, written by an earlier version of an app, to test that a new
  version still reads them (dial-113: DFM-Dial 1.13 settings with
  [null,5] warnings; batt-25: DFM-Batt 2.5 files with cycle histories
  and a group wiped to 0; batt-moved: a model whose group moved up)
- a pilot's data, for a day's flying: batt-26 (DFM-Batt 2.6 files: groups
  Field and Glider with cycle histories, models TestMX and Other)

To find what an app reads: run it with an empty fixture and --trace;
"hidden" lines are working files it wanted.
