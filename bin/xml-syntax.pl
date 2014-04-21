use strict;
use warnings;
use JSON::PS;

my $Data = {};

## Public identifiers for XHTML named character references DTD
## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-documents>
for (
  '-//W3C//DTD XHTML 1.0 Transitional//EN',
  '-//W3C//DTD XHTML 1.1//EN',
  '-//W3C//DTD XHTML 1.0 Strict//EN',
  '-//W3C//DTD XHTML 1.0 Frameset//EN',
  '-//W3C//DTD XHTML Basic 1.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN',
  '-//W3C//DTD MathML 2.0//EN',
  '-//WAPFORUM//DTD XHTML Mobile 1.0//EN',
) {
  $Data->{charrefs_pubids}->{$_} = 1;
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
