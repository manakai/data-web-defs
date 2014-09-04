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
            $d->{$m} = $f->text_content;
          }
        }
        push @{$data->{records} ||= []}, $d;
      } elsif ($l eq 'xref') {
        $data->{$l} = {type => $e->get_attribute ('type'),
                       data => $e->get_attribute ('data'),
                       label => $e->text_content};
      } else {
        $data->{$l} = $e->text_content;
      }
    }
  } else {
    $Data->{$ln} = $el->text_content;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
