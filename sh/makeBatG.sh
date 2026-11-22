set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-BatG/DFM-BatG.lc DFM-BatG.lua
rm -f zip/DFM-BatG.zip
zip -ru zip/DFM-BatG.zip DFM-BatG.lc DFM-BatG
zip -ru zip/DFMHC.zip DFM-BatG.lc DFM-BatG



