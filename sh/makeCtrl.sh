set -e
set -x
rm -f zip/DFM-Ctrl.zip
zip -ru zip/DFM-Ctrl.zip DFM-Ctrl.lua DFM-Ctrl
zip -ru zip/DFM.zip DFM-Ctrl.lua DFM-Ctrl



