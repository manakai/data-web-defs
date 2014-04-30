use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

my $Required = {};
my $Array = {};

my $prop;
my $type;
for (split /\x0D?\x0A/, path (__FILE__)->parent->parent->child ('src/ogp.txt')->slurp_utf8) {
  if (/^\s*#/) {
    #
  } elsif (/^([^:\s]+:.+)$/) {
    $prop = $1;
    $Data->{props}->{$prop} ||= {};
    if (defined $type) {
      $Data->{props}->{$prop}->{target_type}->{$type} = 1;
    } else {
      $Data->{props}->{$prop}->{target_type}->{'*'} = 1;
    }
  } elsif (/^  = (.+)$/) {
    $Data->{props}->{$prop}->{aliases}->{$1} = 1;
    $Data->{props}->{$1}->{aliases}->{$prop} = 1;
  } elsif (/^\*\s*(\S+)$/) {
    $type = $1;
    $Data->{types}->{$type} ||= {};
  } elsif (/^  (.+)$/) {
    my $data = $1;
    if ({
      'URL' => 1,
      'MIME type' => 1,
      'e-mail address' => 1,
      'integer' => 1,
      'positive integer' => 1,
      'non-negative integer' => 1,
      'floating-point number' => 1,
      'OGP country' => 1,
      'OGP locale' => 1,
      'OGP unit' => 1,
      'OGP DateTime' => 1,
    }->{$data}) {
      $Data->{props}->{$prop}->{value_type} = $data;
    } elsif ($data eq 'array') {
      $Data->{props}->{$prop}->{array} = 1;
      $Array->{$prop} = 1;
    } elsif ($data eq 'required') {
      if ($prop =~ /^[^:]+:[^:]+$/) {
        if (defined $type) {
          $Data->{types}->{$type}->{requires}->{$prop} = 1;
        } else {
          $Data->{types}->{'*'}->{requires}->{$prop} = 1;
        }
      } else {
        $Required->{$prop} = 1;
      }
    } elsif ($data eq 'DEPRECATED') {
      $Data->{props}->{$prop}->{deprecated} = 1;
    } elsif ($data =~ s/^enum://) {
      $Data->{props}->{$prop}->{enums}->{$_} = 1 for split /\|/, $data, -1;
    } else {
      die "Unknown data: |$data|";
    }
  } elsif (/\S/) {
    die "Broken line: |$_|";
  }
}

for my $prop (keys %$Required) {
  my $prefix = $prop;
  $prefix =~ s/[^:]+$//;
  for my $p (keys %{$Data->{props}}) {
    if (not $p eq $prop and
        $p =~ /^\Q$prefix\E/) {
      $Data->{props}->{$p}->{requires}->{$prop} = 1;
    }
  }
}

for my $prop (keys %$Array) {
  for my $p (keys %{$Data->{props}}) {
    if ($p =~ /^\Q$prop\E:/) {
      $Data->{props}->{$p}->{array_item} = 1;
    }
  }
}

$Data->{units}->{$_} = 1
    for split /\s+/, path (__FILE__)->parent->parent->child ('src/ogp-units.txt')->slurp_utf8;

for my $prop (keys %{$Data->{props}}) {
  if ($prop =~ /^([^:]+)/) {
    $Data->{prefixes}->{$1} = 1;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
