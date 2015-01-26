use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $input_path = path (shift);
my $doc = new Web::DOM::Document;
my $parser = new Web::HTML::Parser;
$parser->parse_byte_string ('utf-8', $input_path->slurp => $doc);

my $Data = {rows => []};

for my $table_el ($doc->query_selector_all ('table.wikitable')->to_list) {
  my @row = $table_el->rows->to_list;
  next unless @row;
  my @header;
  for my $cell_el ((shift @row)->cells->to_list) {
    my $n = $cell_el->text_content;
    $n =~ s/\s+/ /g;
    $n =~ s/^ //;
    $n =~ s/ $//;
    push @header, $n;
  }

  for my $tr_el (@row) {
    my @row;
    for my $cell_el ($tr_el->cells->to_list) {
      push @row, $cell_el->inner_html;
    }
    my $data = {};
    for (0..$#header) {
      $data->{$header[$_]} = $row[$_];
    }
    push @{$Data->{rows}}, $data;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
