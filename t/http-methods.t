#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/http-methods.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.SEARCH.idempotent == 1'
test 2 '.SEARCH.protocols.HTTP == 1'
