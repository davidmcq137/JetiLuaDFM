Default units are the units into which all telemetry readings are converted as
they come from the sensor. The app defaults to metric/MKS units, as these are
the Jeti standard.

Some sensors to not follow Jeti guidance and have non-standard units, or
settable units. The Jeti guidance is that all sensors should report in metric
units, and then the TX or Jeti Studio can do conversions. We convert these units
to the default units (again the "default default" is metric units) in these
non-standard cases. Some sensor manufacturers even create their own non-standard
unit names (e.g. kmh vs. the Jeti standard km/h). We convert the ones we know
about but can't handle everything. Let us know if we missed any that are important to you.


Units are converted within a units group such as distance, speed, flow rate, etc.

Units not in these unit groups are not converted.

It is important to have consistent units if doing lua computations and all lua
variable operations are done in the default units. You can change the default
units to different systems than metric, but you then have to be consistent
across unit groups if you expect lua variable computations to be correct.

In addition to setting the default used inside the app (e.g. for lua variables),
you can set specific units for an indvidual gauge that apply to that gauge
only. This can be convenient if you want speed and vario in m/s to compute glide
ratio but prefer to display speed in km/h or mph. The gauge-specific units are
set in the Inputs panel and are only available if a sensor is selected for
input.
