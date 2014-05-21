use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;

my $Data = {};

my $path = path (__FILE__)->parent->parent->child ('local/schemaorg-wsa.html');
my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
$doc->inner_html ($path->slurp_utf8);

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/\A //;
  $s =~ s/ \z//;
  return $s;
} # _n

for my $table (@{$doc->query_selector_all ('table:-manakai-contains("Expected Values")')}) {
  my @row = @{$table->rows};
  my $header = shift @row;
  my @header;
  for (@{$header->cells}) {
    push @header, _n $_->text_content;
  }
  my $defs = {};
  for my $row (@row) {
    my $data = {};
    for (0..($row->cells->length-1)) {
      $data->{$header[$_]} = $row->cells->[$_];
    }
    if (defined $data->{Property} and defined $data->{'Expected Values'}) {
      $defs->{_n $data->{Property}->text_content}
          ||= $data->{'Expected Values'};
    }
  }
  for (keys %$defs) {
    my $prop = $_;
    $Data->{$prop}->{values}->{$_} = 1
        for map { _n $_->text_content } @{$defs->{$_}->query_selector_all ('li')};
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
