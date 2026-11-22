set -e
set -x
rm -f zip/SensorE.zip
zip -ru zip/SensorE.zip SensorE.lua SensorE.jsn DFM-Maps/SensorE/sensorEmulator.jsn DFM-Maps/SensorE/sensorEmulatorGPS.jsn
