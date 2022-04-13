set -e
set -x
rm -f DFMHC.zip
cd ~
zip -ru ~/JS/DFMHC.zip Apps.json
cd ~/JS
sh sh/makeCrow.sh
sh sh/makeSWT.sh
sh sh/makeGRat.sh
sh sh/makeWatt.sh
sh sh/makeAmix.sh
sh sh/makeVsens.sh
