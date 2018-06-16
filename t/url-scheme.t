#!/bin/sh
echo "1..4"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/url-schemes.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.https.secure | not | not '
test 2 '.http.secure | not'
test 3 '.aaa.iana | not | not'
test 4 '.ocf.iana | not | not'