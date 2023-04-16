set -e
set -x

pandoc en-main.md -f markdown_strict -t html  -o EN-MAIN.HTML --metadata title="DFM-InsP Help" --template="jeti.html"
cp EN-MAIN.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-settings.md -f markdown_strict -t html  -o EN-SETTINGS.HTML --metadata title="DFM-InsP Settings Help" --template="jeti.html"
cp EN-SETTINGS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-inputs.md -f markdown_strict -t html  -o EN-INPUTS.HTML --metadata title="DFM-InsP Inputs Help" --template="jeti.html"
cp EN-INPUTS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editpanel.md -f markdown_strict -t html  -o EN-EDITPANEL.HTML --metadata title="DFM-InsP Edit Panel Help" --template="jeti.html"
cp EN-EDITPANEL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editlinks.md -f markdown_strict -t html  -o EN-EDITLINKS.HTML --metadata title="DFM-InsP Edit Links Help" --template="jeti.html"
cp EN-EDITLINKS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-luavariables.md -f markdown_strict -t html  -o EN-LUAVARIABLES.HTML --metadata title="DFM-InsP Lua Variables Help" --template="jeti.html"
cp EN-LUAVARIABLES.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-resetall.md -f markdown_strict -t html  -o EN-RESETALL.HTML --metadata title="DFM-InsP Reset All Help" --template="jeti.html"
cp EN-RESETALL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editlua.md -f markdown_strict -t html  -o EN-EDITLUA.HTML --metadata title="DFM-InsP Edit Lua Expressions Help" --template="jeti.html"
cp EN-EDITLUA.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-inputs.md -f markdown_strict -t html  -o EN-INPUTS.HTML --metadata title="DFM-InsP Edit Inputs Help" --template="jeti.html"
cp EN-INPUTS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-more.md -f markdown_strict -t html  -o EN-MORE.HTML --metadata title="DFM-InsP Lua Variables - More" --template="jeti.html"
cp EN-MORE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-colors.md -f markdown_strict -t html  -o EN-COLORS.HTML --metadata title="DFM-InsP Lua Variables - Colors" --template="jeti.html"
cp EN-COLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-units.md -f markdown_strict -t html  -o EN-UNITS.HTML --metadata title="DFM-InsP Lua Variables - Units" --template="jeti.html"
cp EN-UNITS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-widgetcolors.md -f markdown_strict -t html  -o EN-WIDGETCOLORS.HTML --metadata title="DFM-InsP - Widget colors" --template="jeti.html"
cp EN-WIDGETCOLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-backcolors.md -f markdown_strict -t html  -o EN-BACKCOLORS.HTML --metadata title="DFM-InsP - Background colors" --template="jeti.html"
cp EN-BACKCOLORS.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editpanelsub.md -f markdown_strict -t html  -o EN-EDITPANELSUB.HTML --metadata title="DFM-InsP - Editpanel subpanel" --template="jeti.html"
cp EN-EDITPANELSUB.HTML ~/JSE/DOCS/DFM-INSP/

pandoc en-editgauge.md -f markdown_strict -t html  -o EN-EDITGAUGE.HTML --metadata title="DFM-InsP Lua Variables - Edit Widget" --template="jeti.html"
cp EN-EDITGAUGE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryCBdial.md -f markdown_strict -t html  -o ~/JS/DFM-InsP/Panels/EN-HARRYCBDIAL.HTML --metadata title="Harry C. CB Dial Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-HARRYCBDIAL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryElectric.md -f markdown_strict -t html  -o ~/JS/DFM-InsP/Panels/EN-HARRYELECTRIC.HTML --metadata title="Harry C. Electric panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-HARRYELECTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-ChartRecorder.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-CHARTRECORDER.HTML --metadata title="Chart Recorder Two Trace Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-CHARTRECORDER.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-Concentric.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-CONCENTRIC.HTML --metadata title="Concentric Gauges Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-CONCENTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-ElectricArc.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-ELECTRICARC.HTML --metadata title="Electric Panel with Arc Gauges" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-ELECTRICARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-FourUp.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-FOURUP.HTML --metadata title="Four Gauge Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-FOURUP.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-GlassCockpit.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-GLASSCOCKPIT.HTML --metadata title="Glass Cockpit Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-GLASSCOCKPIT.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryCBdial.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-HARRYCBDIAL.HTML --metadata title="Harry C. CB Dial Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-HARRYCBDIAL.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-HarryElectric.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-HARRYELECTRIC.HTML --metadata title="Harry C. Elecric Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-HARRYELECTRIC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-PreFlightArc.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-PREFLIGHTARC.HTML --metadata title="Preflight Panel with Arg Gauges" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-PREFLIGHTARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-PreFlightCBox.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-PREFLIGHTCBOX.HTML --metadata title="PreFlight Central Box Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-PREFLIGHTCBOX.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-RickDFour.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-RICKDFOUR.HTML --metadata title="Rick D DA-200 Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-RICKDFOUR.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-RickFive.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-RICKFIVE.HTML --metadata title="Rick D Radial Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-RICKFIVE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TurbineArc.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TURBINEARC.HTML --metadata title="Turbine Panel with Arc Gauges" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TURBINEARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-Turbine.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TURBINE.HTML --metadata title="Turbine Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TURBINE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoLargeArc.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TWOLARGEARC.HTML --metadata title="Two Large Gauge Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TWOLARGEARC.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoLarge.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TWOLARGE.HTML --metadata title="Two Large Gauge Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TWOLARGE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TwoNeedle.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TWONEEDLE.HTML --metadata title="Split Gauge Example Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TWONEEDLE.HTML ~/JSE/DOCS/DFM-INSP/

pandoc ~/JS/Gauges/resources/gauges/en-TurbineHarry2.md -f markdown_strict -t html -o ~/JS/DFM-InsP/Panels/EN-TURBINEHARRY2.HTML --metadata title="Harry C. Turbine Panel" --template="jeti.html"
cp ~/JS/DFM-InsP/Panels/EN-TURBINEHARRY2.HTML ~/JSE/DOCS/DFM-INSP/

