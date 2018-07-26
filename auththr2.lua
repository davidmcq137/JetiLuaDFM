-- auto throttle main telemetry screen 1

local ytable = {}
local ytable2 = {}
local ytable3 = {}
local oldTime = 0
local mrs = 0 

local ww
local ix
local iy, iy2, iy3
local now
local last_now=0
local last_thr=-5
local same_thr=false
local capture = false
local steady_time = -1
local steady_thr_val = false
local thr_pct = 0
local comp_spd
local spd=0
local set_pct
local set_spd
local comp_spd
local p_val
local i_val = 0
local Kp = 1
local Ki = 0


local function printForm()        

   lcd.setColor(0,0,0)

   lcd.drawLine(2, 2, 2, 2+50)
   lcd.drawLine(2,2+50/2, 300+2, 2+50/2)

   lcd.drawLine(2, 2+60, 2, 2+60+50)
   lcd.drawLine(2,2+50/2+60, 300+2, 2+50/2+60)


--[[ 
  if (system.getTime() ~= oldTime) then
    oldTime = system.getTime()
    mrs = 0.85 * mrs + 0.15 * math.random(1,59)
    table.insert(ytable, #ytable+1, mrs)

    if #ytable > 60 then
      table.remove(ytable, 1)
    end
  end
--]]

  local a = .05

 --  mrs = (1-a) * mrs + a * math.random(-2,2)

  now = system.getTimeCounter()

  local P4  = system.getInputs("P4")
  local P8  = system.getInputs("P8")

  local eps = (1+1)/1000*10

  if math.abs(P4 - last_thr) > eps then
    same_thr = false
    steady_time = 0
    steady_thr_val = false
  else
    if not same_thr then
      same_thr = true
      steady_time = now
    else
      if (now - steady_time > 2000) and (not steady_thr_val) then
        steady_thr_val = P4
        thr_pct = (P4+1)*50
        print(string.format("Throttle steady at %.0f%%", thr_pct))
--        print("Thr steady at: ", (P4+1)*50, "%")
      end
    end
  end
  last_thr = P4

-- put code here to track i_val to thr when loop reg off


  local epsC = (1+1)/1000*50

  if (math.abs(P4-P8) >= epsC) then
    capture = false
  else
    if not capture then
      system.playBeep(2, 5000, 100)
      print("Beep!")
      capture = true
    end
  end

  set_pct = (P8+1)*50
  set_spd = set_pct*2    
  comp_spd = thr_pct * 2
  
  spd = 0.90*spd + 0.1*comp_spd
  
  p_val = Kp * (spd-set_spd)
  i_val = i_val + Ki * (spd-set_spd)
  if i_val < 0 then i_val = 0 end
  if i_val > 100 then i_val = 100 end
  e_val = p_val + i_val
  if e_val < 0 then e_val = 0 end
  if e_val >=100 then e_val = 100 end
  

  if now-last_now >  200 then -- 200 msec * 300 pts = 60 sec
    last_now = now


    iy = 2+50/2 + (50/2)*P4
    iy2 = 2+50/2 + (50/2) * P8
    iy3 = e_val*60/100

    if iy < 2 then iy = 2 end
    if iy > 50+2 then iy = 50+2 end   
    if iy2 < 2 then iy2 = 2 end
    if iy2 > 50+2 then iy2 = 50+2 end   
    -- iy3 already clipped

    table.insert(ytable, #ytable+1, iy)
    -- print('#ytable: ', #ytable)
    if #ytable > 300 then
      -- print('over 300')
      table.remove(ytable, 1)
    end

    table.insert(ytable2, #ytable2+1, iy2)
    -- print('#ytable2: ', #ytable2)
    if #ytable2 > 300 then
      -- print('over 300')
      table.remove(ytable2, 1)
    end

    table.insert(ytable3, #ytable3+1, iy3)
    -- print('#ytable3: ', #ytable3)
    if #ytable3 > 300 then
      -- print('over 300')
      table.remove(ytable3, 1)
    end
  end

  local ss = string.format("P4: %2f", P4)
  ww = lcd.getTextWidth(FONT_NORMAL, ss)
  lcd.drawText(5+(300-ww)/2-1,2,ss, FONT_MINI)

  ss = string.format("P8: %2f", P8)
  ww = lcd.getTextWidth(FONT_NORMAL, ss)
  lcd.drawText(5+(300-ww)/2-1,2+60,ss, FONT_MINI)


  local ix = 0

  for i = 1,#ytable,1 do
    ix = ix + 1
    iy = 60-ytable[i]
    lcd.setColor(200, 0, 0)
    lcd.drawPoint(ix+1,iy)
    iy2 = 60-ytable2[i]
    lcd.setColor(0, 0, 200)
    lcd.drawPoint(ix+1, iy2)
    iy3 = 60-ytable3[i]
    lcd.setColor(200,0,0)
    lcd.drawPoint(ix+1, iy3+60)
  end

  lcd.setColor(0, 0, 0)

  collectgarbage()
 
end   


local function init() 
  system.registerForm(1,MENU_MAIN,"Auto Throttle",nil, nil,printForm) 
end
--------------------------------------------------------------------------------
return {init=init, author="JETI model", version="1.0"}


