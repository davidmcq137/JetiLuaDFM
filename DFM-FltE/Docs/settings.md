Summary of commands:

- Sync PID Prop gain
- Sync PID Int gain
- Max Gauge RPM
- Engine
- Indicators

## Sync PID Prop gain

This is the PID feedback loop proportional gain. Set to 0 to remove the
proportional term from the feedback loop. You can lower it to make the feedback
loop less tight which might be necessary if the loop is oscillating.

## Sync PID Int gain

This is the PID feedback loop integral gain. Set to 0 to remove the integral
term from the feedback loop. You can lower it to slow down the feedback loop and
increase it to speed up the feedback loop. Setting it too hight might make the
loop unstable.

## Max Gauge RPM

This is the full-range value for the RPM gauge.

## Engine

This allows setting the engine name to whatever you like which will show up in
the title of the telemetry window. The app must be restarted after changing it
before you will see it in the title of the window.

## Indicators

This submenu will let you associate controls or switches with the indicators in
the center of the telemetry window.
