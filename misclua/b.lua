local hp1345a = {
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

local function loop()
   
end

local function drawHP1345A(x, y, str, scale, rot)
   local xc = x
   local yc = y
   local xr, yr
   local ren = lcd.renderer()
   local shape
   local b0 = string.byte("0")
   local cc
   local np
   for char in str:gmatch(".") do
      if char == "." then cc = "/" else cc = char end
      np = string.byte(cc) - b0 + 2
      shape = hp1345a[np]
      if shape then 
	 ren:reset()
	 for i,v in ipairs(shape) do
	    if v[1] == -1 then
	       ren:renderPolyline(2)
	       ren:reset()
	    else
	       xr = xc + scale*v[1]*math.cos(-rot) - scale*v[2]*math.sin(-rot)
	       yr = yc + scale*v[1]*math.sin(-rot) + scale*v[2]*math.cos(-rot)
	       ren:addPoint(xr, yr)
	    end
	 end
	 ren:renderPolyline(2)      
	 xc = xc + scale * 18 * math.cos(-rot)
	 yc = yc + scale * 18 * math.sin(-rot)
      end
   end
end

local function printForm()

   local scale = system.getInputs("P4") + 1
   local rot = 180 * (system.getInputs("P1") + 1)
   drawHP1345A(120,80, "1234567890", scale, math.rad(rot))
   lcd.drawText(10,140, system.getCPU())
   
end

local function init()

   system.registerTelemetry(1, "Tele 1", 5, printForm)
   
end

return {init=init, loop=loop, author="DFM", version="1", name="b.lua"}
