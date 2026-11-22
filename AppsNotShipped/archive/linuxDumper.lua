-- ############################################################################# 
-- # DC-24 Application Dumper - Lua application for JETI DC/DS transmitters 
-- # Copyright (c) 2017, JETI model s.r.o.
-- # All rights reserved.
-- #
-- # The app dumps compiled Lua chunks to files without debugging information.
-- # Useful to shrink the app, reduce memory consumption, improve start-up time 
-- # and prevent memory issues. 
-- #
-- # Load the application and then open it via User Applications form.
-- # Hit "Compile apps and dump" and confirm. All Lua files (*.lua) in the Apps
-- # folder will be converted to their binary representation (*.lc).  
-- # You can then use the binary files (*.lc) in the transmitter instead of (*.lua) 
-- # files. 
-- # NOTICE: This application should be run only via a PC Emulator to reach the 
-- # best performance.
-- #
-- #
-- # Redistribution and use in source and binary forms, with or without
-- # modification, are permitted provided that the following conditions are met:
-- # 
-- # 1. Redistributions of source code must retain the above copyright notice, this
-- #    list of conditions and the following disclaimer.
-- # 2. Redistributions in binary form must reproduce the above copyright notice,
-- #    this list of conditions and the following disclaimer in the documentation
-- #    and/or other materials provided with the distribution.
-- # 
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- # ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
-- # ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- # (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- # LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- # ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-- # 
-- # The views and conclusions contained in the software and documentation are those
-- # of the authors and should not be interpreted as representing official policies,
-- # either expressed or implied, of the FreeBSD Project.                    
-- #                       
-- # V1.0 - Initial release
-- # 12/29/20 - DFM - Modified to make list of lua files and select one for compile/dump
-- #
-- #############################################################################

 local appName="App Dumper"
 local path = "Apps"
 local luaFiles={"DFM-Crow.lua"}
 local luaFileIdx=1
 
--------------------------------------------------------------------
  
 local function readFile(path)
    print("path:", path)
    
   local f = io.open(path,"r")
   print("f:", f)
   
   return f:read("*a")

   --[[
  local lines={}
  if(f) then
    while 1 do 
      local buf=io.read(f,512)
      if(buf ~= "")then 
        lines[#lines+1] = buf
      else
        break   
      end   
    end 
    io.close(f)
    return table.concat(lines,"") 
  end
   --]]
end  

local function exportFile()
   local func
   local err
   local chunk
   local fn, fnlc
   
   --fn = path .. "/" .. luaFiles[luaFileIdx]
  fn = luaFiles[luaFileIdx]   
  fnlc = string.gsub(fn, ".lua", ".lc")

  print("fn:", fn)
  print("fnlc:", fnlc)
  
  func, err = loadfile(fn)
  print("func, err", func, err)
  
  if not func then
     print("Dumper: loadfile error - " .. err)
     return
  end
  chunk = string.dump(func,true)
  
  file = io.open(fnlc,"wb")
  print("file:", file)
  
  if(file) then
    file:write(chunk)
    file:close(file)
  end
  
  print("Exported " .. fnlc)
end
 

readFile(luaFiles[1])
exportFile()

   


   
