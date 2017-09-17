#!/bin/sh
echo "1..5"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/aria.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.roles.alert.attrs["aria-expanded"] | not | not'
test 2 '.attrs["aria-selected"].is_state | not | not'
test 3 '.attrs["aria-details"].value_type == "idref"'
test 4 '.roles.none.subclass_of.roletype | not | not'
test 5 '.roles.figure.preferred.name == "figure"'
