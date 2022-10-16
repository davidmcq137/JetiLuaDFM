#!/bin/bash
set -e
set -x
rm -f DFMHC.zip
cd ~/JS
sh sh/makeCrow.sh
sh sh/makeSWT.sh
sh sh/makeGRat.sh
sh sh/makeWatt.sh
sh sh/makeAmix.sh
sh sh/makeVsens.sh
sh sh/makeBatt.sh
# we don't want the test versions of the .jsn files in the distro .. temp rename them then put back later
for f in DFM-BatG/BD_*.jsn; do
    mv -- "$f" "${f%.jsn}.jxx"
done
sh sh/makeBatG.sh
set +x
read -p "New lua/lc files generated. Press enter after saving Apps.json file from App Builder" n1
set -x
cd ~
zip -ru ~/JS/DFMHC.zip Apps.json
for f in DFM-BatG/BD_*.jxx; do
    mv -- "$f" "${f%.jxx}.jsn"
done
