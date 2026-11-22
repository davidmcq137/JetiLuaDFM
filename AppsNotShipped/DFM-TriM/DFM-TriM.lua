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
local imageSelectWidth={}
local img
local Field={}
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
local savedSubForm

local first = true

local function xminImg()
   return -0.50 * imageSelectWidth[imageIdx]
end

local function xmaxImg()
   return 0.50 * imageSelectWidth[imageIdx]
end

local function yminImg()
   return -0.50 * imageSelectWidth[imageIdx] / 2
end

local function ymaxImg()
   return 0.50 * imageSelectWidth[imageIdx] / 2 
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
		     math.rad(Field.images[1].heading))
   return {x=tx, y=ty}
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

   lat0 = Field.images[imageIdx].center.lat
   lng0 = Field.images[imageIdx].center.lng
   coslat0 = math.cos(math.rad(lat0))
   
   rwy = {}
   if Field.runway then
      for j=1, #Field.runway.path, 1 do
	 rwy[j] = ll2xy(Field.runway.path[j].lat, Field.runway.path[j].lng)
      end
   end
   
   tri = {}
   if Field.triangle then
      for j=1, #Field.triangle.path, 1 do
	 tri[j] = ll2xy(Field.triangle.path[j].lat, Field.triangle.path[j].lng)
      end
      tri.center = ll2xy(Field.triangle.center.lat, Field.triangle.center.lng)
   end
   
   nfc = {}
   nfp = {}
   
   if Field.nofly then
      for j = 1, #Field.nofly, 1 do
	 if Field.nofly[j].type == "circle" then
	    local tt = ll2xy(Field.nofly[j].lat, Field.nofly[j].lng)
	    tt.r = Field.nofly[j].diameter / 2
	    tt.inside = Field.nofly[j].inside_or_outside == "inside"
	    table.insert(nfc, tt)
	 elseif Field.nofly[j].type == "polygon" then
	    local pp = {}
	    for k =1, #Field.nofly[j].path, 1 do
	       table.insert(pp,ll2xy(Field.nofly[j].path[k].lat,Field.nofly[j].path[k].lng))
	    end
	    table.insert(nfp, {inside=(Field.nofly[j].inside_or_outside == "inside"),
			       path = pp})
	 end
      end
   end
   

   imageSelectEntries.selectedImage = imageSelectEntries[i]
   --print("selImage: imageSelectEntries.selectedImage", imageSelectEntries.selectedImage)
   
   graphScaleRst()

end


local function selectCallback(idx)
   local fc, path
   --print("selectCallback: idx, savedSubForm:", idx, savedSubForm)
   
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   path = appInfo.Dir.."/"..fieldSelectEntries.selectedField..
      "/field.jsn"
   fc = io.readall(path)
   if not fc then print("DFM-TriM - Could not read JSON: "..path) end
   Field = json.decode(fc)
   if not Field then print("DFM-TriM - Could not decode JSON") end
   lat0 = Field.images[1].center.lat
   lng0 = Field.images[2].center.lng
   coslat0 = math.cos(math.rad(lat0))
   
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   selImage(1)

   --print("fieldIdx", idx)
   
   fieldIdx = idx
   imageIdx = 1
   
   --keyForm(KEY_2)
end

   
local function keyForm(key)
   local inc, i, si, ll
   local fp
   
   --print("keyForm, savedSubForm:", key, savedSubForm)
   if key == KEY_2 or key == KEY_3 or key == KEY_4 then
      if key == KEY_3 or key == KEY_4 then
	 if key == KEY_3 then inc = -1 else inc = 1 end
	 imageIdx = math.max(math.min(imageIdx + inc, #imageSelectEntries), 1)
	 --print("@imageIdx:", imageIdx)
	 selImage(imageIdx)
      else
	 --print("%selectedField", fieldSelectEntries.selectedField)
	 i = 0
	 fp = io.readall(appInfo.Dir .. "/" .. fieldSelectEntries.selectedField .. "/field.jsn")
	 --print("fp:", fp)
	 
	 if fp then
	    Field = json.decode(fp)
	 else
	    print("DFM-TriM: did not read file", fp)
	 end
	 if Field then
	    --print("#Field.images", #Field.images)
	 else
	    print("DFM-TriM: Did not decode jsn in " .. fp)
	 end
	 table.sort(Field.images, function(a,b) return a.meters_per_pixel > b.meters_per_pixel end)
	 
	 for k,v in ipairs(Field.images) do
	    imageSelectEntries[k] = Field.images[k].file
	    imageSelectWidth[k] = v.meters_per_pixel * 320 * math.cos(math.rad(Field.images[k].center.lat))	 
	    --print("k,iSE,iSW", k, imageSelectEntries[k], imageSelectWidth[k])
	 end
	 
	 imageIdx = 1
	 selImage(imageIdx)
	 
      end

      
      --print("imageSelectEntries.selectedImage:", imageSelectEntries.selectedImage)
      
      if imageSelectEntries.selectedImage then
	 img = lcd.loadImage(imageSelectEntries.selectedImage)
	 --form.setTitle(imageSelectEntries.selectedImage)
	 form.setTitle("")
	 form.reinit(2)
      end
   end
   if key == KEY_1 or key == KEY_5 then
      form.preventDefault()
      --print("Key1 .. image", img)
      img = nil
      form.reinit(1)
   end
end

local function initForm(subform)
   savedSubForm = subform
   --print("savedSubForm", savedSubForm)
   
   local i
   if subform == 1 then
      --form.setTitle("GPS Triangle Racing Fields")
      form.setTitle("")
      form.setButton(2, "View", 1)
      i=0
      --print("dir of:", appInfo.Dir)
      for fname, ftype, fsize in dir(appInfo.Dir) do
	 if ftype == 'folder' and string.len(fname) > 2 then -- elim "." and ".."
	    i = i + 1
	    --print("i, fname", i, fname)
	    fieldSelectEntries[i] = fname --string.format("%s", fname)
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
	 lcd.drawText(10,35,"Scale: " .. (imageSelectWidth[imageIdx] or "---") .." m/pix", FONT_MINI)
	 lcd.drawText(10,45,"Lat: " ..  string.format("%.6f", lat0) .. "°", FONT_MINI)
	 lcd.drawText(10,55,"Lon: " ..  string.format("%.6f", lng0) .. "°", FONT_MINI)
	 lcd.drawText(10,65,"Elev: " .. (Field.elevation or "---") .." m", FONT_MINI)

	 --lcd.setClipping(0,15,310,160)

	 setColorRunway()
	 if #rwy == 4 then
	    ren:reset()
	    for j = 1, 5, 1 do
	       if j == 1 then
		  --print(toXPixel(rwy[j%4+1].x, map.Xmin, map.Xrange, windowWidth),
		  --	    toYPixel(rwy[j%4+1].y, map.Ymin, map.Yrange, windowHeight))	       
	       end
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

   initForm(1)
   selectCallback(1)
   
   system.registerForm(1, MENU_APPS, "GPS Triangle Racing Maps", initForm, keyForm, printForm)

   emFlag = (select(2,system.getDeviceType()) == 1)
end

return {init=init, loop=loop, author="DFM", version="1", name=appInfo.Name}
