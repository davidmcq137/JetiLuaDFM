set -e
set -x
cp -rv DFM-GPS/*.lc /media/ds16/Apps/DFM-GPS/
cp -rv DFM-GPS/*.jsn /media/ds16/Apps/DFM-GPS/
rm -v /media/ds16/Apps/DFM-GPS/GG_*.jsn
rm -v /media/ds16/Apps/DFM-GPS/DFM-GPSm.lc
cp DFM-GPS/DFM-GPSm.lc /media/ds16/Apps/DFM-GPSm.lc
