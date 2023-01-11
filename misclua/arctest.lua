--[[

   arctest.lua - app to demonstrate arc drawing
   DFM 01/06/2023
   
   local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)
   
   theta is the amount of the full arc to draw in radians (0 to aR)
   x0 and y0 are arc center in pixels
   a0 and aR are the starting and ending points of the complete arc in radians
   ri and ro are inner and outer radius in pixels
   im is the number of segmemts in the polygon approximation of the arc
   alp is the transparency factor (see render documentation)
   
   note that a0 needs a 90 degree shift for the arc to be vertical and aR
   is the "distance" in radians from a0
   
--]]

local function arcSegment(x0, y0, a0, aR, ri, ro, im, alp)

   local ren = lcd.renderer()
   
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + (i-1)*(aR-a0)/im),
		   y0 - ro * math.sin(a0 + (i-1)*(aR-a0)/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(aR), y0 - ro * math.sin(aR))
   ren:addPoint(x0 - ri * math.cos(aR), y0 - ri * math.sin(aR))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+(i-1)*(aR-a0)/im),
		   y0 - ri * math.sin(a0+(i-1)*(aR-a0)/im))
   end
   
   --lcd.setColor(lcd.getFgColor())
   ren:renderPolygon(alp)

end

local function drawArc(theta, x0, y0, a0, aR, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*theta/im), y0 - ro * math.sin(a0 + i*theta/im))
   end
   
   ren:addPoint(x0 - ro * math.cos(a0+theta), y0 - ro * math.sin(a0+theta))
   ren:addPoint(x0 - ri * math.cos(a0+theta), y0 - ri * math.sin(a0+theta))
   
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*theta/im), y0 - ri * math.sin(a0+i*theta/im))
   end
   
   --lcd.setColor(lcd.getFgColor())
   ren:renderPolygon(alp)
end

local function drawBackArc(x0, y0, a0, aR, ri, ro, im, alp)
   local ren = lcd.renderer()
   ren:reset()
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   ren:addPoint(x0 - ro * math.cos(a0), y0 - ro * math.sin(a0))   
   for i=1,im-1,1 do
      ren:addPoint(x0 - ro * math.cos(a0 + i*aR/im), y0 - ro * math.sin(a0 + i*aR/im))
   end
   ren:addPoint(x0 - ro * math.cos(a0+aR), y0 - ro * math.sin(a0+aR))
   ren:addPoint(x0 - ri * math.cos(a0+aR), y0 - ri * math.sin(a0+aR))
   for i=im-1,1,-1 do
      ren:addPoint(x0 - ri * math.cos(a0+i*aR/im), y0 - ri * math.sin(a0+i*aR/im))
   end
   ren:addPoint(x0 - ri * math.cos(a0), y0 - ri * math.sin(a0))
   lcd.setColor(200,200,200)
   ren:renderPolygon(alp) -- use this line for filled background
   lcd.setColor(lcd.getFgColor())
   ren:renderPolyline(2) -- use this line for outline background

end

local function loop()
end

local function printForm()

   local theta = math.rad(270)
   local x0, y0 = 160, 80
   local a0 = math.rad(-135 + 90)
   local aR = theta
   local ri, ro
   local im 
   local alp = 1
   local colors = {{255,0,0},{0,255,0},{0,0,255}, {255,255,0}, {0,255,255},{255,0,255},{0,0,0}}

   -- vary the amount of arc drawn
   local ctl5 = system.getInputs("P5")
   ctl5 = (ctl5 + 1) / 2

   -- vary the width of the arc
   local ctl6 = system.getInputs("P6")
   ctl6 = (ctl6 + 1) / 2

   --vary the number of segments
   local ctl7 = system.getInputs("P7")
   ctl7 = (ctl7 + 1) / 2   

   ri = 60
   ro = ri + ctl6 * 60
   im = 20

   local nc = #colors
   local ts = theta/ nc
   local iLow = math.max(math.min((theta*ctl5 - ts/4)// ts, nc-1), 0)
   local tLow = iLow * ts
   
   local ccL
   local ccP
   
   ccL = colors[iLow + 1]

   if iLow > 0 then
      ccP = colors[iLow]
   else
      ccP = ccL
   end

   if iLow + 2 <= nc then
      ccH = colors[iLow + 2]
   else
      ccH = ccL
   end

   local alpha = (theta*ctl5 - tLow - ts/4) / ts
   --print(iLow, tLow, alpha)

   local r,g,b

   local thr = 1
   
   if alpha > thr then
      print(alpha, ">0.75")
      r = ccL[1] * alpha + ccH[1] * (1-alpha)
      g = ccL[2] * alpha + ccH[2] * (1-alpha)
      b = ccL[3] * alpha + ccH[3] * (1-alpha)      
   elseif alpha < 1-thr then
      print(alpha, "<0.25")
      r = ccP[1] * alpha + ccL[1] * (1-alpha)
      g = ccP[2] * alpha + ccL[2] * (1-alpha)
      b = ccP[3] * alpha + ccL[3] * (1-alpha)
   else
      print(alpha, "pure")
      r = ccL[1]
      g = ccL[2]
      b = ccL[3]
   end
      
   lcd.setColor(r,g,b)
   --print(math.deg(ts), ctl5*math.deg(theta), iLow)
   drawArc(theta*ctl5, x0, y0, a0, aR, ri, ro, im, alp)

   x0 = 220

   local nseg = nc
   local im = 0.3*270/nseg
   local tseg = math.floor(ctl5 * nseg)
   
   for i=1,tseg,1 do
      local f = aR/nseg
      local ai = a0 + (i-1)*f
      local af = a0 + i*f
      local cc = colors[1+(i-1)%nc]
      --print(i, 1+(i-1)%nc)
      lcd.setColor(cc[1], cc[2], cc[3])
      arcSegment(x0, y0, ai, af, ri, ro, im, alp)
   end

   lcd.setColor(lcd.getFgColor())
   local str = string.format("Segments: %d", im)
   lcd.drawText(160 - lcd.getTextWidth(FONT_NORMAL, str)/2, 140, str)

   str = string.format("Theta: %d°", math.deg(theta * ctl5))
   lcd.drawText(160 - lcd.getTextWidth(FONT_NORMAL, str)/2, 125, str)

   str = string.format("CPU: %d%%", system.getCPU())
   lcd.drawText(240, 140, str)		       
   
   local ren = lcd.renderer()

   alp = 1.0
   ren:reset()
   ren:addPoint(226,59)
   ren:addPoint(231,41)
   ren:addPoint(313,26)
   ren:addPoint(392,26)
   ren:renderPolygon(alp)

   
end

local function init()

   print(system.registerTelemetry(1, "arctest window", 4, printForm))

end

return {init=init, loop=loop, author="DFM", version="1", name="arctest.lua"}


