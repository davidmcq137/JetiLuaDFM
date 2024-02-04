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
availImgs = {}
cfgimg = {}
cfgimgESP = {}

json = require "cjson" -- same json encode/decode as Jeti uses, loaded via luarocks

fn = "./Images/availFmtMaster.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
availFmt = json.decode(file)

fn = "./Images/availImgsMaster.jsn"
fp = assert(io.open(fn, "r"))
file = assert(fp:read("a"))
print("Read "..fn)
fp:close()
availImgs = json.decode(file)

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

-- prepare cfgimg table for printTele(), save as cfgimg.jsn
-- prepare json file to send to the ESP, save as configimages.jsn
-- top key "config" is the widget positions
-- top key "images" is the widget internal details

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
      --cfgimgESP.config["p"..k]["g"..g].wtype = t.wtype

      cfgimg.config[k][g] = {}
      cfgimg.config[k][g].xul = math.floor(availVals[t.xc] - t.width/2)
      cfgimg.config[k][g].yul = math.floor(availVals[t.yc] - t.height/2)
      --cfgimg.config["p"..k]["g"..g].wtype = t.wtype
      cfgimg.config[k][g].xc = availVals[t.xc]
      cfgimg.config[k][g].yc = availVals[t.yc]
      cfgimg.config[k][g].width = t.width
      cfgimg.config[k][g].height = t.height      
      
      availFmts[k][g] =  {}
      availFmts[k][g].xc = availVals[t.xc]
      availFmts[k][g].yc = availVals[t.yc]
      availFmts[k][g].width = t.width -- availVals[t.width]
      availFmts[k][g].height = t.height --availVals[t.height]
   end
end

cfgimgESP.images = {}
cfgimg.images = {}

skip = {height=true, width=true, loadImage=true, loadImageSmaller = true,
	imageHeight=true, imageWidth=true, name=true, origHeight=true,
	origWidth=true, label=true, BMPname=true}

transX = {x0=true, xlmin=true, xlmax=true, xlbl=true}
transY = {y0=true, ylmin=true, ylmax=true, ylbl=true}   
id = 0
ii = 0
jj = 0
print("#availImgs", #availImgs)

for i,img in ipairs(availImgs) do
   ii = ii + 1
   -- id = math.floor(img.id)
   id = id + 1
   cfgimgESP.images[id] = {}
   cfgimg.images[id] = {}
   for k,v in pairs(img) do
      jj = jj + 1
      --print("k,v,skip[k]", k, v, skip[k])
      if not skip[k] then
	 if transX[k] then -- move from upper left origin to lower right origin
	    cfgimgESP.images[id][k] = img.width - v
	 elseif transY[k] then
	    cfgimgESP.images[id][k] = img.height - v
	 else
	    cfgimgESP.images[id][k] = v
	 end
      end
   end
   for k,v in pairs(img) do
      if true then --not skip[k] then
	 cfgimg.images[id][k] = v
      end
   end
end

print("ii,jj", ii,jj)
--print("3", system.getCPU())

encodedESP = json.encode(cfgimgESP)
encoded = json.encode(cfgimg)

fn = "./Images/configimages.jsn"
fp = assert(io.open(fn, "w"))
assert(fp:write(encodedESP))
print("Wrote " .. fn)
fp:close()

fn = "./Images/cfgimg.jsn"
fp = assert(io.open(fn , "w"))
assert(fp:write(encoded))
print("Wrote " .. fn)
fp:close()

os.exit(0)
