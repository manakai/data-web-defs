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
      $Data->{encodings}->{$name}->{name} = $name;
      for (@{$_->{labels}}) {
        $Data->{supported_labels}->{$_} = $name;
        $Data->{encodings}->{$name}->{labels}->{$_} = 1;
      }
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/dom-extracted.json');
  my $json = json_bytes2perl $path->slurp;
  for (keys %{$json->{encoding_compat_names}}) {
    $Data->{encodings}->{$_}->{compat_name} = $json->{encoding_compat_names}->{$_};
  }
}

for my $name (keys %{$Data->{encodings}}) {
  $Data->{encodings}->{$name}->{compat_name} //= $name;
}

sub _name ($) {
  return $Data->{supported_labels}->{lc $_[0]} || lc $_[0];
} # _name

{
  my $path = path (__FILE__)->parent->parent->child
      ('src', 'locale-default-encodings.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^(\S+)\s+(\S+)$/) {
      my $label = lc $2;
      $Data->{locale_default}->{lc $1} = _name $label;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

$Data->{html_decl_map}->{_name 'utf-16be'} = _name 'utf-8';
$Data->{html_decl_map}->{_name 'utf-16le'} = _name 'utf-8';
$Data->{html_decl_map}->{_name 'x-user-defined'} = _name 'windows-1252';
for (keys %{$Data->{html_decl_map}}) {
  $Data->{encodings}->{$_}->{html_decl_mapped} = $Data->{html_decl_map}->{$_};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
