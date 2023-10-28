set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3Gb/DFM-F3Gb.lc DFM-F3Gb/DFM-F3Gb.lua
rm -f DFM-F3Gb.zip
zip -ru DFM-F3Gb.zip DFM-F3Gb.lc DFM-F3Gb -x DFM-F3Gb/GPS.jsn

