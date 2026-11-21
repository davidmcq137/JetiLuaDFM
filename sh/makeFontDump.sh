set -e
set -x
rm -f FontDump.zip
zip -ru FontDump.zip FontDump.lua FontDump -x '*.out'
