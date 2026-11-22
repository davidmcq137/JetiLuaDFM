set -e
set -x
set -v
rm -f zip/DFM-RMon.zip
zip -ru zip/DFM-RMon.zip DFM-RMon.lua DFM-RMon
zip -ru zip/DFM.zip DFM-RMon.lua DFM-RMon

