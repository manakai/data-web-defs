#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/tlds.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.tlds.com.iana | not | not'
test 2 '.tlds.jp.iana | not | not'
test 3 '.tlds.arpa.iana | not | not'
