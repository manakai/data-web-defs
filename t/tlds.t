#!/bin/sh
echo "1..10"
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
test 7 '.tlds[""] | not'
test 8 '.tlds.bd.subdomains["*"] | not | not'
test 9 '.tlds.bd.subdomains["%2A"] | not'
test 10 '.tlds.bg.subdomains["0"] | not | not'