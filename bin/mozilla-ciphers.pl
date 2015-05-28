use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Web::DOM::Document;
use JSON::PS;

my $Data = {ciphers => []};
my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
local $/ = undef;
$doc->inner_html (scalar <>);

sub n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # n

my $table = $doc->query_selector ('table:-manakai-contains("IANA"):-manakai-contains("TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256")');
my @row = $table->rows->to_list;
my $header = shift @row;
my @header = map { n $_->text_content } $header->cells->to_list;
for (@row) {
  my @cell = map { n $_->text_content } $_->cells->to_list;
  my $row = {};
  for (0..$#cell) {
    $row->{$header[$_]} = $cell[$_];
  }
  push @{$Data->{ciphers}}, $row;
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
