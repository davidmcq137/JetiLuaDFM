DFM-SpdA.lua

This is a speed announcer that was inspired by Tero's (from
RC-Thoughts.com) altitude announcer. It is written in Lua following
Tero's style (thanks Tero for all that you are doing to support the
Jeti community!) and it has only been tested on a DS-24. It was
developed on the Jeti emulator running on Debian Linux and the DS-24.

The purpose is to periodically speak the speed of the aircraft derived
from one of the telemetry sensors. Instead of the built-in approach of
a fixed interval and an on/off switch, this program attempts to vary
the interval of announcements according to changes in speed. I have
tested with several pitot-static airspeed sensors (e.g. Jeti MSpeed,
Digitech's airspeed sensor, Carsten's Groen's ASSI, Xicoy Flight
Computer) and with GPS sensors.

You can set a minimum interval of seconds between announcements
(default is 2 seconds). The system will then look at the change in
speed since the last announcement and vary the time to the next
announcement by a factor of 20:1. So, with the 2-second default, the
longest interval (if the speed is constant) is 40 seconds by default
.. but it is settable.

A speed-change scale factor can also be selected that varies how
sensitive the 20:1 window is to speed changes. The default is 10
mph. Think of this as the speed change that will result in the median
interval, in this case 20 seconds between announcements. Set this
lower to make more frequent announcements and larger to make less
frequent announcements.

I've played around with settings that seem to be informative but not
too "chatty" and used that experience to set the defaults. You may
have different preferences :-)

On the main menu, you need to select the speed sensor and an enable
switch. You can also set a continuous annoncement switch that will
speak the speed every (default) 2 seconds. I use a three position
switch for this .. down for off, middle for "automatic" and up for
continuous.You can set a Vref speed (typically approx 1.3 times the
stall speed in fullscale flying .. experience shows that 1.5 works
better for our planes) ... once the plane drops below Vref, it will
announce the speed with no units (e.g. no "mph or km/hr") every two
seconds to help with landing.  The program won't provide any
announcements (unless in continuous mode) until it goes about the
stall speed for the first time. So it won't annoy you on startup and
taxi. You can over-ride this with the continuous announce switch of
course ... e.g. if you want speed callouts on takeoff.

You can configure for mph or km/hr (or any of the other supported Jeti
units .. e.g. some fullscale pilots prefer knots) and also remove the
units from announcement if you like. I left Tero's language support
scaffolding in place but have no translations available at this
time. If anyone wants to offer translations, I am happy to include
them.

I have defaulted to no decimal places on the speed, it announces the
closest integer to the speed. I did not think it was useful to do
further rounding (e.g. 2 mph or 5 mph granularity). At least it does
not announce with two decimal places like the Jeti default system
does!

To install the program in your system, create DFM-SpdA directory in
the /Apps folder of your transmitter.  Copy all the files from the
dropbox folder DFM-SpdA into the DFM-SpdA folder on your transmitter
..  except for DFM-SpdA.lua .. put that file directly into the /Apps
folder of the transmitter.

Then, when you open the DS-24s User Applications menu, and do "+" you
will see DFM-SpdA on the menu ..  select it .. then press the 3D
button to go into the menu and set up your sensor, switch and any
parameters you want to alter from the defaults. Be sure the audio
volume on your TX is up so you can hear it.

Note that I have provided a calibration number (defaults to 100%) in
case you want to adjust the pitot-based sensors to agree with some
other standard (GPS or a radar gun). Remember that the pitot systems
in models are not going to be perfectly accurate since they do not
compensate for atmospheric pressure or temperature but they should be
repeatable in identifying the stall speed because the same factors
that vary the dynamic pressure in the pitot tube impact the wing's
lift in the same way.




