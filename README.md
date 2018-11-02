# JetiLuaDFM

DFM-LSO.lua

"Landing Signal Officer" - so named because the pilot can't look at it during flight, his/her "RIO" (backseater or spotter) 
can look at it.

It is intended to work with the Jeti MGPS GPS sensor, the Jeti MSpeed Pitot/Static system, and the Digitech CTU. GPS parameters
come from the MGPS, Airspeed from the MSpeed and barometric altitude from the CTU. It can also work with other GPS's and airspeed sensors, but they won't be auto-assigned in the menu and have to have their telemetry channels assigned manully in the menu.

It works by reading the GPS lat and long, and converting them with a simple iso-rectangular projection to the X-Y plane. 
It assumes a simple round earth model, and I've tweaked the Earth radius to give accurate conversions in the New York area.
I suspect it is only a few percent error on the absolute coords, in other locations and of virtually no concern for relative distances from the local rigin as we are doing here.

The MGPS provides heading and speed information and is capable of computing speed and heading from the path. Other GPSs may note do this so the program can work with raw Lat and Long and compute speed and heading. This has been 
tested with Gaspar's Xicoy Flight computer.

While the system can read altitude from any sensor, GPS has poor accuracy on Z coordinates, and a slower response than a barometric method of altitude sensing, so we prefer that if available. If both GPS and non-GPS altitudes are available the system selects the barometric sensor.

To install the system, move the entire directory DFM-LSO into the Apps directory of the tansmitter or the Jeti emulator. This
directory contains all the support files needed by the program. Put the executable file (DFM-LSO.lua) directly into the Apps 
directory.

You will likely want to edit the file of known flying fields. Several are included. When the program wakes up it checks from the
GPS signal to see if it is at a known flying site from the file Fields.jsn. For each field you can specify GPS coords, runway 
direction (true, not magnetic), runway size, and you can also add points of interest (POIs) that will be marked with a cross
on the map if the map has zoomed out far enough to see them. This is useful for field boundaries, etc. On startup the program will display a messsage if it is at a known or unknown field. It will also label the map with this info. If it is an unknown field and no entry exists in the Fields.jsn file, there is a menu parameter to rotate the map so that the runway is displayed ahead of the pilot running left to right on the screen to maximize screen real estate. There is a north-pointer in the upper left of the map screen which will move if the screen rotates (either due to the rotate menu entry or a field in Fields.jsn).

Start the program in the usual way from the User Applications menu, and confirm that the telemetry sensors are auto-assigned
correctly, or assign them manually. Remember you also have to go into the telemetry setup menu and the displayed telemetry screen and add the two screens (LSO MAP and LSO ILS) to the list of screens to display.

One interesting feature of the program is the ability to note the takeoff direction and position and thus, even if a runway is
not designated in Fields.jsn, it can create an "ILS" system to show deviations from left to right and on glideslope on approach.
To enable this feature you have to tell the program what the brake and throttle controls are. These are menu options. Place the 
throttle at the midpoint of their travel, select the brake control menu, and when the usual switch select menu comes up, move 
brakes to the full on position and the same with the throttle. The program will assume that if the brakes are released and the 
throttle is moved close to full within 5 seconds that this is the takeoff point. It will note that with a circle on the map.

Once the aircraft has reached 50' altitude (AGL) it will then draw a second circle, a runway, and an ILS course which is a simple triangle that is +/- 12 degrees left and right and it will assume a 6 degree glideslope to the touchdown point (assumed to be the liftoff point). If you leave DEBUG mode on (see the DEBUG variable in the source code) the system will generate Lissajous figures and simulate a flight path. Wait for the altitude (also varying sinusoidally in DEBUG mode) to be increasing before doing your "takeoff" and you can play with this feature. The ILS screen is the second screen provided in addition to the map. the P7 slider is used on the emulator in DEBUG mode to speed up or slow down simulated time. I usually use P4 for throttle and P5 for brakes.

As the airplane files, a trail of 6 past positions is kept as a "comet tail". These points are fit with a Bezier curve to offer
a nicer visualization of the aircraft's flight path. As you may note, the little aircraft shape changes color if the ILS course 
has beenb established .. it turns green when with the "cone" of the ILS in the XY plane. I kind of like the T-38ish shape for
the aircraft, but of course you can edit Shapes.jsn if you prefer something else.

The map automatically zooms out as the flight path of the aircraft requires it, there is no way at present to do this manually. The program wakes up with an 800x400' window.

As the program executes, it also saves its own log file in the Log directory. The program can play that file back if desired. 
Check the source code for how to do that. Best done on the emulator...