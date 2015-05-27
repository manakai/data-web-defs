#!/bin/sh
echo "1..15"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/http-frames.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.ws.status_codes["1001"].iana | not | not'
test 2 '.ws.status_codes["1001"].close | not | not'
test 3 '.ws.status_codes["1005"].close | not'
test 4 '.ws.extensions["x-webkit-deflate-frame"].obsolete | not | not'
test 5 '.ws.protocols.sip.iana | not | not'

test 6 '.http2.error_codes["1"].iana | not | not'
test 7 '.http2.error_codes["3"].connection_error | not | not'
test 8 '.http2.error_codes["5"].stream_error | not | not'
test 9 '.http2.error_codes["5"].name == "STREAM_CLOSED"'
test 10 '.http2.settings["0"].reserved | not | not'
test 11 '.http2.settings["3"].name == "MAX_CONCURRENT_STREAMS"'
test 12 '.http2.settings["4"].initial_integer == 65535'
test 13 '.http2.settings["6"].initial_infinity | not | not'

test 14 '.hpack.static[1][0] == ":authority"'
test 15 '.hpack.static[5][1] == "/index.html"'
