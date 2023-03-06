set -e
set -x
rm -f DFM-GRat.zip
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GRat/DFM-GRG1.lc DFM-GRat/DFM-GRat.lua
zip -ru DFM-GRat.zip DFM-GRat/DFM-GRat.lua DFM-GRat/DFM-GRG1.lc DFM-GRat
zip -ru DFMHC.zip DFM-GRat/DFM-GRat.lua DFM-GRat



