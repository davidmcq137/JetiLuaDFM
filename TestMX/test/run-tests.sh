#!/bin/sh
# TestMitter acceptance tests. Run from the parent of Apps (the Emulator folder):
#   Apps/TestMX/test/run-tests.sh [path-to-JETI-like-lua]
# (default ~/lua-5.3.1-Jeti-typefix/src/lua; in CI, fazzone/lua_jeti with
# ltm-typefix.patch). Build TestMX/testmx_c.so first (TestMX/build.sh).
# Tests: GpsTest on the emulator and DS-24 5.08 profiles, EnvDump and FontDump
# on those and the DS-16 5.06 profile, JsonProbe against the emulator's json,
# against the measured outputs, the DFM-TimG UIDriver scripts with DFM-HUD (SensorL replays
# Log/20190926/16-56-45.log, unpacked from 16-56-45.log.gz if missing), and
# DFM-Maps' scripts on the maps-bds458 (emulator) and maps-bds320 (ds24-508)
# fixtures (TestMX/testmx-uid.lua), DFM-HUD with fake Engo glasses, and
# DFM-SWT's press counting with a real model file, DFM-InsP's sequencer, and DFM-Rscu/DFM-Path
# rescue and path steering on their own SensorE configs.
# Exit code: the number of failed tests.
LUA=${1:-$HOME/lua-5.3.1-Jeti-typefix/src/lua}
T=Apps/TestMX/test
fails=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

# the emulator profile sorts strings with en_US.UTF-8 collation, as the
# emulator does; say whether this machine has it (a warning, not a failure)
"$LUA" -e 'print("collation en_US.UTF-8: " .. (os.setlocale("en_US.UTF-8", "collate") and "available" or "MISSING, string order may differ from the emulator"))'

# the top-level app files are gitignored symlinks to the app folders. Links
# made here are removed at the end, so the emulator's list (appset) stays
# as it was
made=""
for a in GpsTest UIDriver SensorL SensorE DFM-TimG DFM-HUD DFM-Maps DFM-SWT DFM-Rscu DFM-Path DFM-InsP DFM-Dial; do
   if [ ! -e Apps/$a.lua ]; then ln -s $a/$a.lua Apps/$a.lua && made="$made Apps/$a.lua"; fi
done
# (one trap for both: a second "trap ... EXIT" would replace the first)
trap 'for l in $made; do [ -L "$l" ] && rm "$l"; done; rm -rf "$TMP"' EXIT
if [ ! -f Log/20190926/16-56-45.log ]; then
   mkdir -p Log/20190926
   gunzip -c $T/16-56-45.log.gz > Log/20190926/16-56-45.log
fi

# GpsTest writes Apps/GpsTest/gpstest.out; keep any existing one
OUT=Apps/GpsTest/gpstest.out
[ -f $OUT ] && cp $OUT $OUT.keep
if "$LUA" Apps/TestMX/testmx.lua GpsTest > /dev/null && cmp -s $OUT $T/gpstest-emu606.txt; then
   ok "GpsTest emu-ds24ii-606 = emulator 6.06"
else
   bad "GpsTest emu-ds24ii-606"; diff $OUT $T/gpstest-emu606.txt | head -20
fi
# the 5.08 file was written by an older GpsTest with a shorter header
if "$LUA" Apps/TestMX/testmx.lua -p ds24-508 GpsTest > /dev/null; then
   tail -n +2 $OUT > $TMP/got; tail -n +2 $T/gpstest-ds24-508.txt > $TMP/want
fi
if cmp -s $TMP/got $TMP/want; then
   ok "GpsTest ds24-508 = DS-24 fw 5.08 (apart from the header)"
else
   bad "GpsTest ds24-508"; diff $TMP/got $TMP/want | head -20
fi
if [ -f $OUT.keep ]; then mv $OUT.keep $OUT; else rm -f $OUT; fi

