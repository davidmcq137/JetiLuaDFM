FakeFW fixtures: test data for FakeFW runs, kept out of the working data.

Each folder is laid out like a TX's SD card (Apps/<App>/...) and uses the
model name FakeFW (M-FakeFW.jsn, MF-FakeFW.jsn-<field>.jsn), so a run never
needs the pilot's own files. FakeFW reads a run's files from its temp run
folder, then the fixtures in the order given (the first one that has a
file wins), then the Apps files git doesn't ignore; gitignored working
data is hidden. Everything lives under FakeFW/ because the release build
copies each app's folder whole: test data in an app folder would ship.

Kinds:
- field data, made from the working data by a script of the same name
  (maps-bds.sh 458 or 320 makes maps-bds458 or maps-bds320): the map
  set and images, no settings
- settings presets, written by hand, holding only the settings a test
  needs (maps-tri: {"triEnabled": true}); Maps fills in the rest from its
  init defaults. List them first: --fixture maps-tri,maps-bds458

To find what an app reads: run it with an empty fixture and --trace;
"hidden" lines are working files it wanted.
