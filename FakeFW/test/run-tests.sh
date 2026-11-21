#!/bin/sh
# FakeFW acceptance tests. Run from the parent of Apps (the Emulator folder):
#   Apps/FakeFW/test/run-tests.sh [path-to-JETI-like-lua]
# (default ~/lua-5.3.1-Jeti-typefix/src/lua; in CI, fazzone/lua_jeti with
# ltm-typefix.patch). Build FakeFW/fakefw_c.so first (FakeFW/build.sh).
# Tests: GpsTest, EnvDump and FontDump on the emulator and DS-24 5.08 profiles
# against the measured outputs, and the DFM-TimG UIDriver scripts (SensorL replays
# Log/20190926/16-56-45.log, unpacked from 16-56-45.log.gz if missing).
# Exit code: the number of failed tests.
LUA=${1:-$HOME/lua-5.3.1-Jeti-typefix/src/lua}
T=Apps/FakeFW/test
fails=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

# the emulator profile sorts strings with en_US.UTF-8 collation, as the
# emulator does; say whether this machine has it (a warning, not a failure)
"$LUA" -e 'print("collation en_US.UTF-8: " .. (os.setlocale("en_US.UTF-8", "collate") and "available" or "MISSING, string order may differ from the emulator"))'

# the top-level app files are gitignored symlinks to the app folders
for a in GpsTest UIDriver SensorL DFM-TimG; do
   [ -e Apps/$a.lua ] || ln -s $a/$a.lua Apps/$a.lua
done
if [ ! -f Log/20190926/16-56-45.log ]; then
   mkdir -p Log/20190926
   gunzip -c $T/16-56-45.log.gz > Log/20190926/16-56-45.log
fi

# GpsTest writes Apps/GpsTest/gpstest.out; keep any existing one
OUT=Apps/GpsTest/gpstest.out
[ -f $OUT ] && cp $OUT $OUT.keep
if "$LUA" Apps/FakeFW/fakefw.lua GpsTest > /dev/null && cmp -s $OUT $T/gpstest-emu606.txt; then
   ok "GpsTest emu-ds24ii-606 = emulator 6.06"
else
   bad "GpsTest emu-ds24ii-606"; diff $OUT $T/gpstest-emu606.txt | head -20
fi
# the 5.08 file was written by an older GpsTest with a shorter header
if "$LUA" Apps/FakeFW/fakefw.lua -p ds24-508 GpsTest > /dev/null; then
   tail -n +2 $OUT > $TMP/got; tail -n +2 $T/gpstest-ds24-508.txt > $TMP/want
fi
if cmp -s $TMP/got $TMP/want; then
   ok "GpsTest ds24-508 = DS-24 fw 5.08 (apart from the header)"
else
   bad "GpsTest ds24-508"; diff $TMP/got $TMP/want | head -20
fi
if [ -f $OUT.keep ]; then mv $OUT.keep $OUT; else rm -f $OUT; fi

# EnvDump: what an app sees (globals, libraries, constants) against the
# real dumps; the clock lines differ, and the emulator's internal
# globals/globalVarList tables aren't modelled
[ -e Apps/EnvDump.lua ] || ln -s EnvDump/EnvDump.lua Apps/EnvDump.lua
EOUT=Apps/EnvDump/envdump.out
[ -f $EOUT ] && cp $EOUT $EOUT.keep
SKIP='^getTime\|^getDateTime\|^os.time\|^globals \|globals\.\|^G globals \|globalVarList'
for pr in "emu-ds24ii-606 envdump-emu606" "ds24-508 envdump-ds24-508"; do
   set -- $pr
   rm -f $EOUT
   "$LUA" Apps/FakeFW/fakefw.lua -p $1 EnvDump > /dev/null
   grep -v "$SKIP" $EOUT > $TMP/got 2>/dev/null; grep -v "$SKIP" $T/$2.txt > $TMP/want
   if cmp -s $TMP/got $TMP/want; then
      ok "EnvDump $1 = $2.txt"
   else
      bad "EnvDump $1"; diff $TMP/got $TMP/want | head -20
   fi
done
if [ -f $EOUT.keep ]; then mv $EOUT.keep $EOUT; else rm -f $EOUT; fi

# FontDump: text metrics against the real dumps, every line (FontDump 1.2
# measures Latin-1 too)
[ -e Apps/FontDump.lua ] || ln -s FontDump/FontDump.lua Apps/FontDump.lua
FOUT=Apps/FontDump/fontdump.out
[ -f $FOUT ] && cp $FOUT $FOUT.keep
for pr in "emu-ds24ii-606 fontdump-emu606" "ds24-508 fontdump-ds24-508"; do
   set -- $pr
   rm -f $FOUT
   "$LUA" Apps/FakeFW/fakefw.lua -p $1 -t 1 FontDump > /dev/null
   if cmp -s $FOUT $T/$2.txt; then
      ok "FontDump $1 = $2.txt"
   else
      bad "FontDump $1"; LC_ALL=C diff -a $FOUT $T/$2.txt | head -20
   fi
done
if [ -f $FOUT.keep ]; then mv $FOUT.keep $FOUT; else rm -f $FOUT; fi

for s in timg-test hud-test; do
   if "$LUA" Apps/FakeFW/fakefw-timg.lua $s.jsn > $TMP/$s 2>&1; then
      ok "DFM-TimG $s: $(grep '^==== DONE' $TMP/$s)"
   else
      bad "DFM-TimG $s"; grep -v '^\[UID\]' $TMP/$s | tail -30
   fi
done

echo "FakeFW tests: $fails failed"
exit $fails
