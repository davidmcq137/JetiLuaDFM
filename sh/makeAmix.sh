set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-Amix/DFM-Amix.lc DFM-Amix.lua
rm -f zip/DFM-Amix.zip
zip -ru zip/DFM-Amix.zip DFM-Amix.lc DFM-Amix
zip -ru zip/DFMHC.zip DFM-Amix.lc DFM-Amix

