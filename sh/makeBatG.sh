set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-BatG/DFM-BatG.lc DFM-BatG.lua
rm -f DFM-BatG.zip
zip -ru DFM-BatG.zip DFM-BatG.lc DFM-BatG
zip -ru DFMHC.zip DFM-BatG.lc DFM-BatG



