local M = {}

local savedXP =  {}
local savedYP =  {}
local savedPos = {}
local rgbHist =  {}
local MAXSAVED = 0
local heading
local rgb = {}
local rgbLast
local ribbon = {}

local colorSel = {
   "None",  "Altitude", "Speed",  "Rx1 Q",  "Rx1 A1",
   "Rx1 A2","Rx2 Q",    "Rx2 A1", "Rx2 A2", "P4"
}	 

function M.clearPos()
   rgbHist = {}
   savedPos = {}
   savedXP = {}
   savedYP = {}
end

function M.setMAX(max)

   MAXSAVED = math.max(0, math.min(max, 1000))

   local rp = 10
   for k = 1, rp, 1 do
      rgb[k] = {}
      rgb[k].r = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp)) / 2)
      rgb[k].g = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 2*math.pi/3)) / 2)
      rgb[k].b = math.floor(255 * (1 + math.cos(2*math.pi*0.7*(k-1)/rp - 4*math.pi/3)) / 2)
   end
   M.clearPos()
   return MAXSAVED
end



local function setTextColor()
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 or colorCode == 8 then
      lcd.setColor(0,0,0)
   else
      lcd.setColor(255,255,255)
   end
end

local function setColor(type)
   local colorCode = system.getProperty("Color")
   if colorCode <= 6 then -- white bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(0,255,0)
      end
   elseif colorCode == 7 then -- blue bg
      if type == "In" then
	 lcd.setColor(255,160,16)
      else
	 lcd.setColor(96,255,128)
      end
   elseif colorCode == 8 then -- yellow bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(96,255,128)
      end
   else -- black bg
      if type == "In" then
	 lcd.setColor(255,0,0)
      else
	 lcd.setColor(0,192,0)
      end
   end
end

function M.drawShape(col, row, shape, rotation, type)
   local sinShape, cosShape
   local ren = lcd.renderer()
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   setColor(type)
   ren:reset()
   for i, _ in pairs(shape) do
      ren:addPoint(
	 col + (shape[i][1]*cosShape - shape[i][2]*sinShape + 0.5),
	 row + (shape[i][1] * sinShape + shape[i][2] * cosShape + 0.5)
      )
   end
   ren:renderPolygon()
   setTextColor()
end

function M.drawNFZ(nfz, mapV, xp, yp)
   local ren = lcd.renderer()
   local n
   local x0,y0,r
   local npc=30
   for i in ipairs(nfz) do
      if nfz[i].type == "inside" then
	 setColor("In")
      else
	 setColor("Out")
      end
      if nfz[i].shape == "polygon" then
	 n = #nfz[i].xy
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j = 1, n+1, 1 do 
	    ren:addPoint(xp(nfz[i].xy[j % n + 1].x),
			 yp(nfz[i].xy[j % n + 1].y))
	 end
	 ren:renderPolyline(2,1.0)
      elseif nfz[i].shape == "circle" then
	 x0 = xp(nfz[i].xy[1].x)
	 y0 = yp(nfz[i].xy[1].y)
	 r = 320*nfz[i].radius/(mapV.xmax-mapV.xmin)
	 ren:reset()
	 ren:setClipping(0,0,319,159)
	 for j=0,npc,1 do
	    ren:addPoint(x0 + r * math.sin(2*math.pi*j/npc),
			 y0 + r * math.cos(2*math.pi*j/npc))
	 end
	 ren:renderPolyline(2,1.0)
      end
   end
   setTextColor()
end

local function gradientIndex(inval, min, max, bins, mod)
   -- for a value val, maps to the gradient rgb index for val from min to max
   local bin, val
   ribbon.currentValue  = inval
   if mod then val = (inval-1) % mod + 1 else val = inval end
   bin = math.floor(((bins - 1) * math.max(math.min((val - min) / (max-min),1),0) + 1) + 0.5)   
   ribbon.currentBin = bin
   return bin
end


