set -e
set -x
pandoc reshelp.md -f markdown -t html  -o RESHELP.HTML --metadata title="Result Expressions" --template="jeti.html"
cp RESHELP.HTML ~/JSE/DOCS/V-SENSXF/
