--[[

   The HP1345A characters are from http://phk.freebsd.dk/hacks/Wargames/
   This is the license grant in his python code (which I did not use):

   "THE BEER-WARE LICENSE" (Revision 42):

   <phk@FreeBSD.org> wrote this file.  As long as you retain this notice you
   can do whatever you want with this stuff. If we meet some day, and you think
   this stuff is worth it, you can buy me a beer in return.   Poul-Henning Kamp

   08-Feb-2023 D. McQueeney MIT license for the lua code 

--]]

local M = {}

local hp1345a = {
   { --minus sign
      {0,8},
      {12,8}
   },
   { --dec pt
      {6,18},
      {8,18},
      {8,16},
      {6,16},
      {6,18}
   },
   { --0
      {3,18},
      {9,18},
      {12,12},
      {12,6},
      {9,0},
      {3,0},
      {0,6},
      {0,12},
      {3,18},
      {-1,-1},
      {1,16},
      {11,2}
   },
   { --1
      {3,18},
      {9,18},
      {-1,-1},
      {6,18},
      {6,0},
      {3,3}
   },
   { --2
      {12,18},
      {0,18},
      {2,13},
      {12,7},
      {12,3},
      {9,0},
      {3,0},
      {0,3}
   },
   { --3
      {0,16},
      {3,18},
      {9,18},
      {12,15},
      {12,11},
      {9,9},
      {3,9},
      {9,9},
      {12,7},
      {12,3},
      {9,0},
      {3,0},
      {0,2}
   },
   { --4
      {12,12},
      {0,12},
      {9,0},
      {9,18}
   },
   { --5
      {0,16},
      {3,18},
      {9,18},
      {12,16},
      {12,10},
      {9,8},
      {3,8},
      {0,9},
      {2,0},
      {12,0}
   },
   { --6
      {0,11},
      {3,8},
      {9,8},
      {12,11},
      {12,15},
      {9,18},
      {3,18},
      {0,15},
      {0,8},
      {3,3},
      {7,0}
   },
   { --7
      {4,18},
      {12,0},
      {0,0}
   },
   { --8
      {3,18},
      {9,18},
      {12,15},
      {12,11},
      {9,8},
      {3,8},
      {0,5},
      {0,2},
      {3,-1},
      {9,-1},
      {12,2},
      {12,5},
      {9,8},
      {3,8},
      {0,11},
      {0,15},
      {3,18}
   },
   { --9
      {5,18},
      {9,15},
      {12,10},
      {12,3},
      {9,0},
      {3,0},
      {0,3},
      {0,7},
      {3,10},
      {9,10},
      {12,7}
   }
}

local savrot
local cosrot
local sinrot

function M.drawHP1345A(x, y, str, scale, rot, wid)

   -- function requires a string to be passed ... formatting to be done
   -- by caller. Ignores non number or . characters
   --
   -- x,y:   start location in pixels (upper left or first char)
   -- str:   string to draw
   -- scale: size multiplier .. 1 is nominal
   -- rot:   rotation angle (radians)
   -- wid:   width of polyline (pixels)

   local ren = lcd.renderer()
   local xc, yc = x, y
   local xr, yr
   local shape
   local b0 = 48 -- string.byte("0")
   local np
   
   if rot ~= savrot then
      cosrot = math.cos(-rot)
      sinrot = math.sin(-rot)
      savrot = rot
   end
   
   for char in string.gmatch(str, ".") do
      if char == "-" then
	 np = 1
      elseif char == "." then
	 np = 2
      else
	 np = string.byte(char) - b0 + 3
      end
      shape = hp1345a[np]
      if shape then 
	 ren:reset()
	 for i,v in ipairs(shape) do
	    if v[1] == -1 then -- pick up pen
	       ren:renderPolyline(wid)
	       ren:reset()
	    else
	       xr = xc + scale*v[1]*cosrot - scale*v[2]*sinrot
	       yr = yc + scale*v[1]*sinrot + scale*v[2]*cosrot
	       ren:addPoint(xr, yr)
	    end
	 end
	 ren:renderPolyline(wid)      
	 xc = xc + scale * 18 * cosrot
	 yc = yc + scale * 18 * sinrot
      end
   end
end

return M
