set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/DFM-F3X.lc DFM-F3X/DFM-F3X.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/menuCmd.lc DFM-F3X/menuCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/initCmd.lc DFM-F3X/initCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/fullTele.lc DFM-F3X/fullTele.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/doubleTele.lc DFM-F3X/doubleTele.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-F3X/teleCmd.lc DFM-F3X/teleCmd.lua
rm -f DFM-F3X.zip
zip -ru DFM-F3X.zip DFM-F3X.lua DFM-F3Xm.lc DFM-F3X

