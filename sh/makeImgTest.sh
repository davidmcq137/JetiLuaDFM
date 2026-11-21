set -e
set -x
rm -f ImgTest.zip
zip -ru ImgTest.zip ImgTest.lua ImgTest -x '*.out'
