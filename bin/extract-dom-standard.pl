use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Web::DOM::Document;
use Web::HTML::Parser;
use JSON::PS;

my $path = path (__FILE__)->parent->parent->child ('local/dom.html');
my $Data = {};

my $doc = new Web::DOM::Document;
my $parser = Web::HTML::Parser->new;
$parser->parse_byte_string ('utf-8', $path->slurp => $doc);

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
}

## ...

print perl2json_bytes_for_record $Data;

## License: Public Domain.
