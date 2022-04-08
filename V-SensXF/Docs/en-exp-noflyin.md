# noflyin - determine if aircraft is inside or outside of circular no fly zone defined by a GPS point

     noflyin2 = abs(gpsd(2)) <= radiusi

gpsd(a1) is a special built-in function which measures distance from the aircraft current position to GPS Point a1. GPS Point 1 is the home position where the TX was turned on. In this case we assume GPS Point 2 has been set to the lat,long coordinates of the center of the no fly zone desired.

Result generated: Boolean value (1 for true, 0 for false) if aircraft is in the no-fly zone outside a circle of radius __radiusi__ (meters) from GPS point 2 which is set on the __GPS Points__ menu.

Result description: The radius of no fly zone is __radiusi__ in meters and it defines a circular region. Inside this region is a no fly zone. 

Result units: none. __result__ is a boolean value of 1 (true) if inside the circle and thus in the no fly zone, 0 (false) otherwise

Telemetry variables required: None. The gpsd() function is built in to the expression builder. The example refers to GPS Point 2. You can define as many GPS points as you like and create multiple versions of this for example

   noflyin3 = abs(gpsd(3)) <= radiusi3

This would establish a second no fly inside zone at GPS point 3 with radius __radiusi3__.

Static variables required: radiusi. Name and set this with the __Variables__ menu.

GPS Point required: You must define a GPS point for the center lat,long of the desired no fly zone. Do this in the __GPS Points__ program.

