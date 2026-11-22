--[[
   FontDump: text metrics of every JETI font, for TestMitter's device profiles
   and for comparing the DS-24 (I) and DS-24 II fonts

   Writes Apps/FontDump/fontdump.out, one line per result (comma separated):
     #,FontDump,version,fw,device         header
     H,font,height                        lcd.getTextHeight(font)
     W,font,w32,w33,...,w126              getTextWidth of each ASCII char
     S,font,width,text                    getTextWidth of a test string
     F,font,flag,width                    "Hello World" with a style flag
     R,font,n1/w1,n2/w2,...               each ASCII char repeated n times
                                          (as many as fit in 110): width/n
                                          is its advance to ~0.1 px, since
                                          single-char widths are rounded
     L,font,w1/n/w,...                    the same for U+00A0..U+00FF in
                                          UTF-8 (degree, umlauts, ...): w1 =
                                          single width, w = n repeats
   Widths seem to stop at 150 on the emulator, hence the 110.
   The test strings include the lone Latin-1 byte 0xB0 (degree), as sensor
   units seem to carry it, next to the UTF-8 form.
     ERR,what,message                     a call that raised an error
   Fonts are named by their constants (FONT_NORMAL = 21 on 6.06 but 0 on
   5.08). One font per loop call, the file written at the end, to stay far
   from the CPU limit.

   On a TX: unzip FontDump.zip into the TX's Apps folder, add FontDump in
   Applications, wait for "FontDump: written" on the console (a few
   seconds), then copy Apps/FontDump/fontdump.out back.
--]]

local outFile = "Apps/FontDump/fontdump.out"
local FONTS = {"FONT_NORMAL", "FONT_BOLD", "FONT_MINI", "FONT_BIG", "FONT_MAXI"}
local FLAGS = {"FONT_REVERSED", "FONT_GRAYED", "FONT_XOR", "FONT_OR", "FONT_AND"}
local STRINGS = {"", " ", "  ", "W", "WW", "WWW", "WWWW", "i", "ii", "iiii",
   "Hello World", "0123456789", "-12.3", "100%", "m/s", "12:34:56",
   "\u{B0}", "\u{B0}C", "\u{E4}\u{F6}\u{FC}", "\u{C4}\u{D6}\u{DC}\u{DF}",
   "AV", "To", "WAVE", "DFM-Maps 10.0.1121a",
   "\xB0", "\xB0C", "23\xB0C", "23\u{B0}C", "\xB0F"}

local lines = {}
local step = 0
local done = false

local function out(...)
   local t = {...}
   for i = 1, #t do t[i] = tostring(t[i]) end
   lines[#lines + 1] = table.concat(t, ",")
end

local function try(what, f, ...)
   local ok, r = pcall(f, ...)
   if not ok then out("ERR", what, (tostring(r):gsub(",", ";"))); return nil end
   return r
end

local function doFont(name)
   local f = _ENV[name]
   if f == nil then out("ERR", name, "no such constant"); return end
   out("H", name, try(name .. " height", lcd.getTextHeight, f))
   local w = {"W", name}
   for c = 32, 126 do w[#w + 1] = try(name .. " char " .. c, lcd.getTextWidth, f, string.char(c)) end
   out(table.unpack(w))
   for _, s in ipairs(STRINGS) do
      out("S", name, try(name .. " string", lcd.getTextWidth, f, s), s)
   end
   for _, fl in ipairs(FLAGS) do
      local v = _ENV[fl]
      if v then out("F", name, fl, try(name .. "|" .. fl, lcd.getTextWidth, f | v, "Hello World")) end
   end
end

-- each char repeated as often as fits in 110 px, for its fractional advance
local function doRepeats(name)
   local f = _ENV[name]
   if f == nil then return end
   local r = {"R", name}
   for c = 32, 126 do
      local ch = string.char(c)
      local w1 = try(name .. " char " .. c, lcd.getTextWidth, f, ch) or 0
      local n = (w1 > 0) and math.max(1, math.min(20, 110 // w1)) or 20
      local w = try(name .. " rep " .. c, lcd.getTextWidth, f, string.rep(ch, n))
      r[#r + 1] = n .. "/" .. tostring(w)
   end
   out(table.unpack(r))
end

-- Latin-1 (U+00A0..U+00FF) in UTF-8: single width, then repeats as above
local function doLatin(name)
   local f = _ENV[name]
   if f == nil then return end
   local r = {"L", name}
   for c = 0xA0, 0xFF do
      local ch = utf8.char(c)
      local w1 = try(name .. " latin " .. c, lcd.getTextWidth, f, ch) or 0
      local n = (w1 > 0) and math.max(1, math.min(20, 110 // w1)) or 20
      local w = try(name .. " latin rep " .. c, lcd.getTextWidth, f, string.rep(ch, n))
      r[#r + 1] = tostring(w1) .. "/" .. n .. "/" .. tostring(w)
   end
   out(table.unpack(r))
end

-- write the lines collected so far, one io.write per line, and start a new
-- batch: 1.2 built the whole file (~10 KB) in one string at the end, and
-- the mono DS-16 (5.06) wrote an empty file
local nLines = 0
local function flush(mode)
   local fh = io.open(outFile, mode)
   if not fh then print("FontDump: could not open " .. outFile); return false end
   for i = 1, #lines do io.write(fh, lines[i], "\n") end
   io.close(fh)
   nLines = nLines + #lines
   lines = {}
   return true
end

local function init()
   local dev = system.getDeviceType()
   out("#", "FontDump", "1.3", system.getVersion(), dev)
   if not flush("w") then done = true end
end

local function loop()
   if done then return end
   step = step + 1
   -- three loop calls per font: the basic metrics, the ASCII repeats,
   -- then Latin-1
   local fi = (step + 2) // 3
   if FONTS[fi] then
      local part = (step - 1) % 3
      local ok, err = pcall(function()
	 if part == 0 then doFont(FONTS[fi])
	 elseif part == 1 then doRepeats(FONTS[fi])
	 else doLatin(FONTS[fi]) end
      end)
      if not ok then out("ERR", FONTS[fi], "part " .. part, (tostring(err):gsub(",", ";"))) end
      if not flush("a") then done = true end
      return
   end
   print("FontDump: written " .. outFile .. " (" .. nLines .. " lines)")
   done = true
end

return {init = init, loop = loop, author = "DFM", version = "1.3", name = "FontDump"}
