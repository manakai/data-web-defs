#!/bin/sh
echo "1..5"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/elements.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.elements["http://www.w3.org/1999/xhtml"].a.id == "the-a-element"'
test 2 '.elements["http://www.w3.org/1999/xhtml"].a.attrs[""].rel.id == "attr-hyperlink-rel"'
test 3 '.elements["http://www.w3.org/1999/xhtml"].img.content_model == "empty"'
test 4 '.elements["http://www.w3.org/1999/xhtml"].br.content_model == "empty"'

test 5 '.categories["category-listed"].elements["http://www.w3.org/1999/xhtml"].button | not | not'
