use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules', '*', 'lib')->stringify;
use JSON::PS;

my $Data = {};

sub define ($) {
  my $key = shift;
  $Data->{encodings}->{$key}->{key} = $key;
  $Data->{encodings}->{$key}->{name} //= $key;
  $Data->{encodings}->{$key}->{compat_name} //= $key;
  $Data->{encodings}->{$key}->{suikawiki} //= $key;
} # define

{
  my $path = path (__FILE__)->parent->parent->child ('local/encodings.json');
  my $json = json_bytes2perl $path->slurp;
  for (@$json) {
    for (@{$_->{encodings}}) {
      my $name = $_->{name};
      my $key = $name;
      $key =~ tr/A-Z/a-z/;
      define $key;
      $Data->{encodings}->{$key}->{name} = $name;
      $Data->{encodings}->{$key}->{compat_name} = $name;
      $Data->{encodings}->{$key}->{url} = "https://encoding.spec.whatwg.org/#" . $key;
      $Data->{encodings}->{$key}->{suikawiki} = $name;
      $Data->{encodings}->{$key}->{web} = 1;
      for (@{$_->{labels}}) {
        $Data->{supported_labels}->{$_} = $key;
        $Data->{encodings}->{$key}->{labels}->{$_}->{url} = "https://encoding.spec.whatwg.org/#" . $key;
      }
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('data/encoding-indexes.json');
  my $json = json_bytes2perl $path->slurp;
  for my $name (keys %$json) {
    my $def = $json->{$name};
    if (@$def == 128) {
      $Data->{encodings}->{$name}->{single_byte} = 1;
      define $name;
      $Data->{supported_labels}->{$name} = $name;
      $Data->{encodings}->{$name}->{labels}->{$name} ||= {};
    } elsif (@$def == 256) {
      if ($name =~ /^tcvn-((?:en|de)code)$/) {
        my $key = "x-viet-tcvn";
        $Data->{encodings}->{$key}->{"single_byte_$1"} = $name;
        define $key;
        $Data->{supported_labels}->{$key} = $key;
        $Data->{encodings}->{$key}->{labels}->{$key} ||= {};
      } else {
        $Data->{encodings}->{$name}->{single_byte_encode} = $name;
        $Data->{encodings}->{$name}->{single_byte_decode} = $name;
        define $name;
        $Data->{supported_labels}->{$name} = $name;
        $Data->{encodings}->{$name}->{labels}->{$name} ||= {};
      }
    }
  }
}

define "tscii";
define "tab";

for (qw(
    armscii-8 georgian-academy georgian-ps tscii tab viscii x-viet-vni
    x-viet-vps x-viet-tcvn
    x-mns4330
)) {
  $Data->{encodings}->{$_}->{web} = 1;
}
for (qw(
    big5 euc-jp euc-kr gb18030 ibm866 iso-8859-7 shift_jis utf-8
    windows-874 windows-1250 windows-1251 windows-1252 windows-1253
    windows-1254 windows-1255 windows-1256 windows-1257
    ibm437 ibm737 ibm775 ibm850 ibm852 ibm855 ibm857 ibm862 ibm865
)) {
  $Data->{encodings}->{$_}->{zip} = 1;
}

for (
  ## Encoding labels for additional encodings (other than encoding
  ## names), seen in Web pages and implementations.
  ["georgian-ps", "geostd8"],
  ["georgian-ps", "geo8-gov"],
  ["x-viet-tcvn", "x-viet-tcvn5712"],
  ["x-viet-tcvn", "tcvn"],
  ["x-viet-tcvn", "tcvn-5712"],
  ["x-viet-tcvn", "tcvn-5712:1993"],
  ["x-viet-vps", "x-vps"],
  ["x-viet-vps", "vps"],
  ["viscii", "csviscii"],
  ["ibm437", "437"],
  ["ibm437", "cp437"],
  ["ibm437", "cspc8codepage437"],
  ["ibm437", "ibm-437"],
  ["ibm437", "ibm-437_p100-1995"],
  ["ibm437", "windows-437"],
  ["ibm737", "cp737"],
  ["ibm775", "775"],
  ["ibm775", "cp775"],
  ["ibm775", "cspc775baltic"],
  ["ibm775", "ibm-775"],
  ["ibm775", "ibm-775_p100-1996"],
  ["ibm775", "windows-775"],
  ["ibm850", "850"],
  ["ibm850", "cp850"],
  ["ibm850", "cspc850multilingual"],
  ["ibm850", "ibm-850"],
  ["ibm850", "ibm-850_p100-1995"],
  ["ibm850", "windows-850"],
  ["ibm852", "852"],
  ["ibm852", "cp852"],
  ["ibm852", "cspcp852"],
  ["ibm852", "ibm-852"],
  ["ibm852", "ibm-852_p100-1995"],
  ["ibm852", "windows-852"],
  ["ibm855", "855"],
  ["ibm855", "cp855"],
  ["ibm855", "csibm855"],
  ["ibm855", "cspcp855"],
  ["ibm855", "ibm-855"],
  ["ibm855", "ibm-855_p100-1995"],
  ["ibm855", "windows-855"],
  ["ibm857", "857"],
  ["ibm857", "cp857"],
  ["ibm857", "csibm857"],
  ["ibm857", "ibm-857"],
  ["ibm857", "ibm-857_p100-1995"],
  ["ibm857", "windows-857"],
  ["ibm862", "862"],
  ["ibm862", "cp862"],
  ["ibm862", "cspc862latinhebrew"],
  ["ibm862", "dos-862"],
  ["ibm862", "ibm-862"],
  ["ibm862", "ibm-862_p100-1995"],
  ["ibm862", "windows-862"],
  ["ibm865", "865"],
  ["ibm865", "cp865"],
  ["ibm865", "csibm865"],
  ["ibm865", "ibm-865"],
  ["ibm865", "ibm-865_p100-1995"],
  
  ## This is a willful violation to the Encoding Standard, which
  ## defines a complete set of encoding labels.  |user-defined| is
  ## used by different Web sites in different countries.
  ["x-user-defined", "user-defined"],
) {
  my ($name, $label) = (lc $_->[0], lc $_->[1]);
  $Data->{supported_labels}->{$label} = $name;
  $Data->{encodings}->{$name}->{labels}->{$label} ||= {};
}

sub _key ($) {
  return $Data->{supported_labels}->{lc $_[0]} || lc $_[0];
} # _key

{
  my $path = path (__FILE__)->parent->parent->child
      ('src', 'locale-default-encodings.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^(\S+)\s+(\S+)$/) {
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
## Old HTML5 specification names ISO-2022-JP as one of bad encoding,
## nevertheless usage of it is not prohibited and it is actually one
## of widely deployed encodings in Japan.

$Data->{encodings}->{_key 'replacement'}->{html_conformance} = 'bad';
#$Data->{encodings}->{_key 'replacement'}->{html_conformance} = 'broken';
## When this script is written first, the replacement encoding has no
## label of its own and use of that encoding is a side effect of usage
## of deprecated encodings.  Then a "replacement" label is added to
## the replacement encoding such that an author can intentionally
## deploy that encoding if desired.

print perl2json_bytes_for_record $Data;

## License: Public Domain.
