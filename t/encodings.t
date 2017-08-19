#!/bin/sh
echo "1..19"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/encodings.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.encodings.shift_jis.key == "shift_jis"'
test 2 '.encodings.shift_jis.name == "Shift_JIS"'
test 3 '.encodings.shift_jis.compat_name == "Shift_JIS"'
test 4 '.encodings.shift_jis.html_decl_mapped == "shift_jis"'
test 5 '.encodings.shift_jis.output == "shift_jis"'
test 6 '.encodings["windows-1252"].compat_name == "windows-1252"'
test 7 '.encodings["utf-8"].labels["utf8"] | not | not'
test 8 '.encodings["utf-8"].labels["utf-8"].conforming | not | not'
test 9 '.encodings["utf-8"].conforming | not | not'
test 10 '.encodings["utf-8"].html_conformance == "good"'
test 11 '.html_decl_map["utf-16be"] == "utf-8"'
test 12 '.locale_default.ja == "shift_jis"'
test 13 '.supported_labels["windows-31j"] == "shift_jis"'
test 14 '.encodings["utf-16be"].output == "utf-8"'
test 15 '.encodings["utf-16be"].html_decl_mapped == "utf-8"'
test 16 '.encodings["utf-16be"].single_byte | not'
test 17 '.encodings["windows-1252"].single_byte | not | not'
test 18 '.encodings.replacement.name == "replacement"'
test 19 '.supported_labels.replacement == "replacement"'

## License: Public Domain.