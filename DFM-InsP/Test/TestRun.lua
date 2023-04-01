--[[

   DFM-InsP-TestRun.lua

   lua script to exercise the DFM-InsP.lua app
   requires DFM-InsP-TestPre.lua to be concatenated with DFM-InsP.lua
   creating the file DFM-InsP-TestCat.lua .. 
   then run the actual test with shell script DFM-InsP-Test.sh

   The shell script makes sure there is no saved model file, then reads in all the panels
   in the DFM-InsP/Panels directory, then "runs" all the panels by calling the 
   loop() and printForm() functions 10000 times for each panel

   03/31/23 New file

--]]

-----------------------------------------------


--[[

   Prefix header file for testing DFM-InsP.lua

   03/31/23 New File

--]]

system={}
json={}
lcd={}
form={}

counters={}

function form.reinit()
end

function system.messageBox(txt)
   print("MessageBox: " .. txt)
end


function system.getProperty()
   --print("system.getProperty returning model name Aaa")
   return "Testfile"
end

function system.getDeviceType()
   --print("system.getDeviceType returning _,1")
   return "",1
end

function io.readall(file)
   local f = io.open(file, "r")
   if not f then return nil end
   local content = f:read("*all")
   return content
end

function json.decode(text)
   return cjson.decode(text)
end

function json.encode(jsn)
   return cjson.encode(jsn)
end


require "lfs"

local function diriterator(func, state)
   return function()
      return func(state)
   end
end

function dir(d)
   return dirtree(d)
end

function dirtree(dir)
   -- code by AlexanderMarinov
   -- Compatible with Lua 5.1 (not 5.0).
   assert(dir and dir ~= "", "directory parameter is missing or empty")
   if string.sub(dir, -1) == "/" then
      dir=string.sub(dir, 1, -2)
   end

   --local diriters = {lfs.dir(dir)}
   local diriters = {diriterator(lfs.dir(dir))}
   local dirs = {dir}
				  
   return function()
      repeat
	 local entry = diriters[#diriters]()
	 if entry then 
	    if entry ~= "." and entry ~= ".." then 
	       local filename = table.concat(dirs, "/").."/"..entry
	       local attr = lfs.attributes(filename)
	       if attr.mode == "directory" then 
		  table.insert(dirs, entry)
		  --table.insert(diriters, lfs.dir(filename))
		  table.insert(diriters, diriterator(lfs.dir(filename)))
	       end
	       return filename, attr
	    end
	 else
	    table.remove(dirs)
	    table.remove(diriters)
	 end
      until #diriters==0
   end
end

function system.getSensors()
   --print("system.getSensors() returning {}")
   return {}
end

function system.getInputsVal()
   --print("getInputsVal", x, type(x))
   return 0.0
end

function system.getSensorByID()
   return {type=2, value=0.0, min=0.0, max=1.0, valid=true, unit=""}
end

function system.getTxTelemetry()
   return {0,0,0,0,0,0,0,0,0,0,0,{0,0,0,0,0,0}}
end

function system.getCPU()
   --print("getCPU")
   return 0
end

function lcd.loadImage()
   return {width=318, height=159, data={}}
end

counters.drawImage = 0
function lcd.drawImage()
   counters.drawImage = counters.drawImage + 1
end

function lcd.setColor()
end

counters.drawTextCenter = 0
function lcd.drawTextCenter()
   counters.drawTextCenter = counters.drawTextCenter + 1
end

counters.getTextWidth = 0
function lcd.getTextWidth()
   counters.getTextWidth = counters.getTextWidth + 1
   return 0
end

counters.getTextHeight = 0
function lcd.getTextHeight()
   counters.getTextHeight = counters.getTextHeight + 1
   return 0
end

counters.drawText = 0
function lcd.drawText()
   counters.drawText = counters.drawText + 1
end

counters.drawRectangle = 0
function lcd.drawRectangle()
   counters.drawRectangle = counters.drawRectangle + 1
end

counters.drawFilledRectangle = 0
function lcd.drawFilledRectangle()
   counters.drawFilledRectangle = counters.drawFilledRectangle + 1
end

function lcd.drawLine()
end

function lcd.renderer()
   obj = {}
   function obj:reset()
      return
   end
   function obj:addPoint()
      return
   end
   function obj:renderPolygon()
      return
   end
   function obj:renderPolyline()
      return
   end
   function obj:setClipping()
      return
   end
   function obj:resetClipping()
      return
   end

   return obj
end

function lcd.setClipping()
end

function lcd.resetClipping()
end

--system.registerForm(1, MENU_APPS, "Instrument Panel", initForm, keyForm, prtForm)

local initF, keyF, printF

function system.registerForm(a,b,c,iF,kF,pF)
   print("Register form #"..a.." Name: "..c)
   initF = iF
   keyF = kF
   printF = pf
end

--system.registerTelemetry(1, "DFM-InsP-1", 4, (function(w,h) return printForm(w,h,1) end) )
--system.registerTelemetry(2, "DFM-InsP-2", 4, (function(w,h) return printForm(w,h,2) end) )   

function system.registerTelemetry(n, b, c, tf)
   print("Register Telemetry Window #" .. n .." " .. b)
   if n == 1 then tf1 = tf elseif n == 2 then tf2 = tf end
end

local tc = 0
function system.getTimeCounter()
   --print("getTimeCounter returning 0")
   tc = tc + 30
   return tc
end


-----------------------------------------------

L = require("DFM-InsP")

print("Read module DFM-InsP")
print("App name " .. L.name)
print("App Version " .. L.version)
print("App Author " .. L.author)

print("Running app init()")
L.init(-1)
InsP = L.extaddr.addret()

print("Panels read in at init()")
for i,p in ipairs(InsP.panelImages) do
   print(i, p.timestamp, p.instImage, p.backImage)
end

print("Exercising all panels")
for i,p in ipairs(InsP.panelImages) do
   InsP.settings.window1Panel = i
   InsP.settings.window2Panel = i
   for k=1,1000,1 do
      L.loop()
      tf1(318,158,1)
      tf2(318,158,2)
   end
end

print("Panels available in DFM-InsP/Panels:")
for i,p in ipairs(InsP.settings.panels) do
   print(i,p)
end

print("Reading all panels in DFM-InsP/Panels")
for i,p in ipairs(InsP.settings.panels) do
   if i+1 > #InsP.settings.panels then break end
   if i ~= 1 then L.extaddr.newpanel() end
   L.extaddr.panelChanged(i+1,i)
end

print("Panels read in:")
for i,p in ipairs(InsP.panelImages) do
   print(i, p.timestamp, p.instImage, p.backImage)
end

print("Exercising all panels")
for i,p in ipairs(InsP.panelImages) do
   InsP.settings.window1Panel = i
   InsP.settings.window2Panel = i
   for k=1,1000,1 do
      L.loop()
      tf1(318,158,1)
      tf2(318,158,2)
   end
end

print("Counters:")
for k,v in pairs(counters) do
   print(k,v)
end

print("calling destroy")

L.destroy(-1)
