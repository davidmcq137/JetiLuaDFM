The panel editor will display a panel _live_ and will position a crosshair over
the center of the widget (panel element) being edited. The Select button cycles
through the widgets. The second button selects which property to edit, and the
third button selects which element of that property to edit.

Some items such as labels and text box contents can be edited with the
transmitter's text edit function, for these the fourth button _Edit_ will be
shown as available.

Status and other useful information is displayed on the gray bar at the bottom
of the screen.

Special feature: When editing min and max values for widgets, the editor menu
will use 1 decimal place if the absolute value of min and the absolute value of
max are less than 1000. For numbers whose magnitude is larger than 1000, it will
use integer values (no decimal places). To move a number from below 1000 to
1000, first edit it below 1000 which will use one decimal place. Take it to a
value whose magnitude is above 1000 .. then close and re-open the min/max edit
panel and then it will be in integer mode and you can make the number larger, up
to 32767 or down to -32768.
