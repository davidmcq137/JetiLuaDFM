set -e
set -x
rm -f SensorE.zip
zip -ru SensorE.zip SensorE.lua SensorE.jsn DFM-Maps/SensorE/sensorEmulator.jsn DFM-Maps/SensorE/sensorEmulatorGPS.jsn
