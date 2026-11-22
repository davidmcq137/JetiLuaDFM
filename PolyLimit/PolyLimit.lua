--[[
   PolyLimit 2.0: the renderer's point limits, for JETI (Radek)

   One renderer call has room for 256 points; past that it fails without
   an error. Measured on the emulator (6.06), the same direct and
   off-screen:

   - renderPolygon keeps the FIRST 256 points and silently drops the rest.
     The shape is closed from point 256 straight back to point 1. A circle
     of 512 points (starting at 3 o'clock, clockwise) draws as a half disc.
     Circles of 300, 400, 700 and 1000 points fill exactly from 0 to 256/n
     of a turn, closed by a chord.
   - renderPolyline goes wrong from about 128 points. Its outline probably
     needs about two points per input point, one each side of the line.
     Past the limit the end of the line becomes a filled wedge. A small
     overrun can be invisible, so where it shows depends on the shape: an
     open 3/4 arc looked right at 140 points and wrong at 160, a 6-turn
     spiral (ColorSwap) wrong from 132. The line width (1, 2, 4) makes no
     difference.

   Each window shows four shapes, with a grey lcd.drawCircle / drawLine
   where each belongs:
   - top: renderPolygon, filled circles of 256 points (correct) and 512
     points (a half disc)
   - bottom: renderPolyline(2), open 3/4 arcs of 128 points (correct) and
     200 points (a filled wedge at the end)

   - Window 1 ("PolyLimit direct"): lcd.renderer() straight to the screen.
   - Window 2 ("PolyLimit off-screen"): rendered once into a blank image
     from lcd.createImage with lcd.renderer(image), then lcd.drawImage.

   Both windows are full screen (size 5), in native drawing mode
   (system.setProperty("NativeDraw", 1) in init).

   History (PolyLimit 1.0-1.3, emulator 6.06): circles of 130-133 points
   and polygons of 256-270 points looked right, because a few lost points
   of a circle change it by under a pixel.
--]]

local appName = "PolyLimit"
local version = "2.0"

-- {addPoint calls, kind}: the left one of each pair is within the limit
local SHAPES = {
   {256, "polygon"}, {512, "polygon"},
   {128, "arc"},     {200, "arc"},
}
local R = 62     -- radius, px
local WIDTH = 2  -- polyline width

local img        -- window 2's image, made on its first draw
local directRen

-- the shapes' centres: two rows of two, {x, y, points, kind}
local function centres(w, h)
   local cs = {}
   local y1 = 70 + 18 + R
   local y2 = y1 + 2 * R + 30
   for i, s in ipairs(SHAPES) do
      local x = (i % 2 == 1) and w // 4 or 3 * w // 4
      cs[i] = {x, i <= 2 and y1 or y2, s[1], s[2]}
   end
   return cs
end

-- n points: a full circle without repeating the start ("polygon"), or an
-- open three-quarter arc from the start to the end ("arc"); both start at
-- 3 o'clock and go clockwise
local function points(cx, cy, n, kind)
   local pts = {}
   for i = 0, n - 1 do
      local a = kind == "polygon" and 2 * math.pi * i / n or 1.5 * math.pi * i / (n - 1)
      pts[#pts + 1] = {cx + R * math.cos(a), cy + R * math.sin(a)}
   end
   return pts
end

local function shapes(ren, w, h)
   for _, c in ipairs(centres(w, h)) do
      ren:reset()
      for _, p in ipairs(points(c[1], c[2], c[3], c[4])) do ren:addPoint(p[1], p[2]) end
      lcd.setColor(255, 0, 0)
      if c[4] == "polygon" then ren:renderPolygon() else ren:renderPolyline(WIDTH) end
   end
end

-- the grey references, labels and caption, straight to the screen
local function overlay(w, h, how)
   for _, c in ipairs(centres(w, h)) do
      lcd.setColor(150, 150, 150)
      local txt
      if c[4] == "arc" then
	 local pts = points(c[1], c[2], c[3], "arc")
	 for i = 2, #pts do
	    lcd.drawLine(pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2])
	 end
	 txt = "renderPolyline, " .. c[3] .. " points"
      else
	 lcd.drawCircle(c[1], c[2], R)
	 txt = "renderPolygon, " .. c[3] .. " points"
      end
      lcd.setColor(0, 0, 0)
      lcd.drawText(c[1] - lcd.getTextWidth(FONT_MINI, txt) // 2, c[2] - R - 18, txt, FONT_MINI)
   end
   lcd.setColor(0, 0, 0)
   lcd.drawText(4, 4, appName .. " " .. version .. ": polygon max 256 points, polyline ~128", FONT_MINI)
   lcd.drawText(4, 22, "red = renderer, grey = where it belongs", FONT_MINI)
   lcd.drawText(4, 40, how, FONT_MINI)
end

local function printDirect(w, h)
   if directRen then shapes(directRen, w, h) end
   overlay(w, h, "renderer to the screen")
end

local function printOffscreen(w, h)
   if not img then
      img = lcd.createImage(w, math.min(h, 360)) -- createImage's limit: 480 x 360
      local ren = img and lcd.renderer(img)
      if ren then shapes(ren, w, h) else img = nil end
   end
   if img then
      lcd.drawImage(0, 0, img)
   else
      lcd.setColor(0, 0, 0)
      lcd.drawText(4, 60, "createImage/renderer failed", FONT_NORMAL)
   end
   overlay(w, h, "renderer into createImage, then drawImage")
end

local function init()
   system.setProperty("NativeDraw", 1)
   directRen = lcd.renderer()
   system.registerTelemetry(1, appName .. " direct", 5, printDirect)
   system.registerTelemetry(2, appName .. " off-screen", 5, printOffscreen)
   print(appName .. " " .. version .. ": NativeDraw = " ..
	 tostring(system.getProperty("NativeDraw")))
end

return {init = init, author = "DFM", version = version, name = appName}
