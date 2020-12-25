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

local fieldIdx = 1
local imageIdx = 1

local first = true


local function keyForm(key)
   local inc, i, si, ll
   if key == KEY_2 or key == KEY_3 or key == KEY_4 then
      if key == KEY_3 or key == KEY_4 then
	 if key == KEY_3 then inc = -1 else inc = 1 end
	 imageIdx = math.max(math.min(imageIdx + inc, #imageSelectEntries), 1)
	 imageSelectEntries.selectedImage = imageSelectEntries[imageIdx]
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
	 imageSelectEntries.selectedImage = imageSelectEntries[imageIdx]
      end
      if imageSelectEntries.selectedImage then
	 img = lcd.loadImage(appInfo.Dir.."/"..fieldSelectEntries.selectedField..
				"/"..imageSelectEntries.selectedImage)
	 form.setTitle(imageSelectEntries.selectedImage)
	 form.reinit(2)
      end
   end
   if key == KEY_1 or key == KEY_5 then
      form.preventDefault()
      img = nil
      form.reinit(1)
   end
end

local function selectCallback(idx)
   local fc, path
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   path = appInfo.Dir.."/"..fieldSelectEntries.selectedField..
      "/field.jsn"
   fc = io.readall(path)
   Field = json.decode(fc)
   fieldSelectEntries.selectedField = fieldSelectEntries[idx]
   imageSelectEntries.selectedImage = imageSelectEntries[1]
   fieldIdx = idx
   imageIdx = 1
   keyForm(KEY_2)
end

local function initForm(subform)
   local i
   if subform == 1 then
      form.setTitle("GPS Triangle Racing Fields")
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
      imageSelectEntries.selectedImage = imageSelectEntries[1]
      form.addRow(2)
      form.addLabel({label="Select Field"})
      form.addSelectbox(fieldSelectEntries, fieldIdx, true, selectCallback)
   elseif subform == 2 then
      form.setTitle(imageSelectEntries.selectedImage)
      form.setButton(1, ":backward", 1)
      form.setButton(3, ":down" , 1)            
      form.setButton(4, ":up", 1)
   end
end

local function printForm()
   if img then
      lcd.drawImage(0,0,img,255)
      lcd.setColor(255,255,0)
      if Field then
	 lcd.drawText(10,10,Field.name, FONT_MINI)
	 lcd.drawText(10,20,"Lat: " ..  Field.lat .. "°", FONT_MINI)
	 lcd.drawText(10,30,"Lon: " ..  Field.lng .. "°", FONT_MINI)
	 lcd.drawText(10,40,"Elev: " .. (Field.elevation or "---") .." m", FONT_MINI)
      end
   end
end

local function init()
   system.registerForm(1, MENU_APPS, "GPS Triangle Racing Maps", initForm, keyForm, printForm)
   emFlag = (select(2,system.getDeviceType()) == 1)
end

return {init=init, loop=loop, author="DFM", version="0.1", name=appInfo.Name}
