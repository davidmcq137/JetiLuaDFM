You may enter for the result any lua expression that could occur as the return
	    value of a function. If the returned value after evaluating the
	    result expression is a number, it will be used as the result. If the
	    return value is a boolean, the value of result will be 1 for true and 0 for
	    false.

The telemetry values assigned in the telemetry sensor screens are put in
	    variables which by defualt are named tn where n is the number of a
	    telemetry sensor, for example t1, t2, t3. You can also edit these
	    variable names to whatever you like so long as it complies with the
	    rules for lua variables. They are used in expressions as any normal
	    lua variables and their value is kept up to date with the current
	    value of the telemetry senor by a lua loop running continuously.

Several standard math functions from the lua math library are included. These
	    are: abs, sin, cos, atan, rad, deg, sqrt, max, min and floor. We
	    have also added special functions: step, box, pc, sign, gpsd, gpsb,
	    nfi and nfo. These special functions are defined below.

The step function has three arguments: a1, a2, a3. step(a1,a2,a3)
	    returns 0 when abs(a1-a2) <= abs(a3). It returns -1 when abs(a1-a2) >
	    abs(a3) and a2-a1 is positive. It returns 1 when abs(a1-a2) > abs(a3)
	    and a2-a1 is negative.

The box function also has three arguments and works similarly to step,
	    except that it returns 0 when abs(a1-a2) <= abs(a3) and 1 otherwise.

The sign(a1) function returns +1 if a1 is positive, -1 if a1 is negative and 0 if a1 is 0.

The pc function is used to include the value proportional controls in the
    	    expression.  It can have one, two or three arguments. With one
    	    argument a1 the value of pc(a1) is the value of proportional control
    	    a1 in the standard -1 to 1 range. With two arguments pc(a1, a2) also
    	    reads out control a1 but the value of the function goes from 0 t o
    	    a2. With three arguments pc(a1,a2,a3) also reads out control a1 b ut
    	    the value of the function goes from a2 to a3.

There are two special functions for use with the GPS sensors, these are gpsd(a1)
            and gpsb(a1).  gpsd(a1) computes the distance in meters from the
            current aircraft position (as reported to the lat/long telemetry) to
            the GPS Point a1. gpsb(a1) returns the bearing in degrees from the
            current aircraft position to GPS Point a1. GPS Point 1 is special,
            it is the home position where the first telemetry readings for lat
            and long come in, or when the Reset button was last pushed on the
            GPS Points screen. You can create and type in additional GPS Points
            with your own coordinates.
	    
For creating no-fly-zones, there are two additional special functions to
    	    simplify the specification of these zones, although that could also
    	    be done with lua expressions using gpsd and gpsb.

The function for creating no-fly-inside zones is nfi(a1,a2). The function
    	    returns 1 (true) if the aircraft is within a1 meters of the GPS
    	    Point number a2. You can create a set of GPS points for different no
    	    fly zones and then create a result expression of, for example
    	    nfi(100, 2) which will return true when the aircraft is within 100m
    	    of GPS Point 2, and 0 otherwise, and similarly for GPS Point 3 and
    	    so on.

There is also a function nfo(a1,a2) for creating no-fly-outside zones. nfo
    	    returns true when the aircraft position is more than a1 meters from
    	    GPS Point a2. If a2 is omitted and nfo is called as nfo(200) for
    	    example, then GPS Point 1 is used and the function returns true if
    	    the aircraft is more than 200 meters from the origin point GPS Point
    	    1 and 0 otherwise. Typically nfo only makes sense for GPS Point 1 so
    	    the single parameter call is expected to be used most of the time.
	    
If you need to use units that are not in the Jeti text entry menu we have
       	    defined special escape sequences for these units. They are .p for
       	    the percent symbol (%), and .o for the degree symbol (°).

For example entering a unit string of .oC will display °C as the unit string in
       	    the telemetry window and expression editing screen.

If you press them Menu key with the Result Expressions screen displayed (note
    	    the help symbol on softkey 1), the app will read the file
    	    V-SensXF/Exp.jsn which contains pre-defined expressions for some
    	    common use cases (e.g. watts for electic motors, glide ratio for
    	    sailplanes).  Select the line you want to copy into the expression
    	    to create this result and the app will copy in the expression, the
    	    name and the units for you. It will overwrite anything that was on
    	    the expression line before.

You can edit the file Exp.jsn to add up to six pre-defined equations along with
    	    names and units. Note that you will have to go to the Telemetry
    	    Sensors menu to select and name sensors to match the variable names
    	    used in the pre-defined equations. You will be changing the default
    	    names for example t1, t2 to the variable names used in the Exp.jsn
    	    file (for example Volts, Current for the Watts expression).

**Please note that variable names are case sensitive .. so be sure to match the
    	    telemetry variable names exactly as you see them in the
    	    expression.**