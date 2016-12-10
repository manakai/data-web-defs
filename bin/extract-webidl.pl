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

for my $node (
  $doc->get_element_by_id ('error-names'),
) {
  my $tw = $doc->create_tree_walker ($doc);
  $tw->current_node ($node);
  while (not ($node->node_type == 1 and $node->local_name eq 'table')) {
    $node = $tw->next_node;
  }

  for my $row ($node->tbodies->[0]->rows->to_list) {
    my $name = $row->cells->[0]->query_selector ('code')->text_content;

    my $desc = _n $row->cells->[1]->text_content;
    $desc =~ s/\s*\[\w+\]\s*$//;
    #$Data->{error_names}->{$name}->{desc} = $desc;

    my $code_cell = $row->cells->[2];
    if (defined $code_cell) {
      my $code = $code_cell->query_selector ('code');
      $code = $code->text_content if defined $code;
      my $code_value;
      if ($code_cell->text_content =~ /\((\d+)\)/) {
        $code_value = $1;
      }
      $Data->{error_names}->{$name}->{const_name} = $code;
      $Data->{error_names}->{$name}->{const_value} = $code_value;
    }
  }
}

for my $node (
  $doc->get_element_by_id ('legacy-error-names'),
) {
  my $tw = $doc->create_tree_walker ($doc);
  $tw->current_node ($node);
  while (not ($node->node_type == 1 and $node->local_name eq 'table')) {
    $node = $tw->next_node;
  }

  for my $row ($node->tbodies->[0]->rows->to_list) {
    my $value = $row->cells->[0]->text_content;
    my $name;
    if ($value =~ /^\s*"(\S+)"\s*(\S+)\s*\(([0-9]+)\)\s*$/) {
      $name = $1;
      $Data->{error_names}->{$name}->{const_name} = $2;
      $Data->{error_names}->{$name}->{const_value} = 0+$3;
    } else {
      die "Bad value |$value|";
    }

    my $desc = $row->cells->[1]->text_content;
    if ($desc =~ /^\s*Use\s+(\S+)\.\s*$/) {
      $Data->{error_names}->{$name}->{preferred} = $1;
    } else {
      #warn $desc;
    }
    $Data->{error_names}->{$name}->{deprecated} = 1; # discouraged
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
