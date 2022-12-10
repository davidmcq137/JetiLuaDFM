set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-TimV/DFM-TimV.lc DFM-TimV/DFM-TimV.lua
rm -f DFM-TimV.zip
zip -ru DFM-TimV.zip DFM-TimV.lc DFM-TimV
zip -ru DFMHC.zip DFM-TimV.lc DFM-TimV
