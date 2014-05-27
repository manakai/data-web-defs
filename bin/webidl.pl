use strict;
use warnings;
use JSON::PS;

my $Data = {};

for (
  [integer => '-?([1-9][0-9]*|0[Xx][0-9A-Fa-f]+|0[0-7]*)', 3],
  [float => '-?(([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([Ee][+-]?[0-9]+)?|[0-9]+[Ee][+-]?[0-9]+)', 4],
  [identifier => '_?[A-Za-z][0-9A-Z_a-z]*', 2],
  [string => '"[^"]*"', 2],
  [whitespace => '[\x09\x0A\x0D\x20]+', 2],
  [comment => '//.*|/\*(?:.|\x0A)*?\*/', 2],
  [other => '[^\x09\x0A\x0D\x200-9A-Za-z]', 1],
) {
  $Data->{tokens}->{$_->[0]}->{pattern} = $_->[1];
  $Data->{tokens}->{$_->[0]}->{priority} = $_->[2];
}

for (qw(
  callback interface partial dictionary exception enum typedef implements
  const null true false -Infinity Infinity NaN serializer getter stringifier
  static attribute inherit readonly setter creator deleter legacycaller
  iterator object optional ByteString Date DOMString RegExp any boolean
  byte double float long octet or sequence short unsigned void
  exception unrestricted

  class extends
  Promise

  { } ( ) [ ] ; = : ... - . < > ?
), ',') {
  if ($_ =~ /\A_?[A-Za-z][0-9A-Z_a-z]*\z/) {
    $Data->{keyword_tokens}->{$_} = {};
  } elsif ($_ =~ /\A[^\x09\x0A\x0D\x200-9A-Za-z]\z/) {
    $Data->{other_tokens}->{$_} = 1;
  } else {
    $Data->{tokens}->{$_}->{value} = $_;
    $Data->{tokens}->{$_}->{priority} = 10 + length $_;
  }
}

$Data->{keyword_tokens}->{$_}->{argument_name} = 1 for qw(
  attribute callback const creator deleter dictionary enum exception
  getter implements inherit interface legacycaller partial serializer
  setter static stringifier typedef unrestricted

  class extends
);

## "class" and "extends" are not in spec but extended at:
## <http://dom.spec.whatwg.org/#elements>,
## <https://www.w3.org/Bugs/Public/show_bug.cgi?id=23225>.

## "Promise" is not in spec but in use.

print perl2json_bytes_for_record $Data;

## License: Public Domain.
