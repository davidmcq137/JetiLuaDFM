# Release Notes for Version 8.11 of DFM-Maps

## Bug fixes:

1. The IGC logfile feature had an issue that sometimes prevented the app from running.
	This is now fixed.

2. The absolute/relative altitude sensor numbers for the SM Modellbau
	GPS Logger 3 were inadvertently swapped.

3. Two warning messages on the triangle view were overlapping when there was
	no GPS signal and triangle racing was not enabled.

# Release Notes for Version 8.1 of DFM-Maps

## Video:

Harry Curzon has made a Youtube video summarizing these changes:
	https://youtu.be/TuDt0r6rF5I

## Bug fixes:

1. The version 7.24 app could sometimes crash when coming out of the map
	browser.

2. There were occasional issues creating map repos when close to
	180 degrees longitude with version 7.24. Thanks to Dave in NZ for
	his help in resolving this.

## Notes:

1. We had originally considered releasing this version as a .lc
	file, but it would have created too many upgrade headaches for our
	pilots, so the released version will remain as .lua. If you have
	some older development versions with the .lc filetype on your TX
	they will also show up in the User Applications menu as
	DFM-Maps. If loaded, you will know they are out of date since they
	won't have the current version number. You can remove the file
	DFM-Maps.lc from your Apps/ folder if you want to clean this up.

2. Prior versions such as the
	original 7.24 release will still be available on the website,
	though we do recommend updating to this version. To do that, go
	back to our map generator website. Please be sure to reload or
	refresh the page to make sure you have the latest version of the
	website code and create a new Jeti repo with your fields. Next
	confirm that your repo URL is still properly stored in Jeti Studio
	configuration, and then use Studio's TX Lua App manager to
	uninstall and re-install DFM-Maps.

3. In addition to supporting app installation with Jeti studio, we
	now also offer a zipfile for manual installation of the app and
	your personalized map data.

## New features/changes - General:

Only one change may require you to re-enter data. See #9 and 10
	regarding triangle edits.

1. Language translation is now enabled, and this new version has
	the original English and translations for German, Czech and French
	have been created. If you want to contribute a translation that is
	not already done, see the file DFM-Maps/Lang/readme.1st for
	instructions and contact us.  Many thanks to Claus for the German
	translation, to Pascal Amidey for the French translation and to
	Pavel and Martin for the Czech translation.

2. If you have multiple fields at one GPS location, typically due
	to wind-related orientations, or multiple runways, the app will
	now remember the last selection (done with the manual field
	selection menu) and go directly to that field when restarted or
	when coming back from the map browser.

	Previously the app would always select the first of the fields at
	that location by alphabetical order and it would have to be
	manually changed each time. Thanks to Simon in Australia for
	suggesting this.

3. There is a new menu item (Settings/Airplane Icon) for selecting
	the icon used for your aircraft on the map. We currently have Jet,
	Prop and Glider. The method previously used to set a custom icon
	can still be used if you want to create your own icon. For a model
	called "Dave T38" you would create the file Dave_T38_icon.jsn in
	the directory DFM-Maps/JSON. All spaces (if any) in the model name
	are replaced with underscores.

	The icon is a "connect the dots" drawing specified as a json
	file. You can see examples in the directory. Get out a piece of
	graph paper and plot out one of the examples to see how it works
	(very simple). We are happy to take contributed icon files and add
	them to the menu in future releases if you wish. Thanks to Harry
	Curzon for making the prop icon.

4. We have added a setting to do light or dark backgrounds on the
	Map and Triangle views. This is in addition to the original image
	(google map) background. Image view is not available on the new
	Triangle view.  For the more technical users, all colors in the
	app are now taken from a color configuration file
	DFM-Maps/JSON/Colors.jsn so if you want to make changes to the
	r,g,b values of any feature colors, you can.


5. We have added a checkbox to the Telemetry sensors menu to
	treat a GPS altitude reading as absolute or relative. This is
	primarily meant for GPS units we don't support for
	auto-configuration (see file Apps/DFM-Maps/paramGPS.jsn) and are
	assigned manually by the pilot in the Telemetry Sensors menu.The
	checkbox determines whether or not the field elevation we get from
	google maps is subtracted from the GPS altitude reading or not. In
	absolute mode, it does the subtraction, otherwise not.

	Auto-configured GPSs (currently Jeti MGPS, Tero's GPS, Powerbox
	GPS II and III, FLYMATE PRO, and the Elite GPS Datalogger) have
	this taken care of automatically. Note that as a last resort you
	can override field elevation in the Settings/Field elevation
	adjustment menu.

	We are happy to add additional GPSs to the autoconfiguration file
	if we get the info from pilots.


