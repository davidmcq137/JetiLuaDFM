PrettyPrint = require 'PrettyPrint'


local last = 0
local step
local deltaT
local running

local CTRL_name = {
   "L_Ail", "R_Ail", "L_Flap", "R_Flap", "L_Rud", "R_Rud", "L_Ele", "R_Ele"
}

local CTRL_shortName = {
   "L_A", "R_A", "L_F", "R_F", "L_R", "R_R", "L_E", "R_E"
}



local CTRL_steps = {
   {dt=4000,L_Ail=0 ,R_Ail=0, L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   
   {dt=500, L_Ail=1 ,R_Ail=1,  L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=1000,L_Ail=-1,R_Ail=-1, L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=1 ,R_Ail=-1, L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=1000,L_Ail=-1,R_Ail=1 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=0, R_Flap=0, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=-1,R_Flap=-1,L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=1, R_Rud=1, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=-1,R_Rud=-1,L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   
   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=-1,R_Rud=1, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=1, R_Rud=-1,L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=1, R_Ele= 1},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=-1,R_Ele=-1},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   
   {dt=1000,L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=1, R_Ele=-1},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=-1,R_Ele= 1},
   {dt=500, L_Ail=0 ,R_Ail=0 , L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},   
}

local function loop()
   local now

   --print(system.getInputs("SA"))
   
   if not running then
      if system.getInputs("SA") == 1 then
	 running = true
	 last = system.getTimeCounter()
      else
	 return
      end
   end
   
   now = system.getTimeCounter()

   if now > last + deltaT then
      step = step + 1
      deltaT = CTRL_steps[step].dt
      print("step, deltaT:", step, deltaT)
      for ctl = 1, 8, 1 do
	 system.setControl(ctl, CTRL_steps[step][CTRL_name[ctl]], deltaT, 0)
      end
      if step + 1 > #CTRL_steps then
	 step = 0
	 running = false
      end
      last = now
   end
end

local function init()

   for k,v in ipairs(CTRL_name) do
      print(k,v, type(k), type(v))
   end

   for ctl = 1, 8, 1 do
      print("r:", system.registerControl(
	       ctl, string.format(CTRL_shortName[ctl], ctl),
	       string.format(CTRL_name[ctl], ctl)))
   end

   step = 1
   deltaT = CTRL_steps[step].dt
   running = false
   
   for ctl = 1, 8, 1 do
      print("cn:", CTRL_name[ctl])
      system.setControl(ctl, CTRL_steps[step][CTRL_name[ctl]], 0, 0)
   end

end





--------------------------------------------------------------------------------

return {init=init, loop=loop, name="CTRL", author="JETI model", version="1.0"}
