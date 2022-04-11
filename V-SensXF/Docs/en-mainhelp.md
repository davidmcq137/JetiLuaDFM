V-SensXF is based on excellent Jeti V-Sensor app, the __XF__ refers to __extended
function__.

The main extensions are:

- An arbitrary number of telemetry variables can be defined and named using the
    __Telemetry Sensors__ menu. These variables can then be used in expressions
    to create live computed results. Expressions are defined in the __Result
    Expressions__ menu.
    
- GPS sensors may be defined, along with GPS points on the __GPS
    Sensors__ and __GPS Points__ menus

- We have added a number of special functions to the environment of the lua
    interpreter that is used to evaluate the lua expressions. See the help
    screen on the __Results Expressions__ menu for more information. For example
    we have GPS distance and bearing functions, no fly inside and outside
    functions, and a knob and slider reading function to adjust parameters during
    flight.

- Results can be displayed in telemetry windows and can be set to single or
     double size telemetry windows with the TX Displayed Telemetry menu. You can
     assign specific results to specific telemetry windows with the __Telemetry
     Windows__ menu.

- Results are logged to the logfile up to the max number your transmitter
     permits (10 for Gen 1 monochome devices, 24 for others).

- Results can have lua controls associated with them. These are set with the
     __Lua controls__ menu. The limit for the number lua controls is 4 on Gen 1
     devices, and 10 for others. This allow interaction with the TX programming
     by using a lua control to drive a logic switch or any other function that
     allows lua controls.

- You can have an arbitrary number of result expressions, but the telemetry
     windows, log entries and lua controls are limited to the numbers available
     on the TX depending on its capacity as noted above.





