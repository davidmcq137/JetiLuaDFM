set -e
set -x
rm -f DFM-FltE.zip
zip -ru DFM-FltE.zip DFM-FltE.lua DFM-FltE
cd ~/JSE
rm -f DOCS.zip
zip -ru DOCS.zip DOCS
cd ~/JS
cp -rv ~/JSE/DOCS.zip .







