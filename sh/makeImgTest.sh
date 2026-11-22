set -e
set -x
rm -f zip/ImgTest.zip
zip -ru zip/ImgTest.zip ImgTest.lua ImgTest -x '*.out'
