use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;

my $Data = [];

my $path = $root_path->child ('local/psl-test.txt');
for (split /\x0D?\x0A/, $path->slurp_utf8) {
  if (m{^\s*checkPublicSuffix\s*\(("[^"]*"|'[^']*'|null)\s*,\s*("[^"]*"|'[^']*'|null)\s*\);\s*$}) {
    my $input = $1;
    my $output = $2;
    if ($input eq 'null') {
      $input = undef;
    } else {
      $input =~ s/^["']//;
      $input =~ s/["']$//;
    }
    if ($output eq 'null') {
      $output = undef;
    } else {
      $output =~ s/^["']//;
      $output =~ s/["']$//;
    }
    push @$Data, [$input, $output];
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
