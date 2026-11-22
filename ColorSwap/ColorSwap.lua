--[[
   ColorSwap 2.0: two renderer problems on the DS-24 II, for JETI (Radek)

   1. A polyline of more than 131 points draws wrong. One renderer, 132 or
      more addPoint calls, one renderPolyline: instead of the line it draws
      a filled shape, and gives no error. Measured on the emulator (6.06)
      with ColorSwap 1.3-1.5: 131 points is fine and 132 fails, at line
      widths 1, 2 and 4 alike, so the limit is on the number of points,
      not on the line width. Direct and off-screen rendering fail the same.
   2. Off-screen rendering may swap red and blue (seen on the DS-24 II).

   Both windows are full screen (size 5) in native drawing mode
   (system.setProperty("NativeDraw", 1) in init). Each shows two spirals of
   the same shape, the left one 131 points and the right one 132 points,
   each drawn as ONE red polyline of width 2. Under each polyline the same
   spiral is drawn first as a thin grey line with lcd.drawLine, so a
   correct polyline covers the grey line and a wrong one shows against it.

   - Window 1 ("ColorSwap direct"): lcd.renderer() straight to the screen.
   - Window 2 ("ColorSwap off-screen"): rendered once into a blank image
     from lcd.createImage with lcd.renderer(image), as DFM-Maps draws its
     flight path, then shown with lcd.drawImage.

   Expected: in both windows the left spiral is a red line and the right
   one a filled red shape.

   Colours: both windows have R G B boxes drawn straight to the screen
   (lcd.drawFilledRectangle). Window 2 also has the same boxes rendered
   into the image, on the row below. If off-screen colours swap red and
   blue, window 2's image boxes don't match the ones above them, and its
   spirals come out blue.

   The spiral: t from 0 to 60 over the points, radius R_MAX * t / 60,
   angle 2 * pi * t / 10 (6 turns): x = r * cos(angle), y = r * sin(angle).
--]]

local appName = "ColorSwap"
local version = "2.0"

local GOOD, BAD = 131, 132 -- the last good point count and the first bad one
local WIDTH = 2
local T_END, TURN_S, R_MAX = 60, 10, 105
local COLORS = {{255, 0, 0, "R"}, {0, 255, 0, "G"}, {0, 0, 255, "B"}}

local img -- window 2's off-screen image, made on its first draw
local directRen

-- n points of the spiral around (cx, cy)
local function spiral(n, cx, cy)
   local pts = {}
   for i = 0, n - 1 do
      local t = T_END * i / (n - 1)
      local r = R_MAX * t / T_END
      local a = 2 * math.pi * t / TURN_S
      pts[#pts + 1] = {x = cx + r * math.cos(a), y = cy + r * math.sin(a)}
   end
   return pts
end

-- the two spirals' centres and point counts
local function spirals(w, h)
   local cy = 60 + (h - 60) // 2
   return {{GOOD, w // 4, cy}, {BAD, 3 * w // 4, cy}}
end

-- the grey drawLine reference
local function reference(pts)
   lcd.setColor(160, 160, 160)
   for i = 2, #pts do
      lcd.drawLine(pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y)
   end
end

-- one red polyline through every point
local function polyline(ren, pts)
   lcd.setColor(255, 0, 0)
   ren:reset()
   for _, p in ipairs(pts) do ren:addPoint(p.x, p.y) end
   ren:renderPolyline(WIDTH)
end

-- R G B boxes straight to the screen, with their letters
local function directBoxes(x, y, label)
   lcd.setColor(0, 0, 0)
   lcd.drawText(x, y, label, FONT_MINI)
   for k, c in ipairs(COLORS) do
      lcd.setColor(c[1], c[2], c[3])
      lcd.drawFilledRectangle(x + 70 + (k - 1) * 50, y, 30, 14)
      lcd.setColor(0, 0, 0)
      lcd.drawText(x + 70 + (k - 1) * 50 + 34, y, c[4], FONT_MINI)
   end
end

-- the text over each spiral and the caption
local function labels(w, h, how)
   lcd.setColor(0, 0, 0)
   for _, s in ipairs(spirals(w, h)) do
      local txt = s[1] .. " points"
      lcd.drawText(s[2] - lcd.getTextWidth(FONT_MINI, txt) // 2, 50, txt, FONT_MINI)
   end
   lcd.drawText(240, 4, how, FONT_MINI)
   lcd.drawText(240, 24, "one polyline each, width " .. WIDTH, FONT_MINI)
end

-- window 1: the renderer straight to the screen, every frame
local function printDirect(w, h)
   for _, s in ipairs(spirals(w, h)) do
      local pts = spiral(s[1], s[2], s[3])
      reference(pts)
      if directRen then polyline(directRen, pts) end
   end
   directBoxes(4, 4, "direct")
   labels(w, h, "renderer to the screen")
end

-- window 2: render once into an image, then draw the image every frame
local function renderImage(w, h)
   img = lcd.createImage(w, math.min(h, 360)) -- createImage's limit: 480 x 360
   if not img then return end
   local ren = lcd.renderer(img)
   if not ren then img = nil; return end
   for _, s in ipairs(spirals(w, h)) do
      polyline(ren, spiral(s[1], s[2], s[3]))
   end
   -- the same boxes as directBoxes, rendered into the image, one row lower
   for k, c in ipairs(COLORS) do
      local x, y = 4 + 70 + (k - 1) * 50, 24
      lcd.setColor(c[1], c[2], c[3])
      ren:reset()
      ren:addPoint(x, y)
      ren:addPoint(x + 30, y)
      ren:addPoint(x + 30, y + 14)
      ren:addPoint(x, y + 14)
      ren:renderPolygon()
   end
end

local function printOffscreen(w, h)
   if not img then renderImage(w, h) end
   for _, s in ipairs(spirals(w, h)) do reference(spiral(s[1], s[2], s[3])) end
   if img then
      lcd.drawImage(0, 0, img)
   else
      lcd.setColor(0, 0, 0)
      lcd.drawText(4, 60, "createImage/renderer failed", FONT_NORMAL)
   end
   directBoxes(4, 4, "direct")
   lcd.setColor(0, 0, 0)
   lcd.drawText(4, 24, "image", FONT_MINI)
   labels(w, h, "renderer into createImage")
end

local function init()
   system.setProperty("NativeDraw", 1)
   directRen = lcd.renderer()
   system.registerTelemetry(1, appName .. " direct", 5, printDirect)
   system.registerTelemetry(2, appName .. " off-screen", 5, printOffscreen)
   print(string.format("%s %s: NativeDraw = %s, polylines of %d and %d points",
		       appName, version, tostring(system.getProperty("NativeDraw")),
		       GOOD, BAD))
end

return {init = init, author = "DFM", version = version, name = appName}
