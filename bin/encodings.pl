use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::PS qw(perl2json_bytes_for_record file2perl);

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'encodings.json');
  my $json = file2perl $f;
  for (@$json) {
    for (@{$_->{encodings}}) {
      my $name = $_->{name};
      for (@{$_->{labels}}) {
        $Data->{supported_labels}->{$_} = $name;
      }
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file
      ('src', 'locale-default-encodings.txt');
  for (($f->slurp)) {
    if (/^(\S+)\s+(\S+)$/) {
      my $label = lc $2;
      $Data->{locale_default}->{lc $1} = $Data->{supported_labels}->{$label} || $label;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
