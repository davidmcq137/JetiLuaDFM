DFM-TimA.lua

This is a speed announcer that is intended to also give fuel state with each time announcement
(at one minute intervals), as well as monitor current draw for users of the Jeti Central Boxes.
It can also graph a telemetry parameter of the user's choice (e.g. altitude, airspeed) on a selectable scale.
It has only been tested on a DS-24. It was developed on the Jeti emulator running on Debian Linux and
the DS-24. 

For the script to function correctly, you need go to the main menu and tell it the name of the fuel sensor,
typically it will read in %remaining. You also tell it the switch used for the landing gear and the gear
up position so it "knows" when to start its timer. Finally you need to tell the script how to note the
turbine shutoff so that it can stop the timer. You want to have a checkmark on the menu screen when gear
are up, and a checkmark when the throttle is at cutoff.

The script reads the battery current and maH readings from the default Central Box telemetry channels.
Note that the TX has the ability to set a switch to reset the maH used readings on the battery after they
are charged. We just read the maH from the CB, we don't track it .. so you do have to remember to flick that
switch after charging.

The intention is for the pilot not to have to look at the screen so the communication to the pilot is via
synthesized voice for all announcements. I typically also set alarms in the TX for high current situations
(e.g. currents in excess of 4A on either pack). This script could do that but I see no point in replicating
standard TX functions.

There are two bar graphs on the Super Timer screen that show the instantaneous current draw of the two packs
and they also have a red "high water mark" for the highest reading seen.

To install, put DFM-TimA.lua in your TX's Apps folder. Create in Apps a new folder named DFM-TimA and copy
the rest of the files to that directory.

A very simple and useful script...



