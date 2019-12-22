-- ############################################################################# 
-- # DC-24 Demos 
-- #
-- # Copyright (c) 2016, JETI model s.r.o.
-- # All rights reserved.
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
-- #############################################################################

local appName="Vario test" 

local printed = false  
   
-- function to show all global variables .. uncomment for debug .. called from reset origin menu

local seen={}

local function dump(t,i)
	seen[t]=true
	local s={}
	local n=0
	for k in pairs(t) do
		n=n+1 s[n]=k
	end
	table.sort(s)
	for k,v in ipairs(s) do
		print(i,v)
		v=t[v]
		if type(v)=="table" and not seen[v] then
			dump(v,i.."\t")
		end
	end
end

--dumps a table in human-readable format (sort of)
--kills the script sometimes for a really big table!

local function dumpt(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then
	    k = '"'..k..'"'
	 end
	 s = s .. '['..k..'] = ' .. dumpt(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
 

--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function initForm(formId) 
  
      
end

--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function printForm(formId)
   
end
 
local function loop()
   
   -- Use short tone or longer tone for climbing indication
  local useShortTone = false
  -- Disable vario output so that there is no sound
  local disableVarioOutput = false
  system.setVario(system.getInputs("P1"), useShortTone, disableVarioOutput)

  if not printed then
     dump(_G, "")
     printed = true
  end
  
end 



--------------------------------------------------------------------
-- Init function
--------------------------------------------------------------------
local function init()

   
end 
return { init=init, loop=loop, author="JETI model", version="1.00",name=appName}
