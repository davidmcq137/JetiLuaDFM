-- ############################################################################# 
-- # Jeti ECU Telemetry window1
-- #
-- # Copyright (c) 2019, Markus Zipperer (Markus.Zipperer@onlinehome.de)
-- # Original idea by Thomas Ekdahl (thomas@ekdahl.no)
-- #
-- # License: Share alike                                       
-- # Can be used and changed non commercial, but feel free to send us changes back to be incorporated in the main code.
-- #                       
-- # V1.1 - Initial release
-- ############################################################################# 

local telemetry_window1 = {}
----------------------------------------------------------------------
--

----------------------------------------------------------------------
local function DrawFuelGauge(percentage, ox, oy) 

	local bw = 11 -- 25  width of bar
	local oxo =ox
	
	ox = ox - (25-bw)-2
    -- gas station symbol
    lcd.drawRectangle(34+ox,31+oy,5,9)  
    lcd.drawLine(35+ox,34+oy,37+ox,34+oy)
    lcd.drawLine(33+ox,39+oy,39+ox,39+oy)
    lcd.drawLine(40+ox,31+oy,42+ox,33+oy)
    lcd.drawLine(42+ox,33+oy,42+ox,37+oy)
    lcd.drawPoint(40+ox,38+oy)  
    lcd.drawLine(40+ox,38+oy,40+ox,35+oy)  
    lcd.drawPoint(39+ox,35+oy)
    lcd.drawText(34+ox,2+oy, "F", FONT_MINI)  
    lcd.drawText(34+ox,54+oy, "E", FONT_MINI)  
  
	ox=oxo
	
    -- fuel bar 
    lcd.drawRectangle (3+ox,53+oy,bw,11)  -- lowest bar segment
    lcd.drawRectangle (3+ox,41+oy,bw,11)  
    lcd.drawRectangle (3+ox,29+oy,bw,11)  
    lcd.drawRectangle (3+ox,17+oy,bw,11)  
    lcd.drawRectangle (3+ox,5+oy,bw,11)   -- uppermost bar segment
    
    -- calc bar chart values
    local nSolidBar = math.floor( percentage / 20 )
    local nFracBar = (percentage - nSolidBar * 20) / 20  -- 0.0 ... 1.0 for fractional bar
    local i
    -- solid bars
    for i=0, nSolidBar - 1, 1 do 
      lcd.drawFilledRectangle (3+ox,53-i*12+oy,bw,11) 
    end  
    --  fractional bar
    local y = math.floor( 53-nSolidBar*12+(1-nFracBar)*11 + 0.5)
    lcd.drawFilledRectangle (3+ox,y+oy,bw,11*nFracBar) 

    --lcd.drawText(4+ox,15+oy, config.fuel.tanksize, FONT_BOLD)
    --lcd.drawText(1+ox,49+oy, string.format("Fulltank: %.1f",tonumber(config.fuel.tanksize/1000)), FONT_BOLD)
end

----------------------------------------------------------------------
local function DrawTurbineStatus(status, ox, oy) 
    --lcd.drawText(2+ox,2+oy, "Turbine", FONT_MINI)  
    lcd.drawText(ox, oy, status, FONT_BOLD)  
end

----------------------------------------------------------------------
local function DrawFuelLow(percentage, ox, oy) 

  local tw=13
  local xs=ox+2
  local oyo =oy

  oy=oy+6
  
  if( system.getTime() % 2 == 0) then -- blink every second
    -- triangle
    lcd.drawLine(tw+xs,5+oy, xs,35+oy)	-- 21+ox,5+oy,2+ox,35+oy
    lcd.drawLine(xs,35+oy,xs+(2*tw),35+oy) --2+ox,35+oy,41+ox,35+oy
    lcd.drawLine(xs+(2*tw),35+oy,tw+xs,5+oy) --41+ox,35+oy,21+ox,5+oy
    lcd.drawText(tw+xs-2,14+oy, "!", FONT_BIG) --  20+ox,11+oy, "!", FONT_BIG
  end  
  
  oy=oyo
  -- percentage and warning
  lcd.drawText(1+ox,49+oy, string.format("%d%s",tonumber(percentage),"%"), FONT_BOLD)    
end

----------------------------------------------------------------------
-- Print the telemetry values
function telemetry_window1.show(width, height) 
  
  local xs=38
  
  if(SensorID ~= 0) then
    if(sensorsOnline > 0) then
        -- field separator lines
        lcd.drawLine(32,2,32,36)  --45,2,45,66
		
		--lcd.drawLine(32,18,148,18)  --45,36,148,36
		
        lcd.drawLine(32,36,148,36)  --45,36,148,36

		lcd.drawLine(xs+60,36,xs+60,66) -- pumpv seperator line
		-- fuel
        if(config.converter.sensormap.fuel) then
          if(SensorT.fuel.percent) then
            if(SensorT.fuel.percent > 20) then
              DrawFuelGauge(SensorT.fuel.percent, 1, 0)
            else
              DrawFuelLow(SensorT.fuel.percent, 1, 0)
            end
          end
        end

        -- turbine state
        if(config.converter.sensormap.status) then
          if(SensorT.status.text) then
            DrawTurbineStatus(SensorT.status.text, xs, 0)
          else
            DrawTurbineStatus("UNKNOWN", xs, 0)
          end
        else
              DrawTurbineStatus("UNCONFIG", xs, 0)
        end


        -- Restvol
        if(config.converter.sensormap.fuel and SensorT.fuel.sensor.value) then		  
		    lcd.drawText(xs,1+37, "Fuel", FONT_MINI)  
			lcd.drawText(xs,12+37,  string.format("%1.0f%s",SensorT.fuel.sensor.value,"ml"), FONT_BOLD)
        end
		
        -- pumpv
        if(config.converter.sensormap.pumpv and SensorT.pumpv.sensor.value) then		  
		    lcd.drawText(xs+65,1+37, "Pump", FONT_MINI)  
			lcd.drawText(xs+65,12+37,  string.format("%.1f%s",SensorT.pumpv.sensor.value,"V"), FONT_BOLD)
        end		
		
		--battery V
        if(config.converter.sensormap.ecuv and SensorT.ecuv.sensor.value) then		  			
			lcd.drawText(xs,17, string.format("%.1f%s",SensorT.ecuv.sensor.value,"V"), FONT_BOLD)
        end
		
		
		if(config.converter.sensormap.battcapa and SensorT.battcapa.sensor) then
			-- mit capa, 1s abwechselnd
			
			if( system.getTime() % 2 == 0) then -- switch every second
				-- curr zeigen
				if(config.converter.sensormap.engcurr and SensorT.engcurr.sensor) then		
					lcd.drawText(xs+42,17, string.format("%.1f%s",SensorT.engcurr.sensor.value,"A"), FONT_BOLD)  --35
				end
			else
				-- capa anz
				lcd.drawText(xs+42,17, string.format("%1.0f%s",SensorT.battcapa.sensor.value,"mAh"), FONT_BOLD)  --35			end		
			end
		else
			--gibt keine capa --> nur strom
			if(config.converter.sensormap.engcurr and SensorT.engcurr.sensor) then		
				lcd.drawText(xs+42,17, string.format("%.1f%s",SensorT.engcurr.sensor.value,"A"), FONT_BOLD)  --35
			end	
		end
		


		
    else
      lcd.drawText(5,5, 'OFFLINE', FONT_MAXI)
    end
  else
    DrawTurbineStatus("NO CONFIG", xs, 0)
  end
end

return telemetry_window1