set -e
set -x
cd ~/JS/V-SensXF/Docs
sh makeDocs.sh
cd ~/JS
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o V-SensXF.lc V-SensXF.lua
rm -f DFM-VsensXF.zip
zip -ru V-SensXF.zip V-SensXF.lua V-SensXF.lc V-SensXF
