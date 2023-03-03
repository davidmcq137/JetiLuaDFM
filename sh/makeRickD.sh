set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -o DFM-InsP/DFM-InsP.lc DFM-InsP.lua
rm -f RickD.zip
zip -ru RickD.zip DFM-InsP.lc DFM-InsP
