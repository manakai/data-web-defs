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
        $Data->{encodings}->{$key}->{labels}->{$_} ||= {};
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

for my $key (keys %{$Data->{encodings}}) {
  $Data->{encodings}->{$key}->{output} = $key;
}
$Data->{encodings}->{_key 'replacement'}->{output} = _key 'utf-8';
$Data->{encodings}->{_key 'utf-16be'}->{output} = _key 'utf-8';
$Data->{encodings}->{_key 'utf-16le'}->{output} = _key 'utf-8';

$Data->{encodings}->{_key 'utf-16be'}->{utf16} = 1;
$Data->{encodings}->{_key 'utf-16le'}->{utf16} = 1;
for my $key (keys %{$Data->{encodings}}) {
  $Data->{encodings}->{$key}->{ascii_compat}
      = not $Data->{encodings}->{$key}->{utf16};
}

for my $key (keys %{$Data->{encodings}}) {
  $Data->{encodings}->{$key}->{html_decl_mapped}
      = $Data->{encodings}->{$key}->{utf16} ? _key 'utf-8' : _key $key;
}
$Data->{encodings}->{_key 'x-user-defined'}->{html_decl_mapped}
    = _key 'windows-1252';

for my $key (keys %{$Data->{encodings}}) {
  unless ($Data->{encodings}->{$key}->{html_decl_mapped} eq $key) {
    $Data->{html_decl_map}->{$key}
        = $Data->{encodings}->{$key}->{html_decl_mapped};
  }
}

$Data->{encodings}->{_key 'utf-8'}->{conforming} = 1;
$Data->{encodings}->{_key 'utf-8'}->{labels}->{'utf-8'}->{conforming} = 1;

for my $key (keys %{$Data->{encodings}}) {
  $Data->{encodings}->{$key}->{html_conformance} = 'avoid';
}
$Data->{encodings}->{_key 'utf-8'}->{html_conformance} = 'good';
$Data->{encodings}->{_key 'iso-2022-jp'}->{html_conformance} = 'bad';
$Data->{encodings}->{_key 'replacement'}->{html_conformance} = 'broken';

print perl2json_bytes_for_record $Data;

## License: Public Domain.
