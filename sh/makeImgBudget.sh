set -e
set -x
rm -f zip/ImgBudget.zip
# img/ links to ImgTest/: zip stores the images themselves (not the link)
zip -r zip/ImgBudget.zip ImgBudget.lua ImgBudget -x '*.out' '*.txt' 'ImgBudget/img/*.lua'
