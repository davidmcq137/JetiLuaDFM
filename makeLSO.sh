set -e
set -x
zip -ru DFM-LSO.zip DFM-LSO.lua DFM-LSO.txt SensorE.lua SensorE.jsn DFM-LSO -x DFM-LSO/Fields.jsn -x DFM-LSO/*.png -x DFM-LSO/Pipfile* -x DFM-LSO/old/*

