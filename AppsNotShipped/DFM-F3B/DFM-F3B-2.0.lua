--[[

   ----------------------------------------------------------------------------
   DFM-F3B.lua released under MIT license by DFM 2022

   This app was originally created at the suggestion of Tim Bischoff. It is
   intended to facilitate practice flights for the new F3G electric glider
   competition

   This is the basic F3B version with minimal function per requirements 
   from Jeroen Smits
   ----------------------------------------------------------------------------
   
--]]

local F3BVersion = "2.0"

local telem = {
   Lalist={"..."},
   Idlist={"..."},
   Palist={"..."}
}

local sens = {
   {var="lat",  label="Latitude"},
   {var="lng",  label="Longitude"}
}

local ctl = {
   {var="arm", label="Arming"}
}

local distAB
local gpsScale

local flightZone
local lastFlightZone
local zone = {[0]=1,[1]=2,[3]=3}

local curDist
local curBear
local curPos
local zeroPos
local zeroLatString
local zeroLngString
local initPos
local curX, curY
local lastX, lastY
local rotA

local detA, detB
local dA, dB, dd
local perpA, perpB

local early = 0
local gotTelemetry, hasPopped

local highWater = 0
local forceTeleInit

local function prefix()
   local pf
   if (select(2, system.getDeviceType()) == 1) then pf = "" else pf = "/" end
   return pf
end

local function keyForm(key)
   if key == KEY_1 then
      zeroPos = curPos
      if zeroPos then
	 zeroLatString, zeroLngString = gps.getStrig(zeroPos)
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_2 then
      if curBear then
	 rotA = math.rad(curBear-90)
	 gpsScale = 1.0
	 system.messageBox("GPS scale factor reset to 1.0")
      else
	 system.messageBox("No Current Position")
      end
   elseif key == KEY_3 then
      system.messageBox("Exit menu to TX main screen")
      hasPopped = false
   elseif key == KEY_4 then
      if gpsScale ~= 1.0 then
	 system.messageBox("Do DirB first")
	 return
      end
      if curX and curY then
	 gpsScale = 150.0/math.sqrt(curX^2 + curY^2)
      end
   end

   if zeroLatString and zeroLngString and rotA and gpsScale and (key >= KEY_1) and (key <= KEY_4) then
      local save = {}
      save.zeroLatString = zeroLatString
      save.zeroLngString = zeroLngString
      save.rotA = rotA * 1000
      save.gpsScale = gpsScale * 1000
      local fp = io.open(prefix() .. 'Apps/DFM-F3B/GPS.jsn', "w")
      if fp then
	 io.write(fp, json.encode(save), "\n")
	 io.close(fp)
      end
   end
end

local function ctlChanged(val, ctbl, v)
   local ss = system.getSwitchInfo(val)
   if ss.assigned == false then
      ctbl[v] = nil
   else
      ctbl[v] = val
   end
   system.pSave(v.."Ctl", ctbl[v])
end

local function initForm(sf)
   if sf == 1 then
      form.setTitle("F3B Practice")

      form.setButton(1, "Pt A",  ENABLED)
      form.setButton(2, "Dir B", ENABLED)
      form.setButton(3, "Fields", ENABLED)      
      form.setButton(4, "C 150", ENABLED)
      
      for i in ipairs(ctl) do
	 form.addRow(2)
	 form.addLabel({label=ctl[i].label, width=220})
	 form.addInputbox(ctl[ctl[i].var], true, (function(x) return ctlChanged(x, ctl, ctl[i].var) end) )
      end
      
      form.addRow(1)
      form.addLink((function()
	       initPos = nil
	       curPos = nil
	       zeroPos = nil
	       zeroLatString = nil
	       zeroLngString = nil
	       gpsScale = 1
	       rotA = nil
	       curDist = nil
	       curBear = nil
	       io.remove(prefix() .. 'Apps/DFM-F3B/GPS.jsn')
	       system.messageBox("GPS data reset")
	       form.reinit(1)
		   end),
	 {label = "Reset saved GPS info"})
   end
end

local function det(x1, y1, x2, y2, x, y)
   return (x-x1)*(y2-y1) - (y-y1)*(x2-x1)
end

local function pDist(x1, y1, x2, y2, x, y)
   return math.abs( (x2-x1)*(y1-y) - (x1-x)*(y2-y1) ) / math.sqrt( (x2-x1)^2 + (y2-y1)^2)
end

