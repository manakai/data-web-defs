#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/http-status-codes.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["101"].iana.HTTP | not | not'
test 2 '.["103"].iana.HTTP | not | not'
test 3 '.["201"].iana.RTSP | not | not'
