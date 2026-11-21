#!/bin/sh
# Build FakeFW/fakefw_c.so against a JETI-like Lua 5.3.1 (LUA_32BITS).
# usage: FakeFW/build.sh [lua-src-dir]   (default ~/lua-5.3.1-Jeti-typefix/src)
# The Lua that loads it must export the C API (linux build: -Wl,-E) and have
# package.loadlib (dlopen).
set -e
LUASRC=${1:-$HOME/lua-5.3.1-Jeti-typefix/src}
HERE=$(cd "$(dirname "$0")" && pwd)
gcc -O2 -Wall -shared -fPIC -I"$LUASRC" -o "$HERE/fakefw_c.so" "$HERE/fakefw_c.c" -lm
echo "built $HERE/fakefw_c.so against $LUASRC"
