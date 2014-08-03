use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;

my $Data = {};

sub parse ($) {
  my $path = shift;
  my $doc = Web::DOM::Document->new;
  $doc->manakai_is_html (1);
  $doc->inner_html ($path->slurp_utf8);
  return [map { $_->inner_html } @{$doc->query_selector_all ('pre.idl')}];
} # parse

my $local_path = path (__FILE__)->parent->parent->child ('local');

$Data->{DOM} = parse $local_path->child ('dom.html');
$Data->{DOMPARSING} = parse $local_path->child ('domparsing.html');
$Data->{XHR} = parse $local_path->child ('xhr.html');

print perl2json_bytes_for_record $Data;

## License: Public Domain.
