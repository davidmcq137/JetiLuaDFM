set -e
set -x
cd ~/JS/V-SensXF/Docs
sh makeDocs.sh
cd ~/JS
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o V-SensXF/V-SensXF.lc V-SensXF.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o V-SensXF/V-Ann.lc V-Ann.lua
rm -f zip/DFM-VsensXF.zip
zip -ru zip/V-SensXF.zip V-SensXF.lc V-Ann.lc V-SensXF
zip -ru zip/DFMHC.zip V-SensXF.lc V-Ann.lc V-SensXF

