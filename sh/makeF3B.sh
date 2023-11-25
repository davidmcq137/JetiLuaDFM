set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3B/DFM-F3B.lc DFM-F3B/DFM-F3B.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3B/readSensors.lc DFM-F3B/readSensors.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3B/fieldPopUp.lc DFM-F3B/fieldPopUp.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3B/initVars.lc DFM-F3B/initVars.lua
rm -f DFM-F3B.zip
zip -ru DFM-F3B.zip DFM-F3B.lc DFM-F3B -x DFM-F3B/GPS.jsn

