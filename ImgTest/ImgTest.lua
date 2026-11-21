--[[
   ImgTest: measure what lcd.loadImage and lcd.drawImage cost on a TX

   Loads a fixed set of PNGs from Apps/ImgTest/, one per loop() call, 1.5 s
   apart, smallest first, three rounds, after one "batch" call that loads
   three small images in the same callback. Each load logs its wall time
   (system.getTimeCounter, 1 ms steps) and system.getCPU() right after it.
   If the ImgTest telemetry window is on screen, every frame draws the most
   recently loaded image and its drawImage time is logged per image too.

   Results go to Apps/ImgTest/imgtest.out, one line at a time, so a run the
   TX kills keeps everything up to the kill (the next file in the list is
   the one that killed it).

   Lines (comma separated):
     #,ImgTest,version,firmware,device
     L,tag,name,ms,getCPU,width,height     (tag: batch, r1, r2, r3)
     B,count,total ms,getCPU               (the batch callback as a whole)
     G,ms                                  (collectgarbage between loads)
     D,name,frames,avg ms,max ms,getCPU max (drawImage of that image)
     DONE

   Images: tiny 8x8 RGBA; qpal/qrgb a TurbineL panel quarter (228x171) as
   256-colour and RGBA; ppal/prgba the whole TurbineL panel (456x342);
   bgpal/bgrgb a full-size carbon-fibre background (456x342) as 256-colour
   and RGB.
--]]

local appName = "ImgTest"
local version = "1.0"
local dir = "Apps/ImgTest/"
local outFile = dir .. "imgtest.out"

-- smallest file first, so a kill happens as late as possible
local names = {"tiny", "qpal", "qrgb", "ppal", "prgba", "bgpal", "bgrgb"}
local batchNames = {"tiny", "qpal", "qrgb"}

local gtc = system.getTimeCounter
local steps, stepI, nextT = {}, 0, 0
local shown, shownName
local draw = {}
local done = false

local function out(...)
   local t = {...}
   for i = 1, #t do t[i] = tostring(t[i]) end
   local s = table.concat(t, ",")
   print(s)
   local fh = io.open(outFile, "a")
   if fh then
      io.write(fh, s, "\n")
      io.close(fh)
   end
end

-- one timed load; the caller logs it, so file writes don't land in the timing
local function load(name)
   local t0 = gtc()
   local img = lcd.loadImage(dir .. name .. ".png")
   local ms = gtc() - t0
   return img, ms, system.getCPU()
end

local function logLoad(tag, name, img, ms, cpu)
   out("L", tag, name, ms, cpu, img and img.width or "nil", img and img.height or "nil")
end

local function loop()
   if done then return end
   local now = gtc()
   if now < nextT then return end
   stepI = stepI + 1
   local s = steps[stepI]

   if not s then
      for _, n in ipairs(names) do
	 local d = draw[n]
	 if d then out("D", n, d.n, string.format("%.1f", d.sum / d.n), d.max, d.cpu) end
      end
      out("DONE")
      print(appName .. ": done, results in " .. outFile)
      done = true
      return
   end

   if s.kind == "load" then
      local img, ms, cpu = load(s.name)
      logLoad(s.tag, s.name, img, ms, cpu)
      if img then shown, shownName = img, s.name end
      nextT = now + 1500
   elseif s.kind == "batch" then
      local res = {}
      local t0 = gtc()
      for i, n in ipairs(batchNames) do
	 local img, ms, cpu = load(n)
	 res[i] = {n, img, ms, cpu}
      end
      local total, cpu = gtc() - t0, system.getCPU()
      for _, r in ipairs(res) do logLoad("batch", r[1], r[2], r[3], r[4]) end
      out("B", #batchNames, total, cpu)
      nextT = now + 1500
   elseif s.kind == "gc" then
      local t0 = gtc()
      collectgarbage()
      out("G", gtc() - t0)
      nextT = now + 500
   end
end

local function printWin(w, h)
   if shown then
      local t0 = gtc()
      lcd.drawImage(0, 0, shown)
      local dt = gtc() - t0
      local c = system.getCPU()
      local d = draw[shownName]
      if not d then
	 d = {n = 0, sum = 0, max = 0, cpu = 0}
	 draw[shownName] = d
      end
      d.n = d.n + 1
      d.sum = d.sum + dt
      if dt > d.max then d.max = dt end
      if c > d.cpu then d.cpu = c end
   end
   lcd.drawText(4, 4, done and "ImgTest done" or
		   string.format("ImgTest %d/%d", stepI, #steps), FONT_BOLD)
end

local function init()
   local fh = io.open(outFile, "w")
   if fh then io.close(fh) end
   out("#", appName, version, system.getVersion and system.getVersion() or "?",
       system.getDeviceType and system.getDeviceType() or "?")

   steps[#steps + 1] = {kind = "batch"}
   steps[#steps + 1] = {kind = "gc"}
   for r = 1, 3 do
      for _, n in ipairs(names) do
	 steps[#steps + 1] = {kind = "load", tag = "r" .. r, name = n}
	 steps[#steps + 1] = {kind = "gc"}
      end
   end
   nextT = gtc() + 3000   -- let the TX settle after start-up
   system.registerTelemetry(1, appName, 4, printWin)
end

return {init = init, loop = loop, author = "DFM", version = version, name = appName}
