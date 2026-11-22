--[[
   ImgBudget: what loading images costs against the DS-24 II Lua time budget

   For JETI (Radek, Radim). Since 6.05 the DS-24 II charges each Lua
   callback its wall time against a 10 ms budget (by default). One
   lcd.loadImage includes the PNG decode, and that alone uses or exceeds the
   whole budget, even for small images. An app that must show large images
   can either load them while running (killed, unless the pilot finds the
   300% setting) or load them all in init (limited by memory). This app
   measures both.

   1. Loop loads (menu: "Loop loads" on). loop() loads one image every
      2 s, smallest first, round after round: an 8x8 icon, a 228x171
      panel quarter (palette and RGB), a 456x342 panel (palette and RGBA)
      and a 456x342 background (palette and RGB); then the same background
      and a DFM-Maps field image as baseline JPEG at several qualities, to
      compare JPEG and PNG decode times. The full-screen window
      shows each image's load time in ms and as a % of the 10 ms budget,
      and getCPU() right after the load.

   2. Init loads (menu: "Init loads" N and the image). On the next start
      (change model and back, or restart) init() loads N copies of that
      456x342 image and keeps them all, as an app does that preloads its
      images. The window shows how many loaded and how long init took. Too
      many will exhaust memory: on the TX that stops Lua altogether.

   Everything is also written, line by line, to Apps/ImgBudget/imgbudget.out,
   so a run that is killed or stopped keeps what it measured. Each load
   writes "S" before it and "L" after it in the same callback. If the app is
   killed during a load, the file ends with an S line; if it is killed when
   the callback returns, it ends with that load's L line. At the next start
   the window shows how the previous run ended.

   Lines (comma separated):
     #,ImgBudget,version,firmware,device
     P,<text>                          how the previous run ended
     S,round,name                      a loop load starts
     L,round,name,ms,getCPU,w,h        it finished
     I,k,name,ms,ok                    init load k of N
     IT,N,loaded,total ms,getCPU       init as a whole
--]]

local appName = "ImgBudget"
local version = "1.1"
local dir = "Apps/ImgBudget/"
local outFile = "Apps/ImgBudget/imgbudget.out"
local BUDGET_MS = 10   -- the default fixed budget (Lua Console, F1)
local STEP_MS = 2000

-- PNGs smallest first, so a kill happens as late as possible, then the
-- JPEGs: Radek (JETI) suggested JPEG decodes faster than PNG. jpg/ holds a
-- DFM-Maps field image (BDS458 zoom 16, 458x343, palette PNG) and the
-- background above, each as baseline JPEG (the only kind JETI supports) at
-- quality 50, 75 and 90 (4:2:0 chroma) and 90 with 4:4:4. kb = file size
local IMAGES = {
   {name = "tiny",  file = "img/tiny.png",  kb = 0.1, what = "8x8 RGBA icon"},
   {name = "qpal",  file = "img/qpal.png",  kb = 4,   what = "quarter, palette"},
   {name = "qrgb",  file = "img/qrgb.png",  kb = 13,  what = "quarter, RGB"},
   {name = "ppal",  file = "img/ppal.png",  kb = 9,   what = "panel, palette"},
   {name = "prgba", file = "img/prgba.png", kb = 41,  what = "panel, RGBA"},
   {name = "bgpal", file = "img/bgpal.png", kb = 140, what = "background, palette"},
   {name = "bgrgb", file = "img/bgrgb.png", kb = 230, what = "background, RGB"},
   {name = "bgq50", file = "jpg/bgq50.jpg", kb = 19,  what = "background, JPEG q50"},
   {name = "bgq75", file = "jpg/bgq75.jpg", kb = 26,  what = "background, JPEG q75"},
   {name = "bgq90", file = "jpg/bgq90.jpg", kb = 41,  what = "background, JPEG q90"},
   {name = "bgq90s444", file = "jpg/bgq90s444.jpg", kb = 48, what = "bg, JPEG q90 4:4:4"},
   {name = "map",   file = "jpg/map.png",   kb = 129, what = "Maps image, palette"},
   {name = "mapq50", file = "jpg/mapq50.jpg", kb = 16, what = "Maps image, JPEG q50"},
   {name = "mapq75", file = "jpg/mapq75.jpg", kb = 26, what = "Maps image, JPEG q75"},
   {name = "mapq90", file = "jpg/mapq90.jpg", kb = 46, what = "Maps image, JPEG q90"},
   {name = "mapq90s444", file = "jpg/mapq90s444.jpg", kb = 57, what = "Maps, JPEG q90 4:4:4"},
}
local FILE = {}
for _, im in ipairs(IMAGES) do FILE[im.name] = im.file end
-- the full-size ones, for init loads
local INIT_CHOICES = {"ppal", "prgba", "bgpal", "bgrgb", "bgq75", "map", "mapq75"}

