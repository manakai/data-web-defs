use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;

my $Data = {};

sub read_text ($$) {
  my ($file_name, $file_key) = @_;
  my $f = file (__FILE__)->dir->parent->file ('src', $file_name);
  my $key;
  for (($f->slurp)) {
    if (/^(\S+)$/) {
      $key = $1;
      $Data->{$file_key}->{$key} ||= {};
    } elsif (/^  ([^=]+)=(.*)$/) {
      $Data->{$file_key}->{$key}->{$1} = $2;
    } elsif (/\S/) {
      die "$file_name: Broken data |$_|";
    }
  }
} # read_text

read_text 'css-at-rules.txt' => 'at_rules';

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
