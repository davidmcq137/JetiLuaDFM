This is the lua expression editor. You use the 3D wheel to scroll the list of
numbers, functions, variables and operators back and forth.

The highlighted symbol will be included in the expression if you press enter
while it is highlighted. Note that some common symbols are assigned to softkeys
to speed up the input process.

# Functions available

__abs(v)__ Returns the absolute value of v

__sqrt(v)__ Returns the square root of v

__minV(\'Sn\')__ Returns the minimum value of lua variable Sn since app start or
reset. __Single Quotation marks required__.

__maxV(\'Sn\')__ Returns the maximum value of lua variable Sn since app start or
reset. __Single Quotation marks required__.

__avgV(\'Sn\')__ Returns the average value of lua variable Sn since app start or
reset, OR the running average value of Sn. __Single Quotation marks required__.

Set the averaging mode for variable Sn in the _Lua Variables_ \'More\' sub-menu
- Choose _Global Average_ mode to average Sn from app start or reset, or _Running
Average_ mode to compute a \'sliding window average\' over N samples. N is also set
in the \'More\' menu.

Depending on the number of lua variables defined, they are updated 20-30 times
per second so a value of 30 for N will give approximately a 1s averaging time. N
must be greater than or equal to 1. With N=1 no averaging is performed.

This function is useful for \'cleaning up\' noisy data to display on a gauge or
chart recorder. You can select the average mode and averaging number for each
lua variable independent of its source.

Notes:

The max, min and average values returned by maxV, minV and avgV are reset at app
startup and can also be reset with the switch assigned to reset the min/max on
gauges. This switch assignment is done in the __Settings__ menu.

There may be other functions shown in the scroll list that are loaded
dynamically at app start and are provisioned from lua files in the
__Extensions__ or __Functions__ directories. Some examples include:

__LiPoV(s)__ Returns the generic (brands can vary!) 1S LiPo voltage at state of
charge s

__LiPoS(v)__ Returns the generic (brands can vary!) 1S LiPo state of charge at
voltage v

__LiFeV(s)__ Returns the generic (brands can vary!) 1S LiFe voltage at state of
charge s

__LiFeS(v)__ Returns the generic (brands can vary!) 1S LiFe state of charge at
voltage v

__gratio(a,v)__ Returns the glide ratio computed from airspeed a and vario
reading v







