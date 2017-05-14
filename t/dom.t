#!/bin/sh
echo "1..4"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/dom.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.idl_defs.DOMTokenList[1].members.toggle[0] == "operation"'
test 2 '.idl_defs.DOMTimeStamp[0] == "typedef"'
test 3 '.idl_defs.HTMLElement[1].members.focus[1].spec == "HTML"'
test 4 '.primary_global == "Window"'
