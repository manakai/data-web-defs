use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $DataPath = path (__FILE__)->parent->parent->child ('intermediate/mime-type-provisional.json');
my $Data = json_bytes2perl $DataPath->slurp;

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/iana/mime-type-provisional.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{'provisional-standard-types'}->{records}}) {
    $Data->{mime_types}->{$record->{name}} ||= {};
  }
}

$DataPath->spew (perl2json_bytes_for_record $Data);

## License: Public Domain.
