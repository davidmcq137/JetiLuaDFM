set -e
set -x
rm -f DFM-SpdA.zip
zip -ru DFM-SpdA.zip DFM-SpdA.lua DFM-SpdA
zip -ru DFM.zip DFM-SpdA.lua DFM-SpdA

