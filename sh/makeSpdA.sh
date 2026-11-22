set -e
set -x
rm -f zip/DFM-SpdA.zip
zip -ru zip/DFM-SpdA.zip DFM-SpdA.lua DFM-SpdA
zip -ru zip/DFM.zip DFM-SpdA.lua DFM-SpdA

