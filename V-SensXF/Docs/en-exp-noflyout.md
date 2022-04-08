# noflyout - determine if aircraft is inside or outside of circular no fly  zone

     noflyout = gpsd(1) > radiuso and
     abs(bearing-gpsb(1)) > 90

Result generated: __noflyout__ is a boolean value (1 for true, 0 for false) if aircraft is in the no-fly zone outside a circle of radius __radiuso__ (meters) and in front of the flightline defined by the pilot direction of __bearing__ degrees. 

Result description: The radius of no fly zone is __radiuso__ in meters and it defines a circular region. Outside this region is a no fly zone. Set the value of __bearing__ to the direction in degrees (true, not magnetic) the pilot is facing. 0 degrees is north, 90 degrees west, 180 degrees south, 270 degrees is west.

Result units: none. __result__ is a boolean value of 1 (true) if outside the circle and thus in the no fly zone, 0 (false) otherwise

Telemetry variables required: None. The gpsd() function is built in to the expression builder, and GPS point 1 (see the __GPS Points__ menu) is the home position where the TX was started.

Static variables required: radiuso, bearing. Name and set these with the __Variables__ menu. __bearing__ is in degrees.