local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function varCB(ff)
   local bPos, bearing, distance
   zeroLatString = ff.Lat
   zeroLngString = ff.Lng
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end
   if ff.gpsScale then -- in case no gpsScale
      gpsScale = ff.gpsScale / 1000.0
   else
      gpsScale = 1.0
   end
   -- if rotA is specified, it is x1000
   -- if LatB and LngB are specified as point B it overrides rotA
   -- (if both are specified)
   if ff.rotA then
      rotA = ff.rotA / 1000.0
   elseif ff.LatB and ff.LngB then
      bPos = gps.newPoint(ff.LatB, ff.LngB)
      distance = gps.getDistance(zeroPos, bPos)
      bearing = gps.getBearing(zeroPos, bPos)
      rotA = math.rad(bearing-90)
      --print("d,b,r", distance, bearing, rotA)
   else
      rotA = 0
   end
end

local function loop()

   local gcc = collectgarbage("count")
   if gcc > highWater then
      highWater = gcc
      --print("gcc loop highWater", gcc)
   end
   
   local swa, latS, lngS
   
   if sens.lat.SeId and sens.lat.SePa and sens.lng.SePa then
      local lt, lg
      latS = system.getSensorValueByID(sens.lat.SeId, sens.lat.SePa)
      lngS = system.getSensorValueByID(sens.lng.SeId, sens.lng.SePa)
      if latS and lngS and latS.valid and lngS.valid then
	 curPos = gps.getPosition(sens.lat.SeId, sens.lat.SePa, sens.lng.SePa)
	 lt, lg = gps.getValue(curPos)
      else
	 curPos = nil
      end
      if curPos and (lt ~= 0) and (lg ~= 0) then gotTelemetry = true end
   else
      gotTelemetry = false
   end

   if gotTelemetry and not hasPopped and not form.getActiveForm() then
      local M = require "DFM-F3B/fieldPopUp"
      M.fieldPopUp(curPos, varCB)
      M = nil
      package.loaded["DFM-F3B/fieldPopUp"] = false
      collectgarbage()
      hasPopped = true
   end
   
   if curPos and zeroPos then
      if not initPos then
	 initPos = curPos
	 --if not zeroPos then zeroPos = curPos end
      end

      curDist = gps.getDistance(zeroPos, curPos)
      curBear = gps.getBearing(zeroPos, curPos)

      curX = curDist * math.cos(math.rad(curBear+270)) -- why not same angle X and Y??
      curY = curDist * math.sin(math.rad(curBear+90))

      if not lastX then lastX = curX end
      if not lastY then lastY = curY end
      
      curX, curY = rotateXY(curX, curY, rotA or 0)

      if gpsScale then
	 curX = curX * gpsScale
      end
      
      if curX ~= lastX or curY ~= lastY then
	 lastX = curX
	 lastY = curY
      end
      
      detA = det(0,-50,0,50,curX,curY)
      detB = det(distAB-early,-50, distAB-early, 50,curX,curY)
      
      if detA > 0 then dA = 1 else dA = 0 end
      if detB > 0 then dB = 1 else dB = 0 end
      
      dd = dA + 2*dB
      
      perpA = pDist(0,-50,0,50,curX, curY)
      perpB = pDist(distAB-early,-50,distAB-early, 50, curX, curY)
      
      if detA < 0 then perpA = -perpA end
      if detB > 0 then perpB = -perpB end
      
      if dd then
	 flightZone = zone[dd]
	 if not lastFlightZone then lastFlightZone = flightZone end
      end
   end

   swa = system.getInputsVal(ctl.arm)

   if (flightZone == 3 and lastFlightZone == 2) or (flightZone == 1 and lastFlightZone == 2) then
      if not swa or swa == 1 then
	 system.playBeep(0,440,500)
	 print("Beep")
      end
   end

   lastFlightZone = flightZone
end

local function getAB()
   local pa, pb
   local z = zeroLatString and zeroLngString   

   if rotA and perpA and z and math.abs(perpA) < 1000 then
      pa = string.format("A %.1f", perpA)
   elseif perpA and math.abs(perpA) >= 1000 then
      pa = "A > 1 km"
   else
      pa = "A ---"
   end
   
   if rotA and perpB and z and math.abs(perpB) < 1000 then
      pb = string.format("B %.1f", perpB)
   elseif perpB and math.abs(perpB) >= 1000 then
      pb = "B > 1 km"
   else
      pb = "B ---"
   end
   return pa, pb
end