# EnvDump: what an app sees (globals, libraries, constants) against the
# real dumps; the clock lines differ, EnvDump 1.5+ adds check and probe
# lines, and the emulator's internal
# globals/globalVarList tables aren't modelled
[ -e Apps/EnvDump.lua ] || ln -s EnvDump/EnvDump.lua Apps/EnvDump.lua
EOUT=Apps/EnvDump/envdump.out
[ -f $EOUT ] && cp $EOUT $EOUT.keep
SKIP='^check \|^probe \|^getTime\|^getDateTime\|^os.time\|^globals \|globals\.\|^G globals \|globalVarList'
for pr in "emu-ds24ii-606 envdump-emu606" "ds24ii-606 envdump-ds24ii-606" "ds24-508 envdump-ds24-508" "ds16-506 envdump-ds16-506"; do
   set -- $pr
   rm -f $EOUT
   "$LUA" Apps/TestMX/testmx.lua -p $1 -t 2 EnvDump > /dev/null
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
for pr in "emu-ds24ii-606 fontdump-emu606" "ds24ii-606 fontdump-ds24ii-606" "ds24-508 fontdump-ds24-508" "ds16-506 fontdump-ds16-506"; do
   set -- $pr
   rm -f $FOUT
   "$LUA" Apps/TestMX/testmx.lua -p $1 -t 1 FontDump > /dev/null
   # the header line carries FontDump's version
   tail -n +2 $FOUT > $TMP/got 2>/dev/null; tail -n +2 $T/$2.txt > $TMP/want
   if cmp -s $TMP/got $TMP/want; then
      ok "FontDump $1 = $2.txt"
   else
      bad "FontDump $1"; LC_ALL=C diff -a $TMP/got $TMP/want | head -20
   fi
done
if [ -f $FOUT.keep ]; then mv $FOUT.keep $FOUT; else rm -f $FOUT; fi

# JsonProbe: TestMitter's json (the real Lua CJSON, TestMX/cjson) against
# the emulator's, every case after the header line
if [ ! -e Apps/JsonProbe.lua ]; then
   ln -s JsonProbe/JsonProbe.lua Apps/JsonProbe.lua && made="$made Apps/JsonProbe.lua"
fi
JOUT=Apps/JsonProbe/jsonprobe.out
[ -f $JOUT ] && cp $JOUT $JOUT.keep
rm -f $JOUT
"$LUA" Apps/TestMX/testmx.lua -t 1 JsonProbe > /dev/null
sed 1d $JOUT > $TMP/got 2>/dev/null; sed 1d Apps/JsonProbe/jsonprobe-emu606.txt > $TMP/want
if cmp -s $TMP/got $TMP/want; then
   ok "JsonProbe emu-ds24ii-606 = jsonprobe-emu606.txt"
else
   bad "JsonProbe emu-ds24ii-606"; diff $TMP/got $TMP/want | head -20
fi
if [ -f $JOUT.keep ]; then mv $JOUT.keep $JOUT; else rm -f $JOUT; fi

# DFM-TimG's scripts: SensorL replays the Georgia Jets log, the sliders
# sit where the TimG test model has them, and TimG starts first (the init
# order that once broke SensorL). hud-test runs the real DFM-HUD, which
# reads TimG's DFM_TimG global; its serial port is TestMitter's null device
for t in "timg-test -" "hud-test DFM-HUD"; do
   set -- $t
   s=$1; also=""; [ "$2" = - ] || also="--also $2"
   if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-TimG --script $1.jsn --sensor SensorL \
	$also --controls P5=-0.5,P6=0.1,SA=-1 --target-first --form Geriatric > $TMP/$s 2>&1; then
      ok "DFM-TimG $s: $(grep '^==== DONE' $TMP/$s)"
   else
      bad "DFM-TimG $s"; grep -v '^\[UID\]' $TMP/$s | tail -30
   fi
done

# DFM-Maps' UIDriver scripts through the file layers (nothing is read from
# or written to the working data): the field data in maps-bds458 (DS-24 II)
# or maps-bds320 (DS-24, older TXs), settings from a preset listed before it
# (none = Maps' init defaults, as on a first start); confirm steps are
# skipped, as nobody is there to answer them. On ds24-508 the telemetry
# button steps are skipped too (fw 5.08 has no setTelemetryButton)
for t in "nofly-test maps-bds458 emu-ds24ii-606" "maps-smoke maps-tri,maps-bds458 emu-ds24ii-606" \
	 "nofly-test maps-bds320 ds24-508" "maps-smoke maps-tri,maps-bds320 ds24-508"; do
   set -- $t
   if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-Maps --script $1.jsn \
	--fixture $2 --model TestMX -p $3 > $TMP/$1-$3 2>&1; then
      ok "DFM-Maps $1 ($2, $3): $(grep '^==== DONE' $TMP/$1-$3)"
   else
      bad "DFM-Maps $1 ($2, $3)"; grep -v '^\[UID\]' $TMP/$1-$3 | tail -30
   fi
