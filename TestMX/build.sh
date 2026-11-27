#!/bin/sh
# Build TestMX/testmx_c.so against a JETI-like Lua 5.3.1 (LUA_32BITS).
# usage: TestMX/build.sh [lua-src-dir]   (default ~/lua-5.3.1-Jeti-typefix/src)
# The Lua that loads it must export the C API (linux build: -Wl,-E) and have
# package.loadlib (dlopen).
#
# Coded by Claude Code with guidance from D. McQueeney
set -e
LUASRC=${1:-$HOME/lua-5.3.1-Jeti-typefix/src}
HERE=$(cd "$(dirname "$0")" && pwd)
# cjson/: Lua CJSON 2.1.0, JETI's json library (TestMX/cjson/README.md)
gcc -O2 -Wall -shared -fPIC -I"$LUASRC" -I"$HERE/cjson" -o "$HERE/testmx_c.so" \
    "$HERE/testmx_c.c" "$HERE/cjson/lua_cjson.c" "$HERE/cjson/strbuf.c" "$HERE/cjson/fpconv.c" -lm
echo "built $HERE/testmx_c.so against $LUASRC"
