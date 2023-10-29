set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3B/DFM-F3B.lc DFM-F3B/DFM-F3B.lua
rm -f DFM-F3B.zip
zip -ru DFM-F3B.zip DFM-F3B.lc DFM-F3B -x DFM-F3B/GPS.jsn

