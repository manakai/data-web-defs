#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/encodings.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.encodings.shift_jis.compat_name == "Shift_JIS"'
test 2 '.encodings["windows-1252"].compat_name == "windows-1252"'
test 3 '.encodings["utf-8"].labels["utf8"] | not | not'
