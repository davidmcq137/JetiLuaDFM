local function init()
   if not (select(2, system.getDeviceType()) == 0) then print("Emulator - not deleting DFM-Maps.lua") else
      local fr = io.open("./Apps/DFM-Maps.lua")
      if fr then
	 io.remove("./Apps/DFM-Maps.lua")
	 system.messageBox("Remove Old DFM-Maps (x) and reload (+)", 10)
	 io.close(fr)
      end
   end
end

return {init=init, version="7.24", name="Old DFM-Maps"}