6. It is now possible to create IGC-compliant log files, which
	record the flight paramaters in a standardized format (see
	https://xp-soaring.github.io/igc_file_format/igc_format_2008.html).

	Filenames are in the long name standard format (for example
	2021-11-03-XDM-7FA-01.igc) and log files are stored in the
	Apps/DFM-Maps/IGC/ directory. Post-flight visualization can be
	done with an Android app or with a web-based tool - one example we
	have used is https://igcviewer.bgaladder.net/

	You can use the USB connection to the transmitter to download the
	igc log files to a mobile device or a PC for viewing at the flying
	field.

	In order to record IGC log files, go to the settings menu and
	enable to check the "Record IGC logfile" item. You will need to
	restart this app in order to record the IGC file.  Similarly, if
	you uncheck the log file recording, you should also restart this
	app.

	You can make multiple recordings in a flight. If a race ends and
	you continue flying, the first log file is closed, You can then
	re-arm the start and this will create the next log file in the
	naming sequence.

7. To support logging of pressure altitude and vario values in
	the IGC logfiles, and make these values available for offline
	analysis, we have added entires on the Telemetry Sensors screen
	for an Altimeter (a barometric altitude, e.g. Rel. Altit or
	Abs. Altit for the Jeti MVario), for a standard vario
	(e.g. Vario from the Jeti MVario) and for a TEK Vario. If any of
	our pilots use TEK compensated varios, we would be happy to work
	with them to test this device .. I don't have access to one but
	the code to put it in the the log file is in place.

## New features/changes - Triangle Racing-Specific:

8. We've added a second full-screen telemetry window. Previously
	we only had the Map view (which you enable with the Timers/Sensors
	Displayed Telemetry screen on the TX). You will see that there is
	now a second choice called the Triangle view.

	The original Map view is
	an overhead view of the field with a fixed
	orientation determined when the map repo is created. The new view is
	intended for GPS triangle racing and orients the window to line up
	with the direction of travel, and the map and triangle course rotate
	around the aircraft perspective.

	There are menu items to set the size of the window (Flight
	History/Triangle View Scale) and the length of the history
	"ribbon"
	(Flight History/Triangle View History Points). The number of
	history points in this new view is restricted to a lower number
	than the Map view because of the additional computational load of
	rotating the images insted of just the aircraft.

9. We have removed the Triangle Settings menu. All edits of the
	triangle race course are now done with the Map Browser. Doing it
	this way allows you to see the changes on the screen as you make
	them. If you want to change the values vs. just browse, you have
	to set the field you want to edit/change to be the current
	field. You can do this with the Manual Field Selection menu. This
	works even if telemetry is not live and you are not at the field
	you want to edit.

	We added a new letter "O" to the edit button in the map browser to
	change the aim offset from the pylons since that was previously
	only settable with the Triangle Settings menu.  The edit button is
	the second soft button in the map browser screen and cycles
	through "X,Y,R,L,O" when clicked. This edits the X (left-right), Y
	(up-down), R (rotation), L (Length) and O (aim Offset) of the
	triangle. Press the "Save" button (#5) to save these values. The
	values in the repo are not changed, but the app remembers these
	adjustments when the same combination of model and field is used
	(see next item).

10. In previous versions of the app, if you edited the triangle
	race course with the Map Browser, those edits were saved with the
	model. This was not ideal since the edits would be applied to any
	field where you used that model. We have changed this so that
	triangle edits are saved by the combination of model and field
	.. so the changes are unique to the combination of model and
	field. We believe this is what pilots actually intended. Note! You
	will have to re-enter triangle edits done previously.

11. Some pilots have been experimenting with a version of GPS
	triangle racing while slope soaring. Ideally this would be a
	straight-line course with only two pylons. We have done something
	to facilitate this experimentation which is to add a setting (Race
	Paramaters/Triangle Height Scale) that shrinks or extends the
	vertical leg of the triangle from 1% to 400% of the original
	size. The original size, as speficied by tri racing rules is the
	default: 100%. We have also had some queries about generalizing
	the triangle to a polygon which is amusing. Maybe GPS polygon
	racing could become a thing...

12. You can now set up a switch to turn No Fly warnings on and off in
	flight (Settings/NoFly Ann). If this switch is not assigned, then the
	menu checkboxes control No Fly warning announcements as they have
	previously. If the switch is assigned, it must be in the active (check)
	position to allow warnings .. it is "and-ed" with the menu checkbox
	announcement setting. Thanks to Jochen for suggesting this.

13. We have added a switch to the Race Parameters menu for
	detecting use of throttle during a triangle race. First, you
	should set up a logical switch which is on when the throttle is in
	the "run" position and off when the throttle is off.  Then assign
	this switch to the Throttle switch in the Race Parameters menu and
	select Up/Mid/Low to Up .. confirm that the checkmark is present
	when the throttle is on and the X is present when the throttle is
	off.

	For pre-flight confirmation that this throttle detection is armed
	and ready, we have added a red/green circle just above the
	existing circles showing race status.  Once the switch is
	assigned, but before the race starts, the circle will be red for
	throttle on, and green for throttle off. Once the race starts, and
	use of throttle is detected, we will set the circle to red and
	keep it red, and the subtitle line with the score will turn red
	and remain red and "Thr" will be appended to the subbtitle scoring
	line.

14. We have added a maximum altitude setting to the Race
	Parameters menu. Triangle racing rules require a maximum altitude
	for a race. If this altitude is exceeded, an error will be
	recorded and the subtitle line of the score will turn to red. The
	letters "Alt" will be appended to the line to indicate exceeding
	the max altitude.

15. We have added the display of Index to the overhead map screen
	and to the triangle screen. The value is only displayed when
	triangle racing, and the value is updated with each lap. The Index
	is the total distance flown in a lap, divided by the perimeter of
	the triangle, multiplied by 100. If the IGC log file is open an
	"L" or comment record is stored with the index value for the lap.
