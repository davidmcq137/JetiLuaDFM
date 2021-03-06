-- ############################################################################# 
-- # Jeti ECU Telemetry window2
-- #
-- # Copyright (c) 2019, Markus Zipperer (Markus.Zipperer@onlinehome.de)
-- # Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V0.5 - Initial release
-- ############################################################################# 

local telemetry_window2 = {}

----------------------------------------------------------------------
local function DrawGauge(percentage, ox, oy) 

	local bw = 11 -- 25  width of bar
	local oxo =ox

	ox = ox - (25-bw)-2
    
    -- battery symbol
    lcd.drawRectangle(36+ox,29+oy,3,2)
    lcd.drawRectangle(35+ox,31+oy,5,12)
    lcd.drawText(35+ox,2+oy, "F", FONT_MINI)  
    lcd.drawText(35+ox,54+oy, "E", FONT_MINI)  

	ox=oxo
	
    -- fuel bar 
    lcd.drawRectangle (5+ox,53+oy,bw,11)  -- lowest bar segment
    lcd.drawRectangle (5+ox,41+oy,bw,11)  
    lcd.drawRectangle (5+ox,29+oy,bw,11)  
    lcd.drawRectangle (5+ox,17+oy,bw,11)  
    lcd.drawRectangle (5+ox,5+oy,bw,11)   -- uppermost bar segment
    
    -- calc bar chart values
    local nSolidBar = math.floor( percentage / 20 )
    local nFracBar = (percentage - nSolidBar * 20) / 20  -- 0.0 ... 1.0 for fractional bar
    local i
    -- solid bars
    for i=0, nSolidBar - 1, 1 do 
      lcd.drawFilledRectangle (5+ox,53-i*12+oy,bw,11) 
    end  
    --  fractional bar
    local y = math.floor( 53-nSolidBar*12+(1-nFracBar)*11 + 0.5)
    lcd.drawFilledRectangle (5+ox,y+oy,bw,11*nFracBar)
end

----------------------------------------------------------------------
local function DrawText(ox, oy) 
  local vs      = 15 -- vertical space  13
  oy = oy +2 -- vertical space start  10

	--rpm set/real
  if(config_R.converter.sensormap.rpmset and SensorT_R.rpmset.sensor and config_R.converter.sensormap.rpm and SensorT_R.rpm.sensor) then
    lcd.drawText(4+ox, vs*0+oy+4, 'Set/Real:', FONT_MINI)
    lcd.drawText(52+ox,vs*0+oy, string.format("%s%s%s%s",math.floor(SensorT_R.rpmset.sensor.value/1000), "/" ,math.floor(SensorT_R.rpm.sensor.value/1000), " K"), FONT_BOLD)  --35
  end
  

  if(config_R.converter.sensormap.rpm2 and SensorT_R.rpm2.sensor) then
    lcd.drawText(4+ox, vs*1+oy+4, 'Rpm2', FONT_MINI)
    lcd.drawText(52+ox,vs*1+oy, string.format("%s",math.floor(SensorT_R.rpm2.sensor.value) ), FONT_BOLD)
   -- lcd.drawText(70+ox,vs*2+oy, string.format("%s",SensorT_R.rpm2.sensor.max), FONT_MINI)
  end
  
  if(config_R.converter.sensormap.egt and SensorT_R.egt.sensor) then
    lcd.drawText(4+ox, vs*2+oy+4, 'EGT', FONT_MINI)
    lcd.drawText(52+ox,vs*2+oy, string.format("%s%s",math.floor(SensorT_R.egt.sensor.value)," °C"), FONT_BOLD)
   -- lcd.drawText(70+ox,vs*3+oy, string.format("%s%s",SensorT_R.egt.sensor.max,"C"), FONT_MINI)
  end
  
  if(config_R.converter.sensormap.altitude and SensorT_R.altitude.sensor) then
    lcd.drawText(4+ox, vs*3+oy+4, 'Alti', FONT_MINI)
    lcd.drawText(52+ox,vs*3+oy, string.format("%s%s",math.floor(SensorT_R.altitude.sensor.value)," m"), FONT_BOLD)
  end
end

----------------------------------------------------------------------
-- Print the telemetry values
function telemetry_window2.show(width, height) 

    if(sensorsOnline_R > 0) then
      -- field separator lines vertical
      lcd.drawLine(28,2,28,66)  
      --lcd.drawLine(70,36,148,36)  
 
	-- batt gauge
      if(config_R.converter.sensormap.ecuv and SensorT_R.ecuv) then
        DrawGauge(SensorT_R.ecuv.percent, 1, 0)
      end

      -- engine values
      DrawText(30, 0)

    else
      lcd.drawText(5,5, 'OFFLINE', FONT_MAXI)
    end
end

return telemetry_window2