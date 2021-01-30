--[[

   ---------------------------------------------------------------------------------------
   DFM-TriM.lua -- GPS triangle racing maps

   Developed on DS-24, only tested on DS-24

   ---------------------------------------------------------------------------------------
   Released under MIT license by DFM 2020
   ---------------------------------------------------------------------------------------

--]]

local appInfo={}
appInfo.Name = "DFM-TriM"
appInfo.Dir  = "Apps/" .. appInfo.Name
   
local emFlag
local fieldSelectEntries={}
local imageSelectEntries={}
local img
local Field
local rwy={}
local tri={}
local nfc = {}
local nfp = {}
local lat0
local lng0
local coslat0
local rE = 6378137
local rad = 180 / math.pi
local fieldIdx = 1
local imageIdx = 1
local map={}

local first = true

local function imageScale()
   --print("imageScale: imageIdx", imageIdx)
   --print("imageScale ret:", tonumber(string.match(imageSelectEntries[imageIdx], "(%d+)")))
   return tonumber(string.match(imageSelectEntries[imageIdx], "(%d+)"))
end

local function xminImg()
   return -0.50 * imageScale()
end

local function xmaxImg()
   return 0.50 * imageScale()
end

local function yminImg()
   local yrange = imageScale() / 2
   if not Field or Field.View ~= "Center" then
      return -0.25 * yrange
   else
      return -0.50 * yrange
   end
end

local function ymaxImg()
   local yrange = imageScale() / 2 
   if not Field or Field.View ~= "Center" then
      return 0.75 * yrange
   else
      return 0.50 * yrange
   end
end

local function graphScaleRst()
   map.Xmin = xminImg()
   map.Xmax = xmaxImg()
   map.Ymin = yminImg()
   map.Ymax = ymaxImg()
   map.Xrange = map.Xmax - map.Xmin
   map.Yrange = map.Ymax - map.Ymin
end

local function selImage(i)
   --print("selImage", i)
   --print("imageSelectEntries[i]", imageSelectEntries[i])
   if not imageSelectEntries[i] then return end
   
   imageSelectEntries.selectedImage = imageSelectEntries[i]
	 graphScaleRst()
end




local function rotateXY(xx, yy, rotation)
   local sinShape, cosShape
   sinShape = math.sin(rotation)
   cosShape = math.cos(rotation)
   return (xx * cosShape - yy * sinShape), (xx * sinShape + yy * cosShape)
end

local function ll2xy(lat, lng)
   local tx, ty
   tx, ty = rotateXY(rE*(lng-lng0)*coslat0/rad,
		     rE*(lat-lat0)/rad,
		     math.rad(Field.runway.heading - 270))
   return {x=tx, y=ty}
end

