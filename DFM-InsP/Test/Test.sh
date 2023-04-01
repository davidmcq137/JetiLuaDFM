set -e
set -x
rm -f II_Testfile.jsn
lua -l cjson -l lfs TestRun.lua
jq -S . II_Testfile.jsn > TestA.jsn
jq -S . II_Testfile-Ref.jsn > TestB.jsn
diff TestA.jsn TestB.jsn
rm -f TestA.jsn
rm -f TestB.jsn
