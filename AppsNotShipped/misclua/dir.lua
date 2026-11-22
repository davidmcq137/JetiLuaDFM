local function init()
for name, filetype, size in dir("Log") do
   print(name, filetype, size)
end

for name, filetype, size in dir("Log/20181104") do
   print(name, filetype, size)
end
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}
