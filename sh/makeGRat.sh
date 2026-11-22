set -e
set -x
rm -f zip/DFM-GRat.zip
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GRat/DFM-GRG1.lc DFM-GRat/DFM-GRat.lua
zip -ru zip/DFM-GRat.zip DFM-GRat/DFM-GRat.lua DFM-GRat/DFM-GRG1.lc DFM-GRat
zip -ru zip/DFMHC.zip DFM-GRat/DFM-GRat.lua DFM-GRat



