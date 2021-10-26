Release Notes for Version 9.0 of DFM-Maps

Bug fixes:

1) The app could sometimes crash when coming out of the map browser.

2) There were occasional issues creating map repos when close to 180
degrees longitude. Thanks to Dave in NZ for his help in resolving this.

New features/changes:

Only one change may require you to re-enter data. See #3 and 4 regarding
triangle edits.

1) Language translation is now enabled, and this new version has the
orginal English (locale "en") and translations for XX, YY, and ZZ
contributed by AA, BB and CC.

If you want to contribute a translation that is not already done, see
the file DFM-Maps/Lang/readme.1st for instructions and contact us.

2) We've added a second full-screen telemetry window. Previously we
only had the Map view (which you enable with the Timers/Sensors
Displayed Telemetry screen on the TX). You will see that there is now
a second choice called the Triangle view.

The original Map view is an overhead view of the field with a fixed
orientation determined when the map repo is created. The new view is
intended for GPS triangle racing and orients the window to line up
with the direction of travel, and the map and triangle course rotate
around the aircraft perspective.

There are menu items to set the size of the window (Flight
History/Triangle View Scale) and the length of the history "ribbon"
(Flight History/Triangle View History Points). The number of history
points in this new view is restricted to a lower number than the Map
view because of the additional computational load of rotating the
images insted of just the aircraft.

3) We have removed the Triangle Settings menu. All edits of the
triangle race course are now done with the Map Browser. Doing it this
way allows you to see the changes on the screen as you make them. If
you want to change the values vs. just browse, you have to set the
field you want to edit/change to be the current field. You can do this
with the Manual Field Selection menu. This works even if telemetry is
not live and you are not at the field you want to edit.

We added a new letter "O" to the edit button in the map browser to
change the aim offset from the pylons since that was previously only
settable with the Triangle Settings menu.  The edit button is the
second soft button in the map browser screen and cycles through
"X,Y,R,L,O" when clicked. This edits the X (left-right), Y (up-down),
R (rotation), L (Length) and O (aim Offset) of the triangle. Press the
"Save" button (#5) to save these values. The values in the repo are
not changed, but the app remembers these adjustments when the same
combination of model and field is used (see next item).

4) In previous versions of the app, if you edited the triangle race
course with the Map Browser, those edits were saved with the model. This
was not ideal since the edits would be applied to any field where you
used that model. We have changed this so that triangle edits are saved
by the combination of model and field .. so the changes are unique to
the combination of model and field. We believe this is what pilots
actually intended. Note! You will have to re-enter triangle edits done
previously.

5) If you have multiple fields at one GPS location, typically due to
wind-related orientations, or multiple runways, the app will now
remember the last selection (done with the manual field selection menu)
and go directly to that field when restarted or when coming back from
the map browser.

Previously the app would always select the first of the fields at that
location by alphabetical order and it would have to be manually
changed each time. Thanks to Simon in Australia for suggesting this.

6) There is a new menu item (Settings/Airplane Icon) for selecting the
icon used for your aircraft on the map. We currently have Jet, Prop and
Glider. The method previously used to set a custom icon can still be
used if you want to create your own icon. For a model called "Dave T38"
you would create the file Dave_T38_icon.jsn in the directory
DFM-Maps/JSON. All spaces (if any) in the model name are replaced with
underscores.

The icon is a "connect the dots" drawing specified as a json file. You
can see examples in the directory. Get out a piece of graph paper and
plot out one of the examples to see how it works (very simple). We are
happy to take contributed icon files and add them to the menu in
future releases if you wish.

7) We have added a setting to do light or dark backgrounds on the Map
and Triangle views. This is in addition to the original image (google
map) background. Image view is not available on the new Triangle view.
For the more technical users, all colors in the app are now taken from a
color configuration file DFM-Maps/JSON/Colors.jsn so if you want to make
changes to the r,g,b values of any feature colors, you can.

8) Some pilots have been experimenting with a version of GPS triangle
racing while slope soaring. Ideally this would be a straight-line course
with only two pylons. We have done something to facilitate this
experimentation which is to add a setting (Race Paramaters/Triangle
Height Scale) that shrinks or extends the vertical leg of the triangle
from 1% to 400% of the original size. The original size, as speficied by
tri racing rules is the default: 100%. We have also had some queries
about generalizing the triangle to a polygon which is amusing. Maybe GPS
polygon racing could become a thing...

9) You can now set up a switch to turn No Fly warnings on and off in
flight (Settings/NoFly Ann). If this switch is not assigned, then the
menu checkboxes control No Fly warning announcements as they have
previously. If the switch is assigned, it must be in the active (check)
position to allow warnings .. it is "and-ed" with the menu checkbox
announcement setting. Thanks to Jochen for suggesting this.

10) We have added a checkbox to the Telemetry sensors menu to treat a
GPS altitude reading as absolute or relative. This is primarily meant
for GPS units we don't support for auto-configuration (see file
Apps/DFM-Maps/paramGPS.jsn) and are assigned manually by the pilot in
the Telemetry Sensors menu.

The checkbox determines whether or not the field elevation we get from
google maps is subtracted from the GPS altitude reading or not. In
absolute mode, it does the subtraction, otherwise not. Auto-configured
GPSs (currently Jeti MGPS, Tero's GPS, Powerbox GPS II and III, and
the Elite GPS Datalogger) have this taken care of automatically.

Note that as a last resort you can override field elevation in the
Settings/Field elevation adjustment menu. We are happy to add
additional GPSs to the autoconfiguration file if we get the info from
pilots.
