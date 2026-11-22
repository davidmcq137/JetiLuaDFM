Summary of commands:

- Speed Ann Enable Switch
- Cont. Speed Ann Switch
- Airspeed Sensor
- Speed change scale factor
- Shortest announce time
- Longest announce time

## Speed Add Enable Switch

Assign the switch to turn speed announcements on and off.

## Cont. Speed Ann Switch

Assign the switch to turn on continuous speed annonuncements. A convenient
approach is to use a 3 positon switch, where one end is all announcements off,
middle is the basic (Speed Ann Enable Switch) announce mode, and the other end
is the continuous announce.

## Airspeed Sensor

This command sets the airspeed telemetry sensor from which the speed
announcements are derived. It uses the usual Jeti telemetry sensor menu.

## Speed change scale factor

The speed announcer is designed to make periodic announcements of the
airspeed. Announcements are made at varying intervals depending on how long it
has been since the last announcement and how far the speed has moved from the
last annoncement. This scale factor varies the shape of the curve between the
minimum time interval and the maximum interval. A larger value here will move to
more frequent announcements. You can vary this factor to make it as talkative as
you like.

## Shortest announce time

The announcer will not make another announcement until this time has passed
since the last annonucement.

## Longest announce time

Even if the speed is unchanged, there will be another announcement after this
time has passed.
