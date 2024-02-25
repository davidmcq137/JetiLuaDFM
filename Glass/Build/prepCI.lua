gw = 304
gh = 256
large = 160
ofs=5

availVals = {L1 = gw/2,
	     L2 = gw/2 - large/2 - ofs, R2 = gw/2 + ofs + -large/4 + large/2,
	     L3 = gw/2 - ofs - large/4, R3 = gw/2 + ofs + large/2,
	     L4 = gw/2 - ofs - large/2, C4 = gw/2, R4 = gw/2 + ofs + large/2,
	     H1 = gh/2, H2 = gh/2 - ofs * 6, H3 = gh/2 + large/2 + ofs * 2,
	     GWID = gw, GHGT = gh
	     
}

availFmt = {}
availFormsInstr = {}
cfgimg = {}
cfgimgESP = {}

json = require "cjson" -- same json encode/decode as Jeti uses, loaded via luarocks

fn = "./Images/availFmtMaster.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
availFmt = json.decode(file)

fn = "./Images/availInstrumentsMaster.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
availFormsInstr = json.decode(file)

-- fill in availFmts table with actual pixel value

availFmts = {}
for k,gp in ipairs(availFmt) do
   availFmts[k] = {}
   for g,t in ipairs(gp) do
      availFmts[k][g] =  {}
      availFmts[k][g].xc = availVals[t.xc]
      availFmts[k][g].yc = availVals[t.yc]
      availFmts[k][g].width = t.width -- availVals[t.width]
      availFmts[k][g].height = t.height -- availVals[t.height]
   end
end

-- prepare cfgimg table for printTele(), save as instr.jsn
-- prepare json file to send to the ESP, save as instruments.jsn
-- top key "config" is the widget positions
-- top key "forms" is the forms (basic instrument image) info
-- top key "instrument" is the widget (instrument) internal details

cfgimgESP = {}
cfgimgESP.config = {}
cfgimg.config = {}
for k,gp in ipairs(availFmt) do
   cfgimgESP.config[k] = {}
   cfgimg.config[k] = {}
   availFmts[k] = {}
   for g,t in ipairs(gp) do
      cfgimgESP.config[k][g] = {}
      cfgimgESP.config[k][g].xlr = math.floor(gw - (availVals[t.xc] + t.width/2))
      cfgimgESP.config[k][g].ylr = math.floor(gh - (availVals[t.yc] + t.height/2))

      cfgimg.config[k][g] = {}
      cfgimg.config[k][g].xul = math.floor(availVals[t.xc] - t.width/2)
      cfgimg.config[k][g].yul = math.floor(availVals[t.yc] - t.height/2)
      cfgimg.config[k][g].xc = availVals[t.xc]
      cfgimg.config[k][g].yc = availVals[t.yc]
      cfgimg.config[k][g].width = t.width
      cfgimg.config[k][g].height = t.height      
      
      availFmts[k][g] =  {}
      availFmts[k][g].xc = availVals[t.xc]
      availFmts[k][g].yc = availVals[t.yc]
      availFmts[k][g].width = t.width
      availFmts[k][g].height = t.height
   end
end

cfgimgESP.forms = {}
cfgimgESP.instruments = {}

cfgimg.forms = {}
cfgimg.instruments = {}

-- skip the keys that we don't need in the app or on the ESP, the ones that are only used
-- during the build process
--
-- leave the xlmin, xlmax, ylmin, ylmax values in the json file for now in case we
-- resurrect the idea of variable gauges .. but skip them so they are not copied to
-- the operational json files

skip = {height=true, width=true, name=true, label=true, descr=true, xlmin=true,
	xlmax=true, ylmin=true, ylmax=true, major=true, minor=true, fine=true,
	ticlabels=true}

-- identify which values have to be translated from the conventional upper left origin
-- to the lower right origin of the glasses

transX = {x0=true, xlmin=true, xlmax=true, xlbl=true}
transY = {y0=true, ylmin=true, ylmax=true, ylbl=true}   

-- first prepare the forms table

id = 0
jj = 0
ii = 0
for i, img in ipairs(availFormsInstr.forms) do
   ii = ii + 1
   -- id = math.floor(img.id)
   id = id + 1
   cfgimgESP.forms[id] = {}
   cfgimg.forms[id] = {}
   for k,v in pairs(img) do
      jj = jj + 1
      --print("k,v,skip[k]", k, v, skip[k])
      if not skip[k] then
	 if transX[k] then -- move from upper left origin to lower right origin
	    cfgimgESP.forms[id][k] = img.width - v
	 elseif transY[k] then
	    cfgimgESP.forms[id][k] = img.height - v
	 else
	    cfgimgESP.forms[id][k] = v
	 end
      end
   end
   ---[[
   for k,v in pairs(img) do
      if not skip[k] then
	 cfgimg.forms[id][k] = v
      end
   end
   --]]
end

-- then the instruments table

id = 0
jj = 0
ii = 0
for i,img in ipairs(availFormsInstr.instruments) do
   ii = ii + 1
   id = id + 1
   cfgimgESP.instruments[id] = {}
   cfgimg.instruments[id] = {}
   jj = 0
   for k,v in pairs(img) do
      jj = jj + 1
      --print("k,v,skip[k]", k, v, skip[k])
      if not skip[k] then
	 if transX[k] then -- move from upper left origin to lower right origin
	    cfgimgESP.instruments[id][k] = img.width - v
	 elseif transY[k] then
	    cfgimgESP.instruments[id][k] = img.height - v
	 else
	    cfgimgESP.instruments[id][k] = v
	 end
      end
      cft = cfgimgESP.instruments[id].type
      if cft == "gauge" or cft == "compass" or cft == "hbar" then
	 cfgimgESP.instruments[id].imageID = id
      else
	 cfgimgESP.instruments[id].imageID = 0
      end
	 
   end
   for k,v in pairs(img) do
      if not skip[k] then
	 cfgimg.instruments[id][k] = v
      end
      cft = cfgimgESP.instruments[id].type
      if cft == "gauge" or cft == "compass" or cft == "hbar" then
	 cfgimg.instruments[id].imageID = id
      else
	 cfgimg.instruments[id].imageID = 0	 
      end
   end
end

encodedESP = json.encode(cfgimgESP)
encoded = json.encode(cfgimg)

fn = "./Images/instruments.jsn"
fp = assert(io.open(fn, "w"))
assert(fp:write(encodedESP))
print("Wrote " .. fn)
fp:close()

fn = "./Images/instr.jsn"
fp = assert(io.open(fn , "w"))
assert(fp:write(encoded))
print("Wrote " .. fn)
fp:close()

os.exit(0)