done

# DFM-HUD against TestMitter's fake Engo glasses (TestMX/devices/engo.lua):
# config upload, select, battery polls and gauge frames. HUD opens ttyUSB0
# in the emulator and COM1 on a TX; its form stays closed (no gauges are
# sent while a form is open); model Abc has the gauges (Json/GG_Abc.jsn)
for t in "emu-ds24ii-606 ttyUSB0" "ds24ii-606 COM1"; do
   set -- $t
   if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-HUD --script engo-test.jsn --model Abc \
	--no-form --serial $2=engo -p $1 > $TMP/engo-$1 2>&1; then
      ok "DFM-HUD engo-test ($1): $(grep '^==== DONE' $TMP/engo-$1)"
   else
      bad "DFM-HUD engo-test ($1)"; grep -v '^\[UID\]' $TMP/engo-$1 | tail -30
   fi
done

# DFM-SWT's press counting (1 press, 2 presses, a long press) on switch SA.
# SWT reads the model file at init: a real one (0004Ultr.jsn, 57 KB) from
# the model-ultr fixture. Emulator profile only: the clock starts negative
# there (SWT 0.6 counted the long press as a short one), and on a TX
# profile UIDriver can't tell SWT's form ("Short/Long Switch") is SWT's
if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-SWT --script swt-presses.jsn --sensor none \
     --fixture model-ultr --model-file 0004Ultr.jsn > $TMP/swt 2>&1; then
   ok "DFM-SWT swt-presses: $(grep '^==== DONE' $TMP/swt)"
else
   bad "DFM-SWT swt-presses"; grep -v '^\[UID\]' $TMP/swt | tail -30
fi

# DFM-Rscu and DFM-Path on their own SensorE configs (Apps/<App>/SensorE).
# Emulator profile only: in the emulator Rscu picks its GPS sensors by label
# (Latitude, Longitude ...), so the scripts need no saved settings
rp() {
   if "$LUA" Apps/TestMX/testmx-uid.lua --app $1 --script $2.jsn > $TMP/$2 2>&1; then
      ok "$1 $2: $(grep '^==== DONE' $TMP/$2)"
   else
      bad "$1 $2"; grep -v '^\[UID\]' $TMP/$2 | tail -30
   fi
}
rp DFM-Rscu rscu-test
rp DFM-Rscu rscu-controls-test
rp DFM-Path path-controls-test

# DFM-Dial: min/max warnings across restarts ("restartApp"). Since 1.14 "no
# warning" is false, so a warning on one dial only saves as [false,5], not
# [null,5] (Lua CJSON); upgrade-113 starts from a 1.13 file holding [null,5]
# (fixture dial-113). The model name picks the file, DD_TestMX.jsn
rd() {
   if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-Dial --script $1.jsn --model TestMX $2 > $TMP/$1 2>&1; then
      ok "DFM-Dial $1: $(grep '^==== DONE' $TMP/$1)"
   else
      bad "DFM-Dial $1"; grep -v '^\[UID\]' $TMP/$1 | tail -30
   fi
}
rd warn-roundtrip
rd upgrade-113 "--fixture dial-113"

# DFM-InsP's sequencer after panel edits, on the insp-aaa fixture (settings
# with 2 panels and 2 old sequencer entries naming panels that are gone)
ip() {
   if "$LUA" Apps/TestMX/testmx-uid.lua --app DFM-InsP --script $1.jsn \
	--fixture ${2:-insp-aaa} --model TestMX > $TMP/$1 2>&1; then
      ok "DFM-InsP $1: $(grep '^==== DONE' $TMP/$1)"
   else
      bad "DFM-InsP $1"; grep -v '^\[UID\]' $TMP/$1 | tail -30
   fi
}
ip seq-stale-target
ip seq-new-entry
ip seq-image-change
ip panel-list
ip bad-settings insp-bad,insp-aaa

# warnings that don't fail a test: message boxes too long for a DS-24
grep -h '^\[FW\] warning:' $TMP/* 2>/dev/null | sort -u | sed 's/^\[FW\] warning: /WARN: /'

echo "TestMitter tests: $fails failed"
exit $fails
