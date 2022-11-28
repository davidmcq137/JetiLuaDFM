local M = {}

function M.settings(savedRow)
   form.setTitle("Settings")
   form.addRow(1)
   form.addLabel({label="this is line one", width=220})
   savedRow = 1
   return savedRow
end

return M

