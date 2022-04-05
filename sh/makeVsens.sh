set -e
set -x
cd ~/JS/V-SensXF/Docs
sh makeDocs.sh
cd ~/JS
rm -f DFM-VsensXF.zip
zip -ru V-SensXF.zip V-SensXF.lua V-SensXF.lc V-SensXF
