use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $RootPath = path (__FILE__)->parent->parent;

my $path = $RootPath->child ('local/indexes.json');
my $json = json_bytes2perl $path->slurp;
$json->{'x-user-defined'} = [map { $_ + 0xF780 - 0x80 } 0x80..0xFF];
$json->{'iso-8859-8-i'} = $json->{'iso-8859-8'};

{
  my $path = $RootPath->child ('local/web-extra-index.json');
  my $list = json_bytes2perl $path->slurp;
  for (keys %$list) {
    $json->{$_} = $list->{$_};
  }
  delete $json->{"x-mac-ce"};
}

print perl2json_bytes_for_record $json;

## License: Public Domain.
