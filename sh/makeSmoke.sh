set -e
set -x
rm -f DFM-Smoke.zip
zip -ru DFM-Smoke.zip DFM-Smoke.lua DFM-Smoke
zip -ru DFM.zip DFM-Smoke.lua DFM-Smoke

