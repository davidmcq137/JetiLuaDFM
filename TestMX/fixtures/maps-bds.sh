#!/bin/sh
# Make the TestMitter fixture maps-bds458 or maps-bds320 from the working data:
# the Black Dirt Squadron field with the 458 px maps (DS-24 II) or the 320 px
# maps (DS-24, older TXs), as sh/to458.sh or sh/to320.sh would leave
# DFM-Maps/Maps. Field data only: no settings file, so Maps starts on its
# init defaults. Settings come from small preset fixtures listed before it
# (e.g. --fixture maps-tri,maps-bds458), each holding only the settings a
# test needs; maps-tri is written by hand.
#
# Run from Apps:  sh TestMX/fixtures/maps-bds.sh 458    (or 320)
# It rebuilds TestMX/fixtures/maps-bds<size>/ (laid out like the SD card)
# and never changes the working files. The file list came from a TestMitter run
# with trace on and an empty fixture: what DFM-Maps reads that git ignores.
set -e
SIZE=${1:?usage: sh TestMX/fixtures/maps-bds.sh 458|320}
case $SIZE in 458|320) ;; *) echo "size must be 458 or 320"; exit 1 ;; esac
SRC=DFM-Maps
FIX=TestMX/fixtures/maps-bds$SIZE
OUT=$FIX/Apps/DFM-Maps
rm -rf "$FIX"
mkdir -p "$OUT/Maps"

# the map set, as sh/to$SIZE.sh switches it
cp "$SRC/Maps/Config$SIZE.jsn" "$OUT/Maps/Config.jsn"
cp "$SRC/Maps/Fields$SIZE.jsn" "$OUT/Maps/Fields.jsn"
# the field's map images, one per zoom level (Fields.jsn names the folder)
mkdir -p "$OUT/Maps/BDS$SIZE"
cp "$SRC"/Maps/BDS$SIZE/*.png "$OUT/Maps/BDS$SIZE/"

echo "made $FIX:"
find "$FIX" -type f | sort
