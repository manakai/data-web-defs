use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DomainName::Canonicalize;
use Web::DomainName::Punycode;

my $root_path = path (__FILE__)->parent->parent;
my $Data = {};

{
  my $path = $root_path->child ('local/iana-tlds.txt');
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
  my $path = $root_path->child ('src/tld-additional.txt');
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
  my $path = $root_path->child ('local/mozilla-idn-whitelist.txt');
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

{
  my $path = $root_path->child ('local/psl.txt');
  my $type = 'ICANN';
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (m{^// ===BEGIN PRIVATE DOMAINS===$}) {
      $type = 'PRIVATE';
    } elsif (m{^//}) {
      #
    } elsif (/^(\S+)\s*$/) {
      my $suffix = $1;
      my $exception = $suffix =~ s/^!//;
      $suffix =~ s/^\.//;
      $suffix =~ s/\.$//;
      my @label = map { canonicalize_domain_name $_ } split /\./, $suffix;
      my $data = $Data->{tlds}->{pop @label} ||= {};
      while (@label) {
        my $label = pop @label;
        $data = $data->{subdomains}->{$label} ||= {};
      }
      $data->{public_suffix} = $exception ? 0 : $type;
    } elsif (/\S/) {
      die "Bad line |$_|";
    }
  }
}

{
  my @d = ($Data->{tlds});
  while (@d) {
    my $d = shift @d;
    next unless defined $d;
    for my $a_label (keys %$d) {
      if ($a_label =~ /^xn--/) {
        my $u_label = decode_punycode substr $a_label, 4;
        if (defined $u_label and not $a_label eq $u_label) {
          $d->{$a_label}->{u} = $u_label;
        }
      }
      push @d, $d->{$a_label}->{subdomains};
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
