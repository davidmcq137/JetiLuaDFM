set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -o DFM-Temp/DFM-Temp.lc DFM-Temp.lua
rm -f DFM-Temp.zip
zip -ru DFM-Temp.zip DFM-Temp.lc DFM-Temp
zip -ru DFMHC.zip DFM-Temp.lc DFM-Temp
