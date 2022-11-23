local M = {}
function M.mainMenu(savedRow)
   form.setTitle("GPS Display")
   
   form.setButton(1, "Pt A",  ENABLED)
   form.setButton(2, "Dir B", ENABLED)
   
   form.addRow(2)
   form.addLabel({label="Telemetry >>", width=220})
   form.addLink((function()
	    savedRow = form.getFocusedRow()
	    form.reinit(3)
	    form.waitForRelease()
   end))      
   
   form.addRow(2)
   form.addLabel({label="Fields >>", width=220})
   form.addLink((function()
	    savedRow = form.getFocusedRow()
	    form.reinit(4)
	    form.waitForRelease()
   end))
   
   form.addRow(2)
   form.addLabel({label="No Fly Zones >>", width=220})
   form.addLink((function()
	    savedRow = form.getFocusedRow()
	    form.reinit(5)
	    form.waitForRelease()
   end))
   
   if savedRow then form.setFocusedRow(savedRow) end
   savedRow = 1
   return savedRow
end

return M

