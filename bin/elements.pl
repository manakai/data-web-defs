use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'element-interfaces.txt');
  my $ns = '';
  my $ln = '*';
  for (($f->slurp)) {
    if (/^\@ns (\S+)$/) {
      $ns = $1;
    } elsif (/^(\S+)\s(\S+)$/) {
      $ln = $1;
      $Data->{$ns}->{$ln}->{interface} = $2;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
