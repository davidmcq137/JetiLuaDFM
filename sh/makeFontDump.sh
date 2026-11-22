set -e
set -x
rm -f zip/FontDump.zip
zip -ru zip/FontDump.zip FontDump.lua FontDump -x '*.out'
