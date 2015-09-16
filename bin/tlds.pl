use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child ('local/iana-tlds.txt');
  for (split /\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^([A-Za-z0-9-]+)$/) {
      my $domain = $1;
      $domain =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      $Data->{tlds}->{$domain}->{iana} = 1;
    } elsif (/\S/) {
      warn "Broken line: $_";
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('src/tld-additional.txt');
  for (split /\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^([A-Za-z0-9-]+)$/) {
      my $domain = $1;
      $domain =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      $Data->{tlds}->{$domain} ||= {};
    } elsif (/\S/) {
      warn "Broken line: $_";
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/mozilla-idn-whitelist.txt');
  for (split /\x0A/, $path->slurp) {
    if (/^([A-Za-z0-9-]+)$/) {
      my $domain = $1;
      $domain =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      $Data->{tlds}->{$domain}->{mozilla_idn_whitelist} = 1;
    } elsif (/\S/) {
      warn "Broken line: $_";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
