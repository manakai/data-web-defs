#!/bin/sh
echo "1..5"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/html-syntax.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.adjusted_ns_attr_names["xlink:href"][1][0] == "xlink"'
test 2 '.adjusted_svg_element_names.clippath == "clipPath"'
test 3 '.tokenizer.states["data state"] | not | not'
test 4 '.tree_patterns["special category"][2].name[0] == "annotation-xml"'
test 5 '.doctype_switch.quirks.regexp.public_id == "(?:(?:-/(?:/W3O//DTD W3 HTML STRICT 3\u005C.0//EN//|W3C/DTD HTML 4\u005C.0 TRANSITIONAL/EN)|HTML))"'
