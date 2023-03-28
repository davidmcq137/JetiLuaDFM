# CB Harry dial

This panel features twin needle dials, and a Stacked text box showing capacities
used, and a seemingly invisible Panel Name with the name CENTRAL BOX DATA in the
rawText box.

The Panel Name is invisible because I have chosen its text colour as Black,
which of course does not show against the default black background of the panel.
However when I install this panel on a model in the Tx I will be choosing a
light background on the Tx, such as Lavender or Burr Walnut, and black is the
best text colour to show against those backgrounds.

To get twin needles, the first dial is built until you are satisfied with it,
then copied by pressing the Duplicate button.  Initially it will look as if
nothing has happened because an identical dial has appeared over the original
dial, but a new edit box has appeared.  Give the new dial its own label, for
example Batt 2 V, scroll down to the bottom of its editing box and change its
face visibility and scale visibility to OFF.

All but its needle are now transparent and you are seeing the face and scale of
the original dial below.  Change the needle colour to a different colour than
Batt 1, and if you want trim the needle, which shortens it from the centre
outward, so that if it is overlying the Batt 1 needle you will still see part of
the Batt 1 needle.

The Stacked text box has plain text but the text in apostrophe \'S1.0\' means that
on the Tx it will replace S1 with the value defined for S1 in the app menu __LUA
Variables__.  That is where I select the Central Box telemetry mAh of input 1 to
be S1.  The .0 forces the answer to be shown to 0 decimal places, if I had put
\'S1.2\' it would show the result to 2 decimal places.  If I do not define \.X such
as \'S1\' then the app will default to 2 decimal places in its display.
