set -e
set -x
pandoc mainmenu.md -f markdown -t html  -o MAINMENU.HTML --metadata title="Main Menu" --template="jeti.html"
cp MAINMENU.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc sensors.md -f markdown -t html  -o SENSORS.HTML --metadata title="Sensors" --template="jeti.html"
cp SENSORS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc analysis.md -f markdown -t html  -o ANALYSIS.HTML --metadata title="Analysis" --template="jeti.html"
cp ANALYSIS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc controls.md -f markdown -t html  -o CONTROLS.HTML --metadata title="Controls" --template="jeti.html"
cp CONTROLS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc indicators.md -f markdown -t html  -o INDICATORS.HTML --metadata title="Indicators" --template="jeti.html"
cp INDICATORS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc settings.md -f markdown -t html  -o SETTINGS.HTML --metadata title="Settings" --template="jeti.html"
cp SETTINGS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc snapshot.md -f markdown -t html  -o SNAPSHOT.HTML --metadata title="Snap Shot" --template="jeti.html"
cp SNAPSHOT.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc spdann.md -f markdown -t html  -o SPDANN.HTML --metadata title="Speed Announcer" --template="jeti.html"
cp SPDANN.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc temps.md -f markdown -t html  -o TEMPS.HTML --metadata title="Temperatures" --template="jeti.html"
cp TEMPS.HTML ~/JSE/DOCS/DFM-FLTE/

pandoc vspeeds.md -f markdown -t html  -o VSPEEDS.HTML --metadata title="V Speeds" --template="jeti.html"
cp VSPEEDS.HTML ~/JSE/DOCS/DFM-FLTE/
