use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file
      ('src', 'locale-default-encodings.txt');
  for (($f->slurp)) {
    if (/^(\S+)\s+(\S+)$/) {
      $Data->{locale_default}->{lc $1} = lc $2;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
