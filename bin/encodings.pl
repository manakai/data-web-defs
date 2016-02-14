use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules', '*', 'lib')->stringify;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child ('local/encodings.json');
  my $json = json_bytes2perl $path->slurp;
  for (@$json) {
    for (@{$_->{encodings}}) {
      my $name = $_->{name};
      my $key = $name;
      $key =~ tr/A-Z/a-z/;
      $Data->{encodings}->{$key}->{key} = $key;
      $Data->{encodings}->{$key}->{name} = $name;
      $Data->{encodings}->{$key}->{compat_name} = $name;
      for (@{$_->{labels}}) {
        $Data->{supported_labels}->{$_} = $key;
        $Data->{encodings}->{$key}->{labels}->{$_} = 1;
      }
    }
  }
}

sub _key ($) {
  return $Data->{supported_labels}->{lc $_[0]} || lc $_[0];
} # _key

{
  my $path = path (__FILE__)->parent->parent->child
      ('src', 'locale-default-encodings.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^(\S+)\s+(\S+)$/) {
      my $label = lc $2;
      $Data->{locale_default}->{lc $1} = _key $label;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

$Data->{html_decl_map}->{_key 'utf-16be'} = _key 'utf-8';
$Data->{html_decl_map}->{_key 'utf-16le'} = _key 'utf-8';
$Data->{html_decl_map}->{_key 'x-user-defined'} = _key 'windows-1252';
for (keys %{$Data->{html_decl_map}}) {
  my $key = $_;
  $key =~ tr/A-Z/a-z/;
  $Data->{encodings}->{$key}->{html_decl_mapped} = $Data->{html_decl_map}->{$_};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
