#!/bin/bash
set -e
#set -x
#
# file passed in as $1 from find: ./foo.json
# FNAME foo.json
# BNAME foo
# UNAME FOO
# HNAME EN-FOO.HTML
#
FNAME=$(basename $1)
BNAME="${FNAME%%.*}"
UNAME=$(echo "$BNAME" | awk '{print toupper($0)}')
HNAME='/home/davidmcq/JS/DFM-InsP/Panels/EN-'$UNAME'.HTML'
echo 'Processing' $1 
jq -r '."doc-md"' $FNAME | sed 's/\\n/\n/g' > 'en-'$BNAME'.md'
pandoc 'en-'$BNAME'.md' -t html -o $HNAME --from markdown_strict-smart --metadata title=$BNAME --template="jeti.html"
sed -i s/[”“]/'"'/g $HNAME
cp $HNAME '/home/davidmcq/JSE/DOCS/DFM-INSP/'
