The point of interest in this panel is the sequenced text box which can be
made to state the position of the trim or throttle lock switch, such as
\“Trim Low\” and \“Engine Run\”.  You can do the same thing on other panels to
show, for instance the position of a throttle lock switch for electrics,
the choke switch for petrol (gas) engines, etc.

The length of the following text will make it seem that this is a difficult
subject but the length of the text is just to give space to explain fully
what is happening and how to understand sequenced text boxes in general,
rather than just give a few lines on how to set it for this particular
panel.  For a visual example see the training video on Harry Curzon\’s
Youtube channel.

The text shown in the edit panel for the sequenced text box on the website
does not matter because you can edit it totally in the app on the
transmitter, in fact you can have a blank in the text on the website and
insert whatever text you want, per model, in the Tx.

The basis of the sequenced text box is that each line of text corresponds
to its line number.  Therefore the line numbers start at 1 and go upwards.
The input from telemetry, control or LUA states a number, and the sequenced
text box will display the text from the matching line number.  For example,
if the input is the number 2, then the seq txt box will display the text
from line 2.

The following all relates to the app on the Tx, not to the website panel
builder.

We can use this to display the position of the switch or trims, however we
cannot simply set the Widget Input Source as Control and choose the trim or
switch.  Jeti trims or switches output from minus 100% through 0% at
centre, to +100%.  These translate to the numbers -1, 0, +1, so if we set
the Widget Input Source as a Control and choose the switch or trims, the
seq txt box will not understand minus 1 or 0 as there are no corresponding
line numbers.  We need to add 2 to the switch output so that minus 1, 0 and
plus 1 become plus 1, 2, and 3, then the seq txt box can find those line
numbers.

Go to LUA variables and set a variable as a Control, then set the switch,
trim etc as its source.  In the Inputs menu, set the Widget Input Source as
LUA, in Edit LUA simply select the variable then move the control to
confirm it is working and the Lua value shown should move between the minus
1, 0 and plus 1 values (no zero value if you are using a 2 position
control).  Then finally in the Lua f(x) extension menu choose
Switch2Seq_value().  That step does the adding 2 to the switch value for
you.  (Or you can do it manually by adding 2 to the variable in the Edit
Lua menu and not select a Lua f(x) extension!)

Finally, add or edit the text to suit the trim/switch positions.  If you
set a turbine throttle trim to one step from centre to forward only, then
the Lua will output 2 and 3, since trim position minus 100%, or minus 1, is
not used.  In that case simply put any useless text in line 1 as the app
will never go to it!  (Or do what I do, do not use the extension, simply
write your own line of variable+1 in the Edit Lua menu, because 0 and 1
will become 1 and 2 and then I need only write lines 1 and 2 in the seq txt
box).

Go to the Edit Panel menu, press F1 Select until the seq txt box is chosen,
press F2 until Text is selected, press F4 Edit and you will be able to
edit, add, delete lines of text.  For example in mine line 1 is Trim Low
and line 2 is Run.  With my trim outputting 0 and 1, and the Lua adding 1
to convert that to 1 and 2, trim centre will pick line 1 \“Trim Low\” for the
display, and trim forward will pick line 2 \“Run\” for the display.  If you
find the text that is displayed is the wrong way around it is simply that
the switch is outputting plus 1 and minus 1 at opposite ends to what you
expected so just edit the order of the text in the lines in the editor.
