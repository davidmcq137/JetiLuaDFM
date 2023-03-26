
This is the lua expression editor. You use the 3D wheel to scroll the list of
numbers, functions, variables and operators back and forth.

The highlighted symbol will be included in the expression if you press enter
while it is highlighted. Note that some common symbols are assigned to softkeys
to speed up the input process.

# Functions available

__abs(v)__ Returns the absolute value of v

__sqrt(v) __ Returns the square root of v

__minV(\'Sn\')__ Returns the minimum value of lua variable Sn since app start or reset. Quotation marks required.

__maxV(\'Sn\')__ Returns the maximum value of lua variable Sn since app start or reset. Quotation marks required.

__avgV(\'Sn\')__ Returns the average value of lua variable Sn since app start or reset. Quotation marks required.

__avgV(\'Sn\', N)__ Returns the \'running average\' of lua variable Sn over approximately N updates. Quotation marks required. Depending on the number of lua variables defined, they are updated 20-30 times per second so a value of 30 for N will give approximately 1s averaging time.

Notes:

The max, min and average values returned by maxV, minV and avgV are reset at app
startup and can also be reset with the switch assigned to reset the min/max on
gauges. This switch assignment is done in the __Settings__ menu.

There may be other functions shown in the scroll list that are loaded dynamically at app start and are provisioned from lua files in the __Extensions__ or __Functions__ directories. Some examples include:

__LiPoV(s)__ Returns the generic (brands can vary!) 1S LiPo voltage at state of charge s

__LiPoS(v)__ Returns the generic (brands can vary!) 1S LiPo state of charge at voltage s

__LiFrV(s)__ Returns the generic (brands can vary!) 1S LiFe voltage at state of charge s

__LiFeS(v)__ Returns the generic (brands can vary!) 1S LiFe state of charge at voltage s

__gratio(a,v)__ Returns the glide ratio computed from airspeed a and vario reading v







