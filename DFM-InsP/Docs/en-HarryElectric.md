#HarryElectric

This panel features a Watt meter and a red/green panel light to be operated
by the throttle lock safety switch.

Some ESCs or electric sensors will tell you Watts in the telemetry but a Jeti
MUI does not.  This is not a problem for the app, because instead of selecting
telemetry Watts for the Watt meter we can set its input to be LUA instead of a
sensor, and in the LUA editor we can simply multiply volts by amps.

Before we can use the editor to build the equation we need to create the items
for it to use, so we go to the LUA variables menu and define one of them as the
telemetry volts and another as telemetry amps, then go back to inputs, to the
watt meter, go to its Edit LUA menu where we now find the volts and amps
variables for us to multiply them together.

The throttle lock panel light will show as red or green depending how you assign
the throttle lock safety switch on your Tx.  It is composed of a red panel light
overlaid with a duplicated panel light. The duplicate is changed from red to
green colour, with a transparent background so that when it is off we can see
the red beneath it.

On the transmitter app we simply assign the red and green to whichever
directions of the throttle lock switch we want.  You might think red for danger
meaning T-lock is off, or red for stop meaning T-lock is on, is it up to your
taste!
