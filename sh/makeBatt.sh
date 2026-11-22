set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-Batt/DFM-Batt.lc DFM-Batt.lua
rm -f zip/DFM-Batt.zip
zip -ru zip/DFM-Batt.zip DFM-Batt.lc DFM-Batt
zip -ru zip/DFMHC.zip DFM-Batt.lc DFM-Batt



