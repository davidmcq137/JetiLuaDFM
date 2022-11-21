set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/DFM-GPSm.lc DFM-GPS/DFM-GPS.lua
rm -f DFM-GPS.zip
zip -ru DFM-GPS.zip DFM-GPS.lua DFM-GPSm.lc DFM-GPS

