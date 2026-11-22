set -e
set -x
rm -f zip/DFM-Crow.zip
zip -ru zip/DFM-Crow.zip DFM-Crow.lc DFM-Crow
zip -ru zip/DFMHC.zip DFM-Crow.lc DFM-Crow

