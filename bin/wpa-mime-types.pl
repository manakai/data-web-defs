use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;
my $src_path = $root_path->child ('intermediate/wpa-mime-types.json');
my $Data = json_bytes2perl $src_path->slurp;

for my $type (keys %$Data) {
  my $data = $Data->{$type};
  $data->{url} = 'https://www.iana.org/assignments/media-types/'.$type;
  if (not $data->{required_params} or
      not $data->{optional_params}) {
    unless ($data->{parse_error}) {
      #warn $type;
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
