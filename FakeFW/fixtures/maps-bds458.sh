#!/bin/sh
# Make the FakeFW fixture maps-bds458 from the working data: the Black Dirt
# Squadron field with the 458 px maps (the DS-24 II size), as sh/to458.sh
# would leave DFM-Maps/Maps. Field data only: no settings file, so Maps
# starts on its init defaults. Settings come from small preset fixtures
# listed before it (e.g. --fixture maps-tri,maps-bds458), each holding only
# the settings a test needs; maps-tri is written by hand.
#
# Run from Apps:  sh FakeFW/fixtures/maps-bds458.sh
# It rebuilds FakeFW/fixtures/maps-bds458/ (laid out like the SD card) and
# never changes the working files. The file list came from a FakeFW run
# with trace on and an empty fixture: what DFM-Maps reads that git ignores.
set -e
SRC=DFM-Maps
OUT=FakeFW/fixtures/maps-bds458/Apps/DFM-Maps
rm -rf FakeFW/fixtures/maps-bds458
mkdir -p "$OUT/Maps"

# the 458 px map set, as sh/to458.sh switches it
cp "$SRC/Maps/Config458.jsn" "$OUT/Maps/Config.jsn"
cp "$SRC/Maps/Fields458.jsn" "$OUT/Maps/Fields.jsn"
# the field's map images, one per zoom level (Fields.jsn names the folder)
mkdir -p "$OUT/Maps/BDS458"
cp "$SRC"/Maps/BDS458/*.png "$OUT/Maps/BDS458/"

echo "made FakeFW/fixtures/maps-bds458:"
find FakeFW/fixtures/maps-bds458 -type f | sort
