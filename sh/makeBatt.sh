set -e
set -x
rm -f DFM-Batt.zip
zip -ru DFM-Batt.zip DFM-Batt.lua DFM-Batt -x DFM-Batt/BD*
zip -ru DFMHC.zip DFM-Batt.lua DFM-Batt

