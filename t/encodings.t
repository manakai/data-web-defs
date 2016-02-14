#!/bin/sh
echo "1..8"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/encodings.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.encodings.shift_jis.key == "shift_jis"'
test 2 '.encodings.shift_jis.name == "Shift_JIS"'
test 3 '.encodings.shift_jis.compat_name == "Shift_JIS"'
test 4 '.encodings["windows-1252"].compat_name == "windows-1252"'
test 5 '.encodings["utf-8"].labels["utf8"] | not | not'
test 6 '.html_decl_map["utf-16be"] == "utf-8"'
test 7 '.locale_default.ja == "shift_jis"'
test 8 '.supported_labels["windows-31j"] == "shift_jis"'
