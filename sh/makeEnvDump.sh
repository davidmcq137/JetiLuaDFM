set -e
set -x
rm -f zip/EnvDump.zip
zip -ru zip/EnvDump.zip EnvDump.lua EnvDump -x '*.out'
