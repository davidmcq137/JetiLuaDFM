set -e
set -x

pandoc en-main.md -f markdown -t html  -o EN-MAIN.HTML --metadata title="DFM-InsP Help" --template="jeti.html"
cp EN-MAIN.HTML ~/JSE/DOCS/DFM-INSP/

