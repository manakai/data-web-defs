#!/bin/sh
echo "1..6"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/tls.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.cipher_suites["70"].name == "TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA"'
test 2 '.cipher_suites["71"].reserved | not | not'
test 3 '.cipher_suites["49229"].h2_blacklist | not | not'
test 4 '.cipher_suites["99"].obsolete | not | not'
test 5 '.cipher_suites["0"].nss == "TLS_NULL_WITH_NULL_NULL"'
test 6 '.cipher_suites["136"].gnutls == "TLS_DHE_RSA_CAMELLIA_256_CBC_SHA1"'
