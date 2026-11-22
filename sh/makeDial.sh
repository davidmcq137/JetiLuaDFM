set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -o DFM-Dial/DFM-Dial.lc DFM-Dial.lua
rm -f zip/DFM-Dial.zip
zip -ru zip/DFM-Dial.zip DFM-Dial.lc DFM-Dial
zip -ru zip/DFMHC.zip DFM-Dial.lc DFM-Dial