local function selectCallback(idx)
   local fc, path
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   path = appInfo.Dir.."/"..fieldSelectEntries.selectedField..
      "/field.jsn"
   fc = io.readall(path)
   if not fc then print("DFM-TriM - Could not read JSON: "..path) end
   Field = json.decode(fc)
   if not Field then print("DFM-TriM - Could not decode JSON") end
   lat0 = Field.lat
   lng0 = Field.lng
   coslat0 = math.cos(math.rad(lat0))
   
   rwy = {}
   for j=1, #Field.runway.path, 1 do
      rwy[j] = ll2xy(Field.runway.path[j].lat, Field.runway.path[j].lng)
      --print("j, rwy.x, rwy.y:", j, rwy[j].x, rwy[j].y)
   end
   rwy.heading = Field.runway.heading
   --print("runway heading:", rwy.heading)
   --print("imageSelectEntries.selectedImage:", imageSelectEntries.selectedImage)


   tri = {}
   for j=1, #Field.triangle.path, 1 do
      tri[j] = ll2xy(Field.triangle.path[j].lat, Field.triangle.path[j].lng)
      --print("j, tri.x, tri.y:", j, tri[j].x, tri[j].y)
   end
   tri.center = ll2xy(Field.triangle.center.lat, Field.triangle.center.lng)
   --print("tri.center.x, tri.center.y:", tri.center.x, tri.center.y)
   --print("#Field.runway.path", #Field.triangle.path)	    
   --print("#tri", #tri)

   nfc = {}
   nfp = {}
   
   for j = 1, #Field.nofly, 1 do
      if Field.nofly[j].type == "circle" then
	 local tt = ll2xy(Field.nofly[j].lat, Field.nofly[j].lng)
	 tt.r = Field.nofly[j].diameter / 2
	 tt.inside = Field.nofly[j].inside_or_outside == "inside"
	 table.insert(nfc, tt)
	 --print("tt.x, tt.y", tt.x, tt.y)
	 --print("#nfc, x,y,r", #nfc, nfc[#nfc].x, nfc[#nfc].y, nfc[#nfc].r, nfc[#nfc].inside)
      elseif Field.nofly[j].type == "polygon" then
	 local pp = {}
	 for k =1, #Field.nofly[j].path, 1 do
	    table.insert(pp,ll2xy(Field.nofly[j].path[k].lat,Field.nofly[j].path[k].lng))
	 end
	 table.insert(nfp, {inside=(Field.nofly[j].inside_or_outside == "inside"),
			    path = pp})
      end
   end
   
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   selImage(1)

   fieldIdx = idx
   imageIdx = 1
   --keyForm(KEY_2)
end

local function keyForm(key)
   local inc, i, si, ll
   if key == KEY_2 or key == KEY_3 or key == KEY_4 then
      if key == KEY_3 or key == KEY_4 then
	 if key == KEY_3 then inc = -1 else inc = 1 end
	 imageIdx = math.max(math.min(imageIdx + inc, #imageSelectEntries), 1)
	 selImage(imageIdx)
      else
	 i = 0
	 for fname, ftype, fsize in dir(appInfo.Dir.."/"..fieldSelectEntries.selectedField) do
	    if ftype == 'file' then
	       if not string.match(fname, ".jsn") then
	       i = i + 1
	       imageSelectEntries[i] = fname
	       end
	    end
	 end
	 table.sort(imageSelectEntries,
		    function(a,b)
		       local aa, bb
		       aa=string.match(a, "(%d+)")
		       bb=string.match(b, "(%d+)")
		       return tonumber(aa) < tonumber(bb)
	 end)
	 imageIdx = 1
	 selImage(imageIdx)
	 selectCallback(imageIdx)
      end
      if imageSelectEntries.selectedImage then

	 --print("appInfo.Dir:", appInfo.Dir)
	 --print("fieldSelectEntries.selectedField:", fieldSelectEntries.selectedField)
	 --print("fieldSelectEntries.selectedImage:", fieldSelectEntries.selectedImage)
	 --print("json:", appInfo.Dir .. "/" ..fieldSelectEntries.selectedField.."/"..
		  --fieldSelectEntries.selectedField..".jsn")
	 --print("imageSelectEntries.selectedImage:", imageSelectEntries.selectedImage)
	 img = lcd.loadImage(appInfo.Dir.."/"..fieldSelectEntries.selectedField..
				"/"..imageSelectEntries.selectedImage)
	 --form.setTitle(imageSelectEntries.selectedImage)
	 form.setTitle("")
	 form.reinit(2)
      end
   end
   if key == KEY_1 or key == KEY_5 then
      form.preventDefault()
      img = nil
      form.reinit(1)
   end
end

local function initForm(subform)
   local i
   if subform == 1 then
      --form.setTitle("GPS Triangle Racing Fields")
      form.setTitle("")
      form.setButton(2, ":browser", 1)
      i=0
      for fname, ftype, fsize in dir(appInfo.Dir) do
	 if ftype == 'folder' and string.len(fname) > 2 then -- elim "." and ".."
	    i = i + 1
	    fieldSelectEntries[i] = string.format("%s", fname)
	 end
      end
      table.sort(fieldSelectEntries, function(a,b) return a>b end)
      if (not fieldSelectEntries) or (not fieldSelectEntries.selectedField) then
	 fieldSelectEntries.selectedField = fieldSelectEntries[1]
      end
      selImage(1)
      form.addRow(2)
      form.addLabel({label="Select Field"})
      form.addSelectbox(fieldSelectEntries, fieldIdx, true, selectCallback)
   elseif subform == 2 then
      --form.setTitle(imageSelectEntries.selectedImage)
      form.setTitle("")
      form.setButton(1, ":backward", 1)
      form.setButton(3, ":down" , 1)            
      form.setButton(4, ":up", 1)
   end
end

local function toXPixel(coord, min, range, width)
   local pix
   pix = (coord - min)/range * width
   return pix
end


local function toYPixel(coord, min, rr, height)
   local pix
   local range
   
   range = rr * height/160 -- correct for height not 160 as planned 
   pix = height-(coord - min)/range * height
   return pix
end

local function setColorNoFlyInside()
   lcd.setColor(255,100,100)
end

local function setColorNoFlyOutside()
   lcd.setColor(100,255,0)
end

local function setColorLabels()
   lcd.setColor(255,255,0)
end

local function setColorRunway()
   lcd.setColor(255,255,0)
end

local function setColorTriangle()
   lcd.setColor(100,255,255)
end

local function printForm(windowWidth, windowHeight)

   local ren=lcd.renderer()
   if img then
      --lcd.setColor(0,41,15)
      --lcd.drawFilledRectangle(0,0,windowWidth, windowHeight)
      lcd.drawImage(-5,15,img,255)-- -5 and 15 (175-160??) determined empirically (ugg)
      if Field then
	 --lcd.drawCircle(0,0,10)
	 setColorLabels()
	 lcd.drawText(10,15,"File: " .. imageSelectEntries.selectedImage, FONT_MINI)	 
	 lcd.drawText(10,25,Field.shortname .." - " ..Field.name, FONT_MINI)
	 lcd.drawText(10,35,"Lat: " ..  string.format("%.6f", Field.lat) .. "°", FONT_MINI)
	 lcd.drawText(10,45,"Lon: " ..  string.format("%.6f", Field.lng) .. "°", FONT_MINI)
	 lcd.drawText(10,55,"Elev: " .. (Field.elevation or "---") .." m", FONT_MINI)

	 --lcd.setClipping(0,15,310,160)

	 setColorRunway()
	 if #rwy == 4 then
	    ren:reset()
	    for j = 1, 5, 1 do
	       ren:addPoint(toXPixel(rwy[j%4+1].x, map.Xmin, map.Xrange, windowWidth),
			    toYPixel(rwy[j%4+1].y, map.Ymin, map.Yrange, windowHeight))
	    end
	    ren:renderPolyline(2,0.7)
	 end

	 if #tri == 3 then
	    ren:reset()
	    for j= 1, 4, 1 do
	       ren:addPoint(toXPixel(tri[j%3+1].x, map.Xmin, map.Xrange, windowWidth),
			    toYPixel(tri[j%3+1].y, map.Ymin, map.Yrange, windowHeight))
	    end
	    setColorTriangle()
	    ren:renderPolyline(2,0.7)
	 end


	 for i = 1, #nfp, 1 do
	    ren:reset()
	    if nfp[i].inside then
	       setColorNoFlyInside()
	    else
	       setColorNoFlyOutside()
	    end
	    for j = 1, #nfp[i].path+1, 1 do
	       ren:addPoint(toXPixel(nfp[i].path[j % (#nfp[i].path) + 1].x,
				     map.Xmin, map.Xrange, windowWidth),
			    toYPixel(nfp[i].path[j % (#nfp[i].path) + 1].y,
				     map.Ymin, map.Yrange, windowHeight))
	       
	    end
	    ren:renderPolyline(2,0.5)
	 end
	 
	 for i = 1, #nfc, 1 do
	    if i == i then
	       if nfc[i].inside then
		  setColorNoFlyInside()
	       else
		  setColorNoFlyOutside()
	       end
	       
	       lcd.drawCircle(toXPixel(nfc[i].x, map.Xmin, map.Xrange, windowWidth),
			      toYPixel(nfc[i].y, map.Ymin, map.Yrange, windowHeight),
			      nfc[i].r * windowWidth/map.Xrange)
	    end
	 end
      end
      lcd.setColor(255,255,255)
      lcd.drawFilledRectangle(0,0,windowWidth, 15)
   end

end

   
local function init()
   system.registerForm(1, MENU_APPS, "GPS Triangle Racing Maps", initForm, keyForm, printForm)

   emFlag = (select(2,system.getDeviceType()) == 1)
end

return {init=init, loop=loop, author="DFM", version="1", name=appInfo.Name}
