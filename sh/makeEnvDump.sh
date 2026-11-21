set -e
set -x
rm -f EnvDump.zip
zip -ru EnvDump.zip EnvDump.lua EnvDump -x '*.out'
