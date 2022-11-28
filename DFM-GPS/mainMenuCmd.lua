local M = {}
function M.mainMenu(savedRow, monoTx)
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

   if not monoTx then
      form.addRow(2)
      form.addLabel({label="Settings >>", width=220})
      form.addLink((function()
	       savedRow = form.getFocusedRow()
	       form.reinit(4)
	       form.waitForRelease()
      end))
   end
   
   form.addRow(2)
   form.addLabel({label="Reset App data >>", width=220})
   form.addLink((function()
	    savedRow = form.getFocusedRow()
	    print("foo")
	    form.reinit(6)
	    form.waitForRelease()
   end))      

   if savedRow then form.setFocusedRow(savedRow) end
   savedRow = 1
   return savedRow
end

return M

