set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-Dial/DFM-Dial.lc DFM-Dial.lc
rm -f DFM-Dial.zip
zip -ru DFM-Dial.zip DFM-Dial.lc DFM-Dial
# zip -ru DFMHC.zip DFM-BatG.lc DFM-BatG



