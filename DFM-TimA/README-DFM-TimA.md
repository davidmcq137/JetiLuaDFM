DFM-SpdA.lua

This is a speed announcer that is intended to also give fuel state with each time announcement,
as well as monitor current draw for users of the Jeti Central Boxes. It can also graph a telemetry
parameter of the user's choice (e.g. altitude, airspeed). Tt has only been tested on a DS-24.
It was developed on the Jeti emulator running on Debian Linux and the DS-24. 

For the script to function correctly, you need to tell it the name of the fuel sensor, typically it
will read in %remaining. You also tell it the switch used for the landing gear and the gear up position so
it "knows" when to start its timer. Finally you need to tell the script how to note the turbine shutoff so
that it can stop the timer.

The script reads the battery current and maH readings from the default Central Box telemetry channels.
Note that the TC has the ability to set a switch to reset the maH used readings on the battery after they
are charged. We just read the maH from the CB, we don't track it.

There are two bar graphs on the Super Timer screen that show the instantaneous current draw of the two packs
and they also have a red "high water mark" for the highest reading seen.

A very simple and useful script...



