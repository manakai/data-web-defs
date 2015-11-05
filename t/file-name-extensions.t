#!/bin/sh
echo "1..35"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/file-name-extensions.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.txt.mime_type == "text/plain"';
test 2 '.htm.mime_type == "text/html"';
test 3 '.html.mime_type == "text/html"';
test 4 '.xml.mime_type == "text/xml"';
test 5 '.css.mime_type == "text/css"';
test 6 '.js.mime_type == "text/javascript"';
test 7 '.png.mime_type == "image/png"';
test 8 '.ico.mime_type == "image/vnd.microsoft.icon"';
test 9 '.doc.mime_type == "application/msword"';
test 10 '.dtd.mime_type == "application/xml-dtd"';
test 11 '.svg.mime_type == "image/svg+xml"';
test 12 '.bmp.mime_type == "image/bmp"';
test 13 '.vtt.mime_type == "text/vtt"';
test 14 '.xsl.mime_type == "application/xslt+xml"';
test 15 '.mp3.mime_type == "audio/mpeg"';
test 16 '.mp4.mime_type == "video/mp4"';
test 17 '.ogg.mime_type == "application/ogg"';
test 18 '.xht.mime_type == "application/xhtml+xml"';
test 19 '.xhtml.mime_type == "application/xhtml+xml"';
test 20 '.json.mime_type == "application/json"';
test 21 '.jpg.mime_type == "image/jpeg"';
test 22 '.jpeg.mime_type == "image/jpeg"';
test 23 '.gif.mime_type == "image/gif"';
test 24 '.csv.mime_type == "text/csv"';
test 25 '.manifest.mime_type == "text/cache-manifest"';
test 26 '.pl.mime_type == "text/perl"';
test 27 '.pm.mime_type == "text/perl"';
test 28 '.pdf.mime_type == "application/pdf"';
test 29 '.rdf.mime_type == "application/rdf+xml"';
test 30 '.rss.mime_type == "application/rss+xml"';
test 31 '.atom.mime_type == "application/atom+xml"';
test 32 '.xbm.mime_type == "image/xbm"';
test 33 '.zip.mime_type == "application/zip"';
test 34 '.mpg.mime_type == "video/mpeg"';
test 35 '.mpeg.mime_type == "video/mpeg"';
