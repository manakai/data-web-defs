#!/bin/sh
echo "1..2"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/errors.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.dom_errors.InUseAttributeError.const_value == 9'
test 2 '.dom_errors.HierarchyRequestError.name == "HierarchyRequestError"'