local function formTele()
   local pa, pb
   pa, pb = getAB()
   local ss
   local lt, lg
   if curPos then
      lt, lg = gps.getStrig(curPos)
      ss = "["..lt .. ","..lg.."]"
   else
      ss = ""
   end
   
   if curDist and curBear then
      ss = string.format("Dist %.2f Bearing %.0f° ", curDist, curBear) .. ss
      lcd.drawText(10, 120, ss, FONT_MINI)
   else
      lcd.drawText(10, 120, "Dist --- Bearing --- " .. ss, FONT_MINI)
   end
   lcd.drawText(10,100, pa .. "  "..pb)
end

local xmin, xmax = -110, 290
local ymin, ymax =  -80, 120

local function xp(x)
   return 320 * (x - xmin) / (xmax - xmin)
end

local function yp(y)
   return 160 *(1 -  (y - ymin) / (ymax - ymin))
end

local function xTele(x0, y0)
   local pa
   local pb
   pa, pb = getAB()
   lcd.drawText(x0+0,y0+0,pa, FONT_MAXI)
   lcd.drawText(x0+0,y0+30, pb, FONT_MAXI)
end

--[[
local function fullTele()
   lcd.setColor(0,0,0)
   lcd.drawLine(xp(-50), yp(0), xp(200), yp(0))
   lcd.drawLine(xp(0), yp(-50), xp(0), yp(110))
   --lcd.setColor(200,200,200)
   --lcd.drawLine(xp(150), yp(-10), xp(150), yp(130))
   lcd.drawLine(xp(150), yp(-50), xp(150), yp(110))
   lcd.drawText(xp(0) - 4, yp(-50), "A")
   lcd.drawText(xp(150) - 4, yp(-50), "B")
   if curX and curY and curX >= xmin and curX <= xmax and curY >= ymin and curY <= ymax then
      lcd.drawFilledRectangle(xp(curX)-3, yp(curY)-3, 6, 6)
      local ss
      ss = string.format("X: %3d", curX)
      lcd.drawText(10, 115, ss)
      ss = string.format("Y: %3d", curY)
      lcd.drawText(10, 135, ss)
   end
   xTele(90, 0)
end
--]]

local function printTele()
   xTele(0,0)
end

local function init()

   local p1, p2
   p1, p2 = system.getInputs("P1", "P2")

   if p1 < -0.8 and p2 < -0.8 then forceTeleInit = true else forceTeleInit = false end

   local gotSe = 0
   
   for i in ipairs(sens) do
      local v = sens[i].var
      if not sens[v] then sens[v] = {} end
      sens[v].Se = system.pLoad(v.."Se", 0)
      sens[v].SeId = system.pLoad(v.."SeId", 0)
      sens[v].SePa = system.pLoad(v.."SePa", 0)
      --print(i, sens[v].Se, sens[v].SeId, sens[v].SePa)
      if sens[v].SeId ~= 0 and sens[v].SePa ~= 0 then gotSe = gotSe + 1 end
   end

   for i in ipairs(ctl) do
      local v = ctl[i].var
      ctl[v] = system.pLoad(v.."Ctl")
   end

   distAB = 150

   local jtext = io.readall(prefix() .. 'Apps/DFM-F3B/GPS.jsn')

   if jtext then
      local jj = json.decode(jtext)
      if jj then
	 system.messageBox("Reading globally saved GPS data")
	 zeroLatString = jj.zeroLatString
	 zeroLngString = jj.zeroLngString
	 gpsScale = jj.gpsScale / 1000.0
	 rotA = jj.rotA / 1000.0
      end
   else
      zeroLatString = nil
      zeroLngString = nil
      gpsScale = 1 
      rotA = nil
   end
   
   if zeroLatString and zeroLngString then
      zeroPos = gps.newPoint(zeroLatString, zeroLngString)
   end

   system.registerForm(1, MENU_APPS, "F3B", initForm, keyForm, formTele)
   system.registerTelemetry(1, "F3B Status", 2, printTele)
   --[[
   system.registerTelemetry(2, "F3B Map", 4, fullTele)   
   --]]
   
   gotTelemetry = false
   hasPopped = false

   local M = require "DFM-F3B/readSensors"

   if gotSe < #sens or forceTeleInit then
      M.readSensors(sens)
   else
      M.readSensors()
   end

   M = nil
   package.loaded["DFM-F3B/readSensors"] = false

   collectgarbage()

   print("DFM-F3B/init: gcc " .. collectgarbage("count"))

end
--------------------------------------------------------------------------------

return {init=init, loop=loop, author="DFM", version=F3BVersion, name="F3B"}
