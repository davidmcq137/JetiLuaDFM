set -e
set -x
set -v
rm -f DFM-RMon.zip
zip -ru DFM-RMon.zip DFM-RMon.lua DFM-RMon
zip -ru DFM.zip DFM-RMon.lua DFM-RMon

