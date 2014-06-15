#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/aria.json | $jq "$2" | sh && echo "ok $1") || echo "not ok $1"
}

test 1 '.roles.alert.attrs["aria-expanded"] | not | not'
test 2 '.attrs["aria-selected"].is_state | not | not'
