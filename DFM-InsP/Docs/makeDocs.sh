set -e
set -x

pandoc en-main.md -f markdown -t html  -o EN-MAIN.HTML --metadata title="DFM-InsP Help" --template="jeti.html"
cp EN-MAIN.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-settings.md -f markdown -t html  -o EN-SETTINGS.HTML --metadata title="DFM-InsP Settings Help" --template="jeti.html"
cp EN-SETTINGS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-inputs.md -f markdown -t html  -o EN-INPUTS.HTML --metadata title="DFM-InsP Inputs Help" --template="jeti.html"
cp EN-INPUTS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editpanel.md -f markdown -t html  -o EN-EDITPANEL.HTML --metadata title="DFM-InsP Edit Panel Help" --template="jeti.html"
cp EN-EDITPANEL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editlinks.md -f markdown -t html  -o EN-EDITLINKS.HTML --metadata title="DFM-InsP Edit Links Help" --template="jeti.html"
cp EN-EDITLINKS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-luavariables.md -f markdown -t html  -o EN-LUAVARIABLES.HTML --metadata title="DFM-InsP Lua Variables Help" --template="jeti.html"
cp EN-LUAVARIABLES.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-resetall.md -f markdown -t html  -o EN-RESETALL.HTML --metadata title="DFM-InsP Reset All Help" --template="jeti.html"
cp EN-RESETALL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editlua.md -f markdown -t html  -o EN-EDITLUA.HTML --metadata title="DFM-InsP Edit Lua Expressions Help" --template="jeti.html"
cp EN-EDITLUA.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-inputs.md -f markdown -t html  -o EN-INPUTS.HTML --metadata title="DFM-InsP Edit Inputs Help" --template="jeti.html"
cp EN-INPUTS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-more.md -f markdown -t html  -o EN-MORE.HTML --metadata title="DFM-InsP Lua Variables - More" --template="jeti.html"
cp EN-MORE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-harryCBdial.md -f markdown -t html  -o EN-HARRYCBDIAL.HTML --metadata title="Harry C. CB Dial Panel" --template="jeti.html"
cp EN-HARRYCBDIAL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-HarryElectric.md -f markdown -t html  -o EN-HARRYELECTRIC.HTML --metadata title="Harry C. Electric Panel" --template="jeti.html"
cp EN-HARRYELECTRIC.HTML ~/JSE/DOCS/DFM-INSP/
