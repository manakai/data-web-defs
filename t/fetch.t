#!/bin/sh
echo "1..1"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/fetch.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.referrer_policy.values["no-referrer"].value == "no-referrer"'
