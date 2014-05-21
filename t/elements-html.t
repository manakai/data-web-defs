#!/bin/sh
echo "1..3"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/elements.json | $jq "$2" | sh && echo "ok $1") || echo "not ok $1"
}

test 1 '.elements["http://www.w3.org/1999/xhtml"].a.id == "the-a-element"'
test 2 '.elements["http://www.w3.org/1999/xhtml"].a.attrs[""].rel.id == "attr-hyperlink-rel"'

test 3 '.categories["category-form-attr"].elements["http://www.w3.org/1999/xhtml"].button | not | not'
