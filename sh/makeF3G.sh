set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/DFM-F3G.lc DFM-F3G/DFM-F3G.lua
rm -f DFM-F3G.zip
zip -ru DFM-F3G.zip DFM-F3G.lua DFM-F3G





