set -e
set -x
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/DFM-GPSm.lc DFM-GPS/DFM-GPS.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/drawTape.lc DFM-GPS/drawTape.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/mainMenuCmd.lc DFM-GPS/mainMenuCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/initCmd.lc DFM-GPS/initCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/compGeo.lc DFM-GPS/compGeo.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/drawMono.lc DFM-GPS/drawMono.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/drawColor.lc DFM-GPS/drawColor.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/settingsCmd.lc DFM-GPS/settingsCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/genSettingsCmd.lc DFM-GPS/genSettingsCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/selTeleCmd.lc DFM-GPS/selTeleCmd.lua
/home/davidmcq/lua-5.3.1-Jeti/src/luac -s -o DFM-GPS/selFieldCmd.lc DFM-GPS/selFieldCmd.lua
rm -f DFM-GPS.zip
zip -ru DFM-GPS.zip DFM-GPS.lua DFM-GPSm.lc DFM-GPS

