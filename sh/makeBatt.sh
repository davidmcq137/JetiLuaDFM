set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-Batt/DFM-Batt.lc DFM-Batt.lua
rm -f DFM-Batt.zip
zip -ru DFM-Batt.zip DFM-Batt.lc DFM-Batt
zip -ru DFMHC.zip DFM-Batt.lc DFM-Batt



