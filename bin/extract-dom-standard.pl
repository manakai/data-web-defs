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

{
  my $th = $doc->query_selector ('th:-manakai-contains("Compatibility name")')
      or die "Encoding compatibility name table not found";
  my $parent = $th;
  while (1) {
    $parent = $parent->parent_node;
    if ($parent->local_name eq 'table') {
      last;
    }
  }
  for my $tr ($parent->rows->to_list) {
    my $cell1 = $tr->cells->[0] or next;
    my $cell2 = $tr->cells->[1] or next;
    my $name = ($cell1->query_selector ('a') or next)->text_content;
    my $compat_name = ($cell2->query_selector ('code') or next)->text_content;
    $Data->{encoding_compat_names}->{$name} = $compat_name;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
