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

pandoc en-colors.md -f markdown -t html  -o EN-COLORS.HTML --metadata title="DFM-InsP Lua Variables - Colors" --template="jeti.html"
cp EN-COLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-units.md -f markdown -t html  -o EN-UNITS.HTML --metadata title="DFM-InsP Lua Variables - Units" --template="jeti.html"
cp EN-UNITS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-widgetcolors.md -f markdown -t html  -o EN-WIDGETCOLORS.HTML --metadata title="DFM-InsP - Widget colors" --template="jeti.html"
cp EN-WIDGETCOLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-backcolors.md -f markdown -t html  -o EN-BACKCOLORS.HTML --metadata title="DFM-InsP - Background colors" --template="jeti.html"
cp EN-BACKCOLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editpanelsub.md -f markdown -t html  -o EN-EDITPANELSUB.HTML --metadata title="DFM-InsP - Editpanel subpanel" --template="jeti.html"
cp EN-EDITPANELSUB.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editgauge.md -f markdown -t html  -o EN-EDITGAUGE.HTML --metadata title="DFM-InsP Lua Variables - Edit Widget" --template="jeti.html"
cp EN-EDITGAUGE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryCBdial.md -f markdown -t html  -o EN-HARRYCBDIAL.HTML --metadata title="Harry C. CB Dial Panel" --template="jeti.html"
cp EN-HARRYCBDIAL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryElectric.md -f markdown -t html  -o EN-HARRYELECTRIC.HTML --metadata title="Harry C. Electric panel" --template="jeti.html"
cp EN-HARRYELECTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-ChartRecorder.md -f markdown -t html -o EN-CHARTRECORDER.HTML --metadata title="Title" --template="jeti.html"
cp EN-CHARTRECORDER.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-Concentric.md -f markdown -t html -o EN-CONCENTRIC.HTML --metadata title="Title" --template="jeti.html"
cp EN-CONCENTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-ElectricArc.md -f markdown -t html -o EN-ELECTRICARC.HTML --metadata title="Title" --template="jeti.html"
cp EN-ELECTRICARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-FourUp.md -f markdown -t html -o EN-FOURUP.HTML --metadata title="Title" --template="jeti.html"
cp EN-FOURUP.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-GlassCockpit.md -f markdown -t html -o EN-GLASSCOCKPIT.HTML --metadata title="Title" --template="jeti.html"
cp EN-GLASSCOCKPIT.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryCBdial.md -f markdown -t html -o EN-HARRYCBDIAL.HTML --metadata title="Title" --template="jeti.html"
cp EN-HARRYCBDIAL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryElectric.md -f markdown -t html -o EN-HARRYELECTRIC.HTML --metadata title="Title" --template="jeti.html"
cp EN-HARRYELECTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-PreFlightArc.md -f markdown -t html -o EN-PREFLIGHTARC.HTML --metadata title="Title" --template="jeti.html"
cp EN-PREFLIGHTARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-PreFlightCBox.md -f markdown -t html -o EN-PREFLIGHTCBOX.HTML --metadata title="Title" --template="jeti.html"
cp EN-PREFLIGHTCBOX.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-RickDFour.md -f markdown -t html -o EN-RICKDFOUR.HTML --metadata title="Title" --template="jeti.html"
cp EN-RICKDFOUR.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-RickFive.md -f markdown -t html -o EN-RICKFIVE.HTML --metadata title="Title" --template="jeti.html"
cp EN-RICKFIVE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TurbineArc.md -f markdown -t html -o EN-TURBINEARC.HTML --metadata title="Title" --template="jeti.html"
cp EN-TURBINEARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-Turbine.md -f markdown -t html -o EN-TURBINE.HTML --metadata title="Title" --template="jeti.html"
cp EN-TURBINE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoLargeArc.md -f markdown -t html -o EN-TWOLARGEARC.HTML --metadata title="Title" --template="jeti.html"
cp EN-TWOLARGEARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoLarge.md -f markdown -t html -o EN-TWOLARGE.HTML --metadata title="Title" --template="jeti.html"
cp EN-TWOLARGE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoNeedle.md -f markdown -t html -o EN-TWONEEDLE.HTML --metadata title="Title" --template="jeti.html"
cp EN-TWONEEDLE.HTML ~/JSE/DOCS/DFM-INSP/

