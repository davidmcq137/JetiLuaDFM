This menu allows you to create lua variables that can be used to put values into
text strings, and to do lua assignments to widgets. For instance this lets you
to use a mathematical expression to drive a gauge.

Variable names are defauled to S1 .. Sn but are editable to any names you
choose. A variable can be assigned to a sensor, and the app will keep the
variable updated with the sensor value, or a variable can be assigned to a lua
expression made from other variables (not itself!) and included functions.

Variable scope is global .. not per-panel.
