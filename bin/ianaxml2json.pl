use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Encode;
use Web::DOM::Document;
use Web::XML::Parser;

my $Data = {};

my $doc = new Web::DOM::Document;
{
  my $parser = Web::XML::Parser->new;
  local $/ = undef;
  $parser->parse_char_string ((decode 'utf-8', <>) => $doc);
}

sub _tc ($) {
  my $el = shift;
  my $r = '';
  for my $node ($el->child_nodes->to_list) {
    if ($node->node_type == $node->ELEMENT_NODE) {
      if ($node->local_name eq 'xref') {
        my $value = $node->text_content;
        unless (length $value) {
          $value = uc $node->get_attribute ('data');
        }
        $r .= '[' . $value . ']';
      } else {
        $r .= $node->text_content;
      }
    } elsif ($node->node_type == $node->TEXT_NODE) {
      $r .= $node->data;
    }
  }
  return $r;
} # _tc

for my $el ($doc->document_element->children->to_list) {
  my $ln = $el->local_name;
  if ($ln eq 'registry') {
    my $data = $Data->{registries}->{$el->get_attribute ('id')} = {};
    for my $e ($el->children->to_list) {
      my $l = $e->local_name;
      if ($l eq 'record') {
        my $d = {};
        for my $f ($e->children->to_list) {
          my $m = $f->local_name;
          if ($m eq 'xref') {
            $d->{$m} = {type => $f->get_attribute ('type'),
                        data => $f->get_attribute ('data'),
                        label => $f->text_content};
          } else {
            $d->{$m} = _tc $f;
          }
        }
        push @{$data->{records} ||= []}, $d;
      } elsif ($l eq 'xref') {
        $data->{$l} = {type => $e->get_attribute ('type'),
                       data => $e->get_attribute ('data'),
                       label => $e->text_content};
      } else {
        $data->{$l} = _tc $e;
      }
    }
  } else {
    $Data->{$ln} = _tc $el;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
