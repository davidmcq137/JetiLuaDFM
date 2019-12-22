
-- ############################################################################# 
-- # Jeti helper library
-- #
-- # Copyright (c) 2017, Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V0.5 - Initial release
-- ############################################################################# 

local tablehelper = {}

--------------------------------------------------------------------
-- Read all folders and put it in a table to be used to create a menu
function tablehelper.fromDirectory(path, choice)
    local tmpTable = {"..."}
    local tmpIndex = 1

    for name, filetype, size in dir(path) do
        if(filetype == "folder" and string.sub(name, 1, 1) ~= ".") then
            table.insert(tmpTable, name)

            if(name == choice) then
                tmpIndex=#tmpTable
            end
        end
    end
    collectgarbage()
    print(string.format("fromDirectory: %s - mem: %s", path, collectgarbage("count")))

    return tmpTable, tmpIndex
end

--------------------------------------------------------------------
-- Read all files in a folder and put it in a table to be used to create a menu
function tablehelper.fromFiles(path, choice)
    local tmpTable = {"..."}
    local tmpIndex = 1

    collectgarbage()
    print(string.format("fromFiles: %s - mem: %s", path, collectgarbage("count")))

    for name, filetype, size in dir(path) do
        if(string.sub(name, -3, -1) == "jsn" and string.sub(name, 1, 1) ~= ".") then
            table.insert(tmpTable, string.sub(name, 1, -5))
            
            if (choice) then
                if(string.sub(name, 1, -5) == choice) then
                    tmpIndex=#tmpTable
                end
            end
        end
    end

    return tmpTable, tmpIndex
end

return tablehelper