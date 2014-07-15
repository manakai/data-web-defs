#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/html-syntax.json | $jq "$2" | sh && echo "ok $1") || echo "not ok $1"
}

test 1 '.adjusted_ns_attr_names["xlink:href"][1][0] == "xlink"'
test 2 '.adjusted_svg_element_names.clippath == "clipPath"'
test 3 '.tokenizer.states["data state"] | not | not'