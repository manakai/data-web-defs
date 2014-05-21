use strict;
use warnings;
use Encode;
use JSON::PS;

my $Data = {};

my @data;
while (<>) {
  chomp;
  push @data, [split /\t/, decode 'utf-8', $_];
}

my $header = shift @data;
for my $data (@data) {
  my $item = {};
  for (0..$#$header) {
    $item->{$header->[$_]} = $data->[$_];
  }
  $Data->{$item->{'Common Code'}} = $item;
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
