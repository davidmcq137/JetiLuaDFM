The Flight Engineer App is designed to display single or twin-engine operating
values on a telemetry screen, as well as to provide a set of alerts indicating
potential issues with engine operation.

The app also has the ability to assist
the pilot with collecting flight test data (Snapshot) and collecting data to
establish the RPM as a function of throttle curve that establishes the first
step in engine monitoring.

There are two telemetry screens. The first is named **Flight Engineer
EngineName** where EngineName can be set by the pilot in the settings menu. The
second is named **Flight Engineer: Calibration** and which, when displayed on
the transmitter screen, will record the RPM of both engines after the throttle
stick (set in the controls menu) stops moving for approx 5 seconds.

Our recommendation is to take off with the first screen displayed, and then when
ready to collext throttle vs RPM data to switch to the second screen (or have
the spotter do it for you). Values will be called out with an audio announcement
as they are recorded.

Following flight, there is an analysis menu option for selecting a subset of the
points collected during flight, to edit them, manipulate and fit them for
subsequent use in engine performance monitoring. The data points and fit
parameters can also be saved in the analysis menu.

Summary of commands:

- V Speeds
- Controls
- Settings
- Speed Announcer
- Snapshot
- Temps
- Analysis

## V Speeds

This command opens a menu where the various V speeds can be set. Examples include the stall speed Vs0 and the minimum twin-engine controllable speed Vmca. Speeds can provide alerts when they are exceeded (for example Vne .. never exceed speed) and Vs0 (stall warning). Alerts can be of the form of stick shakes (left or right, various patters) or audio warnings.

## Controls

This command sets up the assignment of controls that the app needs to know about, for example the throttle stick.

## Settings

This command contains several settings to fine-tune the app operation, as well as defining the controls that run the indicators in the middle of the first telemetry screen.

## Speed Announcer

The Flight Engineer app contains the full function of the Speed Announcer app which periodically announces the speed of the aircraft with a time interval that depends on how much the speed has changed since the last announcement and how long since the last announcement.

## Snapshot

This command opens a menu where you can define a set of up to four values that are recorded when a switch changes state, or when a button is pressed.

## Temps

This commmand opens a menu where you can define the temperature boundaries of the engine temperature operating gauge. The regions are Cold, Normal, Warning and Overheat.

## Analysis

This command opens a live graphical window that allows the editing and curve fitting of the throttle vs RPM data collected in flight.




