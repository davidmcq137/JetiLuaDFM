set -e
set -x
rm -f zip/DFM.zip
cd ~
zip -ru ~/JS/zip/DFM.zip Apps.json
cd ~/JS
sh sh/makeChute.sh
sh sh/makeSpdA.sh
sh sh/makeSmoke.sh
sh sh/makeTWZ.sh
sh sh/makeCTU.sh
