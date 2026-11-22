# JetiLuaDFM

This repository contains the basic source files for a set of lua Apps
I've built for the Jeti RC systems. Some of them have been prepared
for distribution via a custom website, or via the Jeti Studio
Transmitter wizard.

For our GPS Maps App, please go to www.jetiluadfm.app and it will have
instructions for how to set up maps for your field(s), and configure
Jeti Studio to download all required content to your TX. You will also
find links to Youtube training videos done by Harry Curzon.

Some of the other apps are hosted by digitech in the Netherlands
(thank you Sandor!). To get these apps, open Jeti studio and open
File/Configuration and add this line to the existing Jeti repository:

http://www.jetimodel.nl/DFMHC/Apps.json

The DFMHC apps are a collaboration with Harry Curzon. There are some
other apps that can be accessed if you add a second line:

http://www.jetimodel.nl/DFM/Apps.json

These apps are less well vetted and tested but you are welcome to use them.

Note that when you add these lines to the Apps Sources tab, my apps
will show up at the bottom of the list of the Jeti-sanctioned apps.

## Repository layout

The repository is the JETI Studio emulator's `Apps/` folder. The emulator
lists the `.lua` files at the top of it, so the top holds only links
into the app folders (`DFM-Maps.lua -> DFM-Maps/DFM-Maps.lua`). Use
`appset` to choose which ones are linked.

- **Shipping apps**: the folders with an `App.json` (DFM-Maps, DFM-InsP,
  DFM-TimG ...). `build/script.lua` builds every `*/App.json` folder, and
  CI publishes them to www.jetiluadfm.app.
- **Test tools**: FakeFW (fake firmware for testing apps off the TX),
  UIDriver, SensorE, SensorL, GpsTest, EnvDump, FontDump, ImgTest and
  SpikeTgt. See `FakeFW/README.md`.
- **Build and website**: `build/`, `sh/` (zips go to `zip/`), `.github/`,
  `dynamic-repo-server/`, `maps-web/`, `common-resources/`, `Gauges/`,
  `json/`, `Screenshots/` and `StaticAppScr/`. Helpers: DFM-HUDBuild,
  DFM-InsP-Test and GlobTest.
- **`Docs/`**: reference documents.
- **`AppsNotShipped/`**: older apps and projects that aren't distributed
  from here, kept for reference. They may not run as they are. To try
  one in the emulator, use `appset add <App>`.

Have fun .. please feel free to raise any issues here.

Dave McQ
