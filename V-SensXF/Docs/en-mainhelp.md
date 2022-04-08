V-SensXF is based on excellent Jeti V-Sensor app, the __XF__ refers to __extended
function__.

The main extensions are:

- An arbitrary number of telemetry variables can be defined using the __Telemetry
    Sensors__ menu
    
- GPS sensors may be defined, along with GPS points on the __GPS
    Sensors__ and __GPS Points__ menus

- We have added a number of special functions to the environment of the lua
    interpreter that is used to evaluate the lua expressions. See the help
    screen on the __Results Expressions__ menu for more information. For example
    we have GPS distance and bearing functions, and a __knob and slider__ reading
    function to adjust parameters during flight.

- An arbitrary number of result expressions can be set and named with the __Result
    Expressions__ menu

- You can define static variables (not linked to telemetry sensors) to facilitate
     more complex result expressions.  Use the __Variables__ menu to create and
     set them.

- Results 1 and 2 have telemetey windows associated with them and can be set to
     single or double size Results are logged to the logfile up to the max
     number your transmitter permits (10 for Gen 1 monochome devices, 24 for
     others)

- Results have lua controls associated with them. Result 1 is lua control V01,
     Result 2 is V02, etc. The limit for lua controls is 4 on Gen 1 devices, and
     10 for others. This allow interaction with the TX programming by using a
     lua control to drive a logic switch or any other function that allows lua
     controls.

- You can have an arbitrary number of result expressions, but the telemetry
     windows, log entries and lua controls are limited to the numbers available
     on the TX depending on its capacity as noted above.

- You can access a file of pre-made result expressions and pilots can exchange
     these files to share useful examples of expressions

This is another paragraph.



