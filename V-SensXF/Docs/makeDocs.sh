set -e
set -x
pandoc en-reshelp.md -f markdown -t html  -o EN-RESHELP.HTML --metadata title="Result Expressions" --template="jeti.html"
cp EN-RESHELP.HTML ~/JSE/DOCS/V-SENSXF/

pandoc en-mainhelp.md -f markdown -t html  -o EN-MAINHELP.HTML --metadata title="V-SensXF Help" --template="jeti.html"
cp EN-MAINHELP.HTML ~/JSE/DOCS/V-SENSXF/

pandoc en-exp-gratio.md -f markdown -t html  -o EN-EXP-GRATIO.HTML --metadata title="V-SensXF Help" --template="jeti.html"
cp EN-EXP-GRATIO.HTML ~/JSE/DOCS/V-SENSXF/

pandoc en-exp-power.md -f markdown -t html  -o EN-EXP-POWER.HTML --metadata title="V-SensXF Help" --template="jeti.html"
cp EN-EXP-POWER.HTML ~/JSE/DOCS/V-SENSXF/

pandoc en-exp-noflyout.md -f markdown -t html  -o EN-EXP-NOFLYOUT.HTML --metadata title="V-SensXF Help" --template="jeti.html"
cp EN-EXP-NOFLYOUT.HTML ~/JSE/DOCS/V-SENSXF/

pandoc en-exp-noflyin.md -f markdown -t html  -o EN-EXP-NOFLYIN.HTML --metadata title="V-SensXF Help" --template="jeti.html"
cp EN-EXP-NOFLYIN.HTML ~/JSE/DOCS/V-SENSXF/
