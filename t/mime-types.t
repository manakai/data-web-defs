#!/bin/sh
echo "1..11"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/mime-types.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["application/smil"].deprecated == "obsolete"'
test 2 '.["application/smil"].preferred_type == "application/smil+xml"'
test 3 '.["application/smil"].any_xml == 1'
test 4 '.["application/smil"].iana == "permanent"'
test 5 '.["application/*"].iana == "permanent"'
test 6 '.["www/*"].type == "type"'
test 7 '.["*/*"].type == "subtype"'
test 8 '.["text/javascript"].obsolete | not'
test 9 '.["text/javascript"].deprecated | not'
test 10 '.["application/javascript"].obsolete | not | not'
test 11 '.["*/*+xml"].iana == "permanent"'
