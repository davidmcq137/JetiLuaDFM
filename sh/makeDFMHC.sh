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
set +x
read -p "New lua files generated. Press enter after saving Apps.json file from App Builder" n1
set -x
cd ~
zip -ru ~/JS/DFMHC.zip Apps.json
