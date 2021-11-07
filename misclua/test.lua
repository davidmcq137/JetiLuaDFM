local t0 = system.getTimeCounter()
local lastlat = 0
local lastlong = 0
local initx, inity
local gotInitPos = false
local L0 
local y0 
local rE = 6371*1000
local rad = 180/math.pi
local f
local lastLoopTime = 0
local avgLoopTime = 0
local loopCount = 0
local xtable = {}
local ytable = {}
local ztable = {}

PrettyPrint = require('PrettyPrint')
--------------
local function fslope(x, y)

    xbar = 0.0
    ybar = 0.0

    sxy = 0
    sx2 = 0
    
    for i = 1, #x do
       xbar = xbar + x[i]
       ybar = ybar + y[i]
    end

    xbar = xbar/#x
    ybar = ybar/#y

    for i = 1, #x do
        sxy = sxy + (x[i]-xbar)*(y[i]-ybar)
        sx2 = sx2 + (x[i] - xbar)^2
    end
    
    if sx2 < 1.0E-6 then
       sx2 = 1.0E-6
    end
    
    slope = sxy/sx2
    
    theta = math.atan(slope)
    tt=0
    if x[1] < x[#x] then
        if y[1] < y[#y] then
            tt = math.pi*2 - theta
        else
	   tt = math.pi/2 - theta
	end
    else
        if y[1] < y[#y] then
	   tt = math.pi - theta
        else
	   tt = math.pi - theta
	end
    end
 
    return slope, tt
end

--------------

local function init()

   f = io.open("gps.dat", "w")

   if not f then
      print("failed to open gps.dat")
      exit()
   end
   
   local sensors = system.getSensors()
   local kk = #sensors

   
   pretty_output = PrettyPrint(sensors)

   io.write(f, pretty_output, "\n")
   
   for i,sensor in ipairs(sensors) do
      ss = string.format("ID, param, decimals: %d, %d, %d", sensor.id, sensor.param, sensor.decimals)
      print(ss)
      io.write(f, ss, "\n")
      if (sensor.type == 5) then
	 if (sensor.decimals == 0) then
	    -- Time
	    ss = string.format("Time: %s = %d:%02d:%02d", sensor.label, sensor.valHour,sensor.valMin, sensor.valSec)
	    print (ss)
	    io.write(f, ss, "\n")
	 else
	    -- Date
	    ss = string.format("Date: %s = %d-%02d-%02d", sensor.label, sensor.valYear,sensor.valMonth, sensor.valDay)
	    print (ss)
	    io.write(f, ss, "\n")
	 end
      elseif (sensor.type == 9) then
	 -- GPS coordinates
	 local nesw = {"N", "E", "S", "W"}
	 local minutes = (sensor.valGPS & 0xFFFF) * 0.001
	 local degs = (sensor.valGPS >> 16) & 0xFF
	 ss = string.format("GPS: %s = %d° %f' %s", sensor.label,degs, minutes, nesw[sensor.decimals+1])
	 print (ss)
	 io.write(f, ss, "\n")
      else
	 if(sensor.param == 0) then
	    -- Sensor label
	    ss = string.format("Label: %s:",sensor.label)
	    print (ss)
	    io.write(f, ss, "\n")
	 else
	    -- Other numeric value
	    ss = string.format("ONV: %s = %.1f %s (min: %.1f, max: %.1f)", sensor.label, sensor.value, sensor.unit, sensor.min, sensor.max)
	    print (ss)
	    io.write(f, ss, "\n")
	 end
      end
   end
   print("#sensors was: ", kk)
   -- io.close(f)
end

local function loop()

   local latnum = 2
   local longnum = 3
   local altnum = 6
   local impnum = 12
   local crsnum = 10
   
   local latitude
   local longitude
   local altitude
   local impulse
   local course
   local compcrs
   local slope
   local compcrsDeg
   
   local allvalid = true
   
   local sensor = system.getSensorByID(1418438693, latnum)
   if not sensor.valid then
      print("lat not valid")
      allvalid = false
   else
      local minutes = (sensor.valGPS & 0xFFFF) * 0.001
      local degs = (sensor.valGPS >> 16) & 0xFF
      latitude = degs + minutes/60
   end
   
   local sensor = system.getSensorByID(1418438693, longnum)
   if not sensor.valid then
      print("long not valid")
      allvalid = false
   else
      local minutes = (sensor.valGPS & 0xFFFF) * 0.001
      local degs = (sensor.valGPS >> 16) & 0xFF
      longitude = degs + minutes/60
      if sensor.decimals == 3 then -- "West" .. make it negative
	 longitude = longitude * -1
      end
   end

   local sensor = system.getSensorByID(1418438693, altnum)
   if not sensor.valid then
      print("alt not valid")
      allvalid = false
   else
      altitude = sensor.value
   end
   
   local sensor = system.getSensorByID(1418438693, crsnum)
   if not sensor.valid then
      print("crs not valid")
      allvalid = false
   else
      course = sensor.value
   end
   
   local sensor = system.getSensorByID(1418438693, impnum)
   if not sensor.valid then
      print("imp not valid")
      allvalid = false
   else
      impulse = sensor.value      
      if impulse > 1.75 and f then -- if knob 8 to right, close data file
	 io.close(f)
	 f=nil
	 print("File gps.dat closed")
      end

      if impulse < 1.25 and gotInitPos then -- if knob 8 to left, reset inital position
	 gotInitPos = false
	 -- print("Reset initial position")
      end
   end
   
   
   if not allvalid then return end
   
   if latitude ~= lastlat and longitude ~= lastlong then
      lastlat = latitude
      lastlong = longitude

      if not gotInitPos then
	 L0 = longitude
	 y0 = rE*math.log(math.tan(( 45+latitude/2)/rad ) )
	 gotInitPos = true
      end

      x = rE*(longitude-L0)/rad
      y = rE*math.log(math.tan(( 45+latitude/2)/rad ) ) - y0

      table.insert(xtable, x)
      table.insert(ytable, y)
      table.insert(ztable, altitude)

      print("inserted -- #x: ", #xtable)

      if #xtable > 4 then
	 slope, compcrs = fslope(table.move(xtable, #xtable-4+1, #xtable, 1, {}),
				 table.move(ytable, #ytable-4+1, #ytable, 1, {}))
      else
	 slope = 0
	 compcrs = math.pi/2
      end

      compcrsDeg = compcrs*180/math.pi
      
      
      local now = system.getTimeCounter()   
      ss = string.format("Time: %.3f, Lg: %.6f, Lt: %.6f, At: %.1f", (now-t0)/1000., longitude, latitude, altitude)
      print(ss)
      ss = string.format("x, y, imp: %.4f, %.4f, %f", x, y,impulse)
      print(ss)
      ss = string.format("GPS course, cmpcrs: %f, %f", course, compcrsDeg)
      print(ss)
      if (f) then io.write(f, (now-t0)/1000., ", ", longitude, ", ", latitude, ", ",x, ", ",y, ", ",altitude, ", ",course, ", ",compcrsDeg, ", ", impulse, "\n") end

   end
   local newLoopTime = system.getTimeCounter()
   local loopDelta = newLoopTime - lastLoopTime

   lastLoopTime = newLoopTime
   
   if avgLoopTime ~=0 then
      avgLoopTime = avgLoopTime * 0.95 + 0.05* loopDelta
   else
      avgLoopTime = 1
   end
   
   loopCount = loopCount+1
   
   if loopCount > 100 then
      loopCount = 0
      -- print('TimA: Avg Loop Time: ', avgLoopTime)
   end
end -- loop

return {init=init, loop=loop, author="JETI model", version="1.0"}


