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
  my $index = $doc->get_element_by_id ('idl-index');
  if (defined $index) {
    my $next = $index->next_element_sibling;
    if (defined $next and $next->local_name eq 'pre') {
      $next->parent_node->remove_child ($next);
    }
  }
  return [map { $_->inner_html } @{$doc->query_selector_all ('pre.idl, pre > code.idl')}];
} # parse

my $local_path = path (__FILE__)->parent->parent->child ('local');

$Data->{DOM} = parse $local_path->child ('dom.html');
#$Data->{DOMPARSING} = parse $local_path->child ('domparsing.html');
$Data->{XHR} = parse $local_path->child ('xhr.html');
$Data->{FETCH} = parse $local_path->child ('fetch.html');
$Data->{FULLSCREEN} = parse $local_path->child ('fullscreen.html');
$Data->{NOTIFICATIONS} = parse $local_path->child ('notifications.html');
$Data->{ENCODING} = parse $local_path->child ('encoding.html');
$Data->{COMPAT} = parse $local_path->child ('compat.html');
$Data->{URL} = parse $local_path->child ('url.html');

print perl2json_bytes_for_record $Data;

## License: Public Domain.
