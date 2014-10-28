#!/bin/sh
echo "1..7"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/headers.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.codings.gzip.transfer.iana == 1'
test 2 '.codings.gzip.content.iana == 1'
test 3 '.range_units.none.reserved == 1'
test 4 '.auth_schemes.basic.iana == 1'
test 5 '.auth_schemes.oauth.credentials.auth_params.oauth_version.spec | not | not'
test 6 '.preferences["odata.callback"].params.url.optionality == "MUST"'
test 7 '.preferences["respond-async"].iana | not | not'
