set -e
set -x
rm -f zip/DFM-Smoke.zip
zip -ru zip/DFM-Smoke.zip DFM-Smoke.lua DFM-Smoke
zip -ru zip/DFM.zip DFM-Smoke.lua DFM-Smoke

