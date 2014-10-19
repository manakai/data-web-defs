#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/dom.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.idl_defs.DOMTokenList[1].members.toggle[0] == "operation"'
test 2 '.idl_defs.DOMTimeStamp.definition_type == "typedef"'
