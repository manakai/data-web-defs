use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'dom-perl-methods.txt');
  for (($f->slurp)) {
    my @data = split /\s+/, $_;
    $Data->{method_name_map}->{$data[0]} = $data[1];
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