local gtc = system.getTimeCounter
local loopOn, initN, initImg
local res = {}         -- per image name: {ms, max, cpu, w, h, n}
local round, idx, nextT = 1, 0, nil
local held = {}        -- the init images, kept so they stay in memory
local initRes          -- {n, loaded, ms, cpu}
local prev             -- how the previous run ended

local function out(...)
   local t = {...}
   for i = 1, #t do t[i] = tostring(t[i]) end
   local s = table.concat(t, ",")
   print(appName .. ": " .. s)
   local fh = io.open(outFile, "a")
   if fh then
      io.write(fh, s, "\n")
      io.close(fh)
   end
end

-- the previous run's log: how did it end?
local function previousRun()
   local s = io.readall(outFile)
   if not s or s == "" then return nil end
   local last, lastL, lastI, it
   for line in s:gmatch("[^\n]+") do
      last = line
      if line:sub(1, 2) == "L," then lastL = line end
      if line:sub(1, 2) == "I," then lastI = line end
      if line:sub(1, 3) == "IT," then it = line end
   end
   local f = {}
   for x in last:gmatch("[^,]+") do f[#f + 1] = x end
   if f[1] == "S" then
      return "killed DURING loading " .. f[3]
   elseif f[1] == "L" then
      return string.format("ended after loading %s (%s ms)", f[3], f[4])
   elseif f[1] == "I" then
      return string.format("stopped in init after %s x %s loaded (last %s ms)",
			   f[2], f[3] or "?", f[4] or "?")
   elseif it and f[1] == "IT" then
      return "ended after init: " .. it
   end
   return "last line: " .. last
end

local function loop()
   if not loopOn then return end
   local now = gtc()
   if not nextT then nextT = now + 3000; return end -- let the TX settle
   if now - nextT < 0 then return end
   nextT = now + STEP_MS
   idx = idx + 1
   if idx > #IMAGES then idx = 1; round = round + 1 end
   local im = IMAGES[idx]
   out("S", round, im.name)
   local t0 = gtc()
   local img = lcd.loadImage(dir .. im.file)
   local ms = gtc() - t0
   local cpu = system.getCPU()
   out("L", round, im.name, ms, cpu, img and img.width or "nil", img and img.height or "nil")
   local r = res[im.name] or {n = 0, max = 0}
   r.ms, r.cpu, r.n = ms, cpu, r.n + 1
   if ms > r.max then r.max = ms end
   if img then r.w, r.h = img.width, img.height end
   res[im.name] = r
   img = nil
   collectgarbage()
end

local function pct(ms) return string.format("%d%%", ms * 100 // BUDGET_MS) end

local function printWin(w, h)
   local y = 4
   lcd.setColor(0, 0, 0)
   lcd.drawText(4, y, string.format("%s %s   budget %d ms   %s", appName, version, BUDGET_MS,
				    loopOn and ("loop loads, round " .. round) or "loop loads off"),
		FONT_MINI)
   y = y + 18
   if prev then
      lcd.setColor(160, 0, 0)
      lcd.drawText(4, y, "previous run: " .. prev, FONT_MINI)
      y = y + 18
   end
   lcd.setColor(0, 0, 0)
   local cols = {4, 150, 230, 290, 345, 415}
   local head = {"image", "size", "file", "ms", "budget", "getCPU"}
   for i, s in ipairs(head) do lcd.drawText(cols[i], y, s, FONT_MINI) end
   y = y + 18
   for _, im in ipairs(IMAGES) do
      local r = res[im.name]
      local row = {im.what,
		   r and r.w and (r.w .. "x" .. r.h) or "",
		   (im.kb < 1 and "<1" or tostring(im.kb)) .. " KB",
		   r and tostring(r.ms) or "-",
		   r and pct(r.ms) or "",
		   r and tostring(r.cpu) or ""}
      if r and r.ms > BUDGET_MS then lcd.setColor(200, 0, 0) else lcd.setColor(0, 0, 0) end
      for i, s in ipairs(row) do lcd.drawText(cols[i], y, s, FONT_MINI) end
      y = y + 16
   end
   y = y + 8
   lcd.setColor(0, 0, 0)
   if initRes then
      lcd.drawText(4, y, string.format("init: %d of %d x %s loaded in %d ms (getCPU %d)",
				       initRes.loaded, initRes.n, initImg, initRes.ms, initRes.cpu),
		   FONT_MINI)
   else
      lcd.drawText(4, y, "init loads: off", FONT_MINI)
   end
end

local function initForm()
   form.addRow(2)
   form.addLabel({label = "Loop loads", width = 220})
   local cb
   cb = form.addCheckbox(loopOn, function(v)
      loopOn = not v
      form.setValue(cb, loopOn)
      system.pSave("loopOn", loopOn and 1 or 0)
   end)
   form.addRow(2)
   form.addLabel({label = "Init loads (next start)", width = 220})
   form.addIntbox(initN, 0, 30, 0, 0, 1, function(v)
      initN = v
      system.pSave("initN", v)
   end)
   form.addRow(2)
   form.addLabel({label = "Init image", width = 220})
   local sel = 1
   for i, n in ipairs(INIT_CHOICES) do if n == initImg then sel = i end end
   form.addSelectbox(INIT_CHOICES, sel, false, function(v)
      initImg = INIT_CHOICES[v]
      system.pSave("initImg", v)
   end)
   form.addRow(1)
   form.addLabel({label = "Results: Apps/ImgBudget/imgbudget.out", font = FONT_MINI})
end

local function init()
   loopOn = system.pLoad("loopOn", 1) == 1
   initN = system.pLoad("initN", 0)
   initImg = INIT_CHOICES[system.pLoad("initImg", 4)] or "bgrgb"

   prev = previousRun()
   local fh = io.open(outFile, "w")
   if fh then io.close(fh) end
   out("#", appName, version, system.getVersion and system.getVersion() or "?",
       system.getDeviceType and system.getDeviceType() or "?")
   if prev then out("P", prev) end

   if initN > 0 then
      local t0 = gtc()
      local loaded = 0
      for k = 1, initN do
	 local t1 = gtc()
	 local img = lcd.loadImage(dir .. FILE[initImg])
	 out("I", k, initImg, gtc() - t1, img and 1 or 0)
	 if not img then break end
	 held[#held + 1] = img
	 loaded = loaded + 1
      end
      initRes = {n = initN, loaded = loaded, ms = gtc() - t0, cpu = system.getCPU()}
      out("IT", initN, loaded, initRes.ms, initRes.cpu)
   end

   system.registerForm(1, MENU_APPS, appName, initForm)
   system.registerTelemetry(1, appName, 5, printWin)
end

return {init = init, loop = loop, author = "DFM", version = version, name = appName}
