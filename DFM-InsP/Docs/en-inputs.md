On this menu you assign a sensor, a TX control or a lua expression to drive the
value of a displayed widget (a gauge or textbox or panel light). Assigning a
control can be convenient for testing (for example assigning the throttle
control to drive a gauge), or to assign a logical switch to a panel light.

You can also enter a lua expression to drive the widget which allows complex
mathematical expressions made of lua variables (which are assigned to sensors)
and built-in functions to drive a gauge or display a text value.

You can also specify a lua f(x) extension. There are lua scripts that are put
into the DFM-InsP/Extensions folder. The app will look for all the .lua files in
the directory and make them available in the pulldown menu for lua f(x)
extensions. One notable one is called Switch2Seq. If you select a control as the
input source for a sequenced text box, the control will give values -1, 0 and 1
if set to Prop mode .. and that is not compatible with the sequenced text box
which expects 1,2,3 .. Switch2Seq makes this adjustment.

