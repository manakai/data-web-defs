#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/microdata.json | $jq "$2" | sh && echo "ok $1") || echo "not ok $1"
}

test 1 '.["http://schema.org/CreativeWork"].props.accessibilityAPI.enum.ARIA.spec | not | not'
test 2 '.["http://schema.org/CreativeWork"].props.interactivityType.enum.active.spec | not | not'
