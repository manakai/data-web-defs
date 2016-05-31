#!/bin/sh
echo "1..6"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/tlds.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.tlds.com.iana | not | not'
test 2 '.tlds.jp.iana | not | not'
test 3 '.tlds.arpa.iana | not | not'
test 4 '.tlds.jp.subdomains.co.public_suffix == "ICANN"'
test 5 '.tlds.io.subdomains.github.public_suffix == "PRIVATE"'
test 6 '.tlds["xn--fiqs8s"].u == "中国"'