function M.savePoints(mapV, curX, curY, lastX, lastY, xp, yp, settings)

   local jj
   --local dist = math.sqrt( (curX - lastX)^2 + (curY - lastY)^2)

   if curX ~= lastX or curY ~= lastY then -- and dist > 5 then -- new point
      heading = math.atan(curX-lastX, curY - lastY)

      ----------------------------------------



      ribbon.currentFormat = "%.f"
      if settings.colorSelect == 1 then -- none
	 jj = #rgb // 2 -- mid of gradient - right now this is sort of a yellow color
      elseif settings.colorSelect == 2 then -- altitude 0-600m
	 jj = gradientIndex(mapV.altitude, 0, 600, #rgb)
      elseif settings.colorSelect == 3 then -- speed 0-300 km/hr
	 jj = gradientIndex(mapV.speed, 0, 300, #rgb)
      elseif settings.colorSelect == 4 then -- Rx1 Q
	 jj = gradientIndex(system.getTxTelemetry().rx1Percent, 0, 100,  #rgb)
      elseif settings.colorSelect == 5 then -- Rx1 A1
	 jj = gradientIndex(system.getTxTelemetry().RSSI[1],    0, 100,  #rgb)
      elseif settings.colorSelect == 6 then -- Rx1 A2
	 jj = gradientIndex(system.getTxTelemetry().RSSI[2],    0, 100,  #rgb)
      elseif settings.colorSelect == 7 then -- Rx2 Q
	 jj = gradientIndex(system.getTxTelemetry().rx2Percent, 0, 100,  #rgb)
      elseif settings.colorSelect == 8 then -- Rx2 A1
	 jj = gradientIndex(system.getTxTelemetry().RSSI[3],    0, 100,  #rgb)
      elseif settings.colorSelect == 9 then -- Rx2 A2
	 jj = gradientIndex(system.getTxTelemetry().RSSI[4],    0, 100,  #rgb)
      elseif settings.colorSelect == 10 then -- P4
	 jj = gradientIndex((1+system.getInputs("P4"))*50, 0,   100,  #rgb)	   
      else
	 print("ribbon color bad idx")
      end
      

      ----------------------------------------
      if #savedXP+1 > MAXSAVED then
	 table.remove(savedPos, 1)
	 table.remove(savedXP, 1)
	 table.remove(savedYP, 1)
	 table.remove(rgbHist, 1)
      else
	 table.insert(savedPos, mapV.curPos)
	 table.insert(savedXP, xp(curX))
	 table.insert(savedYP, yp(curY))
	 table.insert(rgbHist, {r=rgb[jj].r, g=rgb[jj].g, b=rgb[jj].b,
				rgb = rgb[jj].r*256*256+ rgb[jj].g*256 + rgb[jj].b})
      end
      --local rr = rgbHist[#rgbHist]
      --print(settings.colorSelect, #savedXP, jj, rr.r, rr.g, rr.b, rr.rgb)

      lastX = curX
      lastY = curY
   end
   
   return lastX, lastY, heading
end


function M.drawRibbon(xp, yp, curX, curY, settings)
   lcd.setColor(lcd.getFgColor())
   local rh
    --[[
   if MAXSAVED < 128 then
      local ren = lcd.renderer()
      ren:reset()
      rgbLast = -1
           for i=1,#savedXP do
	 rh = rgbHist[i]
	 if rh.rgb ~= rgbLast then
	    ren:addPoint(savedXP[i], savedYP[i])
	    ren:renderPolyline(1,0.7)
	    ren:reset()
	    lcd.setColor(rh.r, rh.g, rh.b)
	    rgbLast = rh.rgb
	 end
	 ren:addPoint(savedXP[i], savedYP[i])
      end
      ren:addPoint(xp(curX), yp(curY))
      ren:renderPolyline(1,0.7)
      else
      --]]
      if #savedXP > 1 then
	 rgbLast = -1
	 for i=2,#savedXP do
	    rh = rgbHist[i-1]
	    if rh.rgb ~= rgbLast and settings.colorSelect ~= 1 then
	       --print(i, rh.r, rh.g, rh.b)
	       lcd.setColor(rh.r, rh.g, rh.b)
	       rgbLast = rh.rgb
	    end
	    lcd.drawLine(savedXP[i-1], savedYP[i-1], savedXP[i], savedYP[i])
	 end
	 lcd.drawLine(savedXP[#savedXP], savedYP[#savedXP], xp(curX), yp(curY))
      end
   --end

   if settings.colorSelect > 1 then
      lcd.setColor(rgb[ribbon.currentBin].r, rgb[ribbon.currentBin].g, rgb[ribbon.currentBin].b)
      lcd.drawFilledRectangle(210 , 148, 6,6)
      setTextColor()
      lcd.drawText(220, 145, colorSel[settings.colorSelect], FONT_MINI)
   end
   
   setTextColor()

   if select(2, system.getDeviceType()) == 1 then
      lcd.drawText(40, 145, "P: "..#savedXP.."   CPU: "..system.getCPU(), FONT_MINI)
   end

end

return M
