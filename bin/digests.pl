use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

my $root_path = path (__FILE__)->parent->parent;

{
  my $json = json_bytes2perl $root_path->child ('local/iana/http-digests.json')->slurp;
  for my $record (@{$json->{registries}->{'http-dig-alg-1'}->{records}}) {
    my $name = $record->{name};
    my $key = lc $name;
    $Data->{algorithms}->{$key}->{HTTP}->{name} = $name;
    $Data->{algorithms}->{$key}->{HTTP}->{iana} = 1;
    $Data->{algorithms}->{$key}->{HTTP}->{'Digest'} = 1;
    $Data->{algorithms}->{$key}->{HTTP}->{'Want-Digest'} = 1;
  }
  my $key;
  for (split /\x0D?\x0A/, $root_path->child ('src/http-digests.txt')->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      my $name = $1;
      $key = lc $name;
      $Data->{algorithms}->{$key}->{HTTP}->{name} = $name;
      $Data->{algorithms}->{$key}->{HTTP}->{'Digest'} = 1;
      $Data->{algorithms}->{$key}->{HTTP}->{'Want-Digest'} = 1;
      next;
    } elsif (/\S/) {
      die "Coding not defined at first line" unless defined $key;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Data->{algorithms}->{$key}->{HTTP}->{spec} = "RFC$1";
        $Data->{algorithms}->{$key}->{HTTP}->{id} = $2;
      } else {
        $Data->{algorithms}->{$key}->{HTTP}->{url} = $url;
      }
    } elsif (/^only in Want-Digest$/) {
      delete $Data->{algorithms}->{$key}->{HTTP}->{'Digest'};
    } elsif (/^(obsolete)$/) {
      $Data->{algorithms}->{$key}->{HTTP}->{$1} = 1;
    } elsif (/^(digits|base16|base64)$/) {
      $Data->{algorithms}->{$key}->{HTTP}->{value_syntax} = $1;
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
