#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/headers.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.codings.gzip.transfer.iana == 1'
test 2 '.codings.gzip.content.iana == 1'
test 3 '.range_units.none.reserved == 1'