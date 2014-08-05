#!/bin/sh
echo "1..4"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/html-syntax.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.adjusted_ns_attr_names["xlink:href"][1][0] == "xlink"'
test 2 '.adjusted_svg_element_names.clippath == "clipPath"'
test 3 '.tokenizer.states["data state"] | not | not'
test 4 '.doctype_switch.obsolete_permitted[1][0] == "-//W3C//DTD HTML 4.0//EN"'