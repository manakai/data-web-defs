use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Web::DOM::Document;
use JSON::PS;

my $Data = {};

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
}

my $input_path = path (__FILE__)->parent->parent->child ('local/webidl.html');
my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
$doc->inner_html ($input_path->slurp_utf8);

{
  my $node = $doc->get_element_by_id ('error-names');
  my $tw = $doc->create_tree_walker ($doc);
  $tw->current_node ($node);
  while (not ($node->node_type == 1 and $node->local_name eq 'table')) {
    $node = $tw->next_node;
  }

  for my $row ($node->tbodies->[0]->rows->to_list) {
    my $name = $row->cells->[0]->query_selector ('code')->text_content;
    my $desc = _n $row->cells->[1]->text_content;
    $desc =~ s/\s*\[\w+\]\s*$//;
    my $code = $row->cells->[2]->query_selector ('code');
    if (defined $code) {
      $code = $code->text_content;
    }
    my $code_value;
    if ($row->cells->[2]->text_content =~ /\((\d+)\)/) {
      $code_value = $1;
    }
    #$Data->{error_names}->{$name}->{desc} = $desc;
    $Data->{error_names}->{$name}->{const_name} = $code;
    $Data->{error_names}->{$name}->{const_value} = $code_value;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
