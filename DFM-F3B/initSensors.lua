local M = {}

local function telemChanged(val, stbl, v, tbl)
   --print("telemChanged", val, tbl.Idlist[val], tbl.Palist[val])
   stbl[v].Se = val
   stbl[v].SeId = tbl.Idlist[val]
   stbl[v].SePa = tbl.Palist[val]
   system.pSave(v.."Se",   stbl[v].Se)
   system.pSave(v.."SeId", stbl[v].SeId)
   system.pSave(v.."SePa", stbl[v].SePa)
end

local function initForm(sf, sens, tbl)
   for i in ipairs(sens) do
      form.addRow(2)
      form.addLabel({label=sens[i].label,width=140})
      form.addSelectbox(tbl.Lalist, sens[sens[i].var].Se or 0, true,
			(function(x) return telemChanged(x, sens, sens[i].var, tbl) end),
			{width=180, alignRight=false})
   end
end

local function keyForm(key)

   form.preventDefault()
   if key == KEY_5 then
      form.close(2)
   end
end

function M.initSensors(sens, tbl)
   --print("M.initSensors")
   system.registerForm(2, 0, "Sensor Selection", (function(x) return initForm(x,sens,tbl) end), keyForm)
end


return M

