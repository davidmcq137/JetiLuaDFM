set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/DFM-F3G.lc DFM-F3G/DFM-F3G.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/menuCmd.lc DFM-F3G/menuCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/initCmd.lc DFM-F3G/initCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/fullTele.lc DFM-F3G/fullTele.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/doubleTele.lc DFM-F3G/doubleTele.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3G/teleCmd.lc DFM-F3G/teleCmd.lua
rm -f DFM-F3G.zip
zip -ru DFM-F3G.zip DFM-F3G.lua DFM-F3Gm.lc DFM-F3G
