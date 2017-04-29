use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $path = path (__FILE__)->parent->parent->child ('local/indexes.json');
my $json = json_bytes2perl $path->slurp;
$json->{'x-user-defined'} = [map { $_ + 0xF780 - 0x80 } 0x80..0xFF];
$json->{'iso-8859-8-i'} = $json->{'iso-8859-8'};
print perl2json_bytes_for_record $json;

## License: Public Domain.
