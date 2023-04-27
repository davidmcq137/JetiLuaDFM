find . -maxdepth 1  -name '*.json' ! -name config.json ! -name Empty.json -exec sh pandoc.sh {} \;
