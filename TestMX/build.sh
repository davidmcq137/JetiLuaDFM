#!/bin/sh
# Build TestMX/testmx_c.so against a JETI-like Lua 5.3.1 (LUA_32BITS).
# usage: TestMX/build.sh [lua-src-dir]   (default ~/lua-5.3.1-Jeti-typefix/src)
# The Lua that loads it must export the C API (linux build: -Wl,-E) and have
# package.loadlib (dlopen).
set -e
LUASRC=${1:-$HOME/lua-5.3.1-Jeti-typefix/src}
HERE=$(cd "$(dirname "$0")" && pwd)
gcc -O2 -Wall -shared -fPIC -I"$LUASRC" -o "$HERE/testmx_c.so" "$HERE/testmx_c.c" -lm
echo "built $HERE/testmx_c.so against $LUASRC"
