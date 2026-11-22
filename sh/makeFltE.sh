set -e
set -x
rm -f zip/DFM-FltE.zip
zip -ru zip/DFM-FltE.zip DFM-FltE.lua DFM-FltE
cd ~/JSE
rm -f zip/DOCS.zip
zip -ru zip/DOCS.zip DOCS
cd ~/JS
cp -rv ~/JSE/DOCS.zip .







