set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -o DFM-InsP/DFM-InsP.lc DFM-InsP.lua
rm -f zip/DFM-InsP.zip
zip -ru zip/DFM-InsP.zip DFM-InsP.lc SensorE.lua SensorE.jsn SensorE DFM-InsP




