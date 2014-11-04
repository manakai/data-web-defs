use strict;
use warnings;
use Path::Class;
use Encode;
use JSON::PS;

my $Data = {};

my $scheme;
open my $file, '<', 'src/url-schemes.txt' or die "$0: url-schemes.txt: $!";
while (<$file>) {
  if (/^\s*#/) {
    next;
  } elsif (/^(.*):\s*$/) {
    $scheme = $1;
    #$scheme =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
    $scheme =~ tr/A-Z/a-z/;
    #$scheme = decode 'utf-8', $scheme;
    $scheme =~ s/(%[0-9A-Fa-f]{2})/uc $1/ge;
    if ($Data->{$scheme}) {
      die "Duplicate URL scheme: |$scheme|\n";
    }
    $Data->{$scheme} = {};
  } elsif (/^\s+([\w-]+)\s*$/) {
    if ($1 eq 'application') {
      $Data->{$scheme}->{$1} = {};
    } else {
      $Data->{$scheme}->{$1} = 1;
    }
  } elsif (/^\s+([\w-]+)=(\S+)\s*$/) {
    if ($1 eq 'application') {
      $Data->{$scheme}->{$1}->{$2} = 1;
    } else {
      $Data->{$scheme}->{$1} = $2;
    }
  } elsif (/\S/) {
    die "Broken data: $_";
  }
}

for my $file_name (qw(local/sw-url-schemes.txt local/iana-url-schemes.txt)) {
  my $scheme;
  open my $file, '<', $file_name or die "$0: $file_name: $!";
  while (<$file>) {
    if (/^\s*#/) {
      next;
    } elsif (/^(.*):\s*$/) {
      $scheme = $1;
      $Data->{$scheme} ||= {};
    } elsif (/^\s+([\w-]+)\s*$/) {
      $Data->{$scheme}->{$1} = 1;
    } elsif (/^\s+([\w-]+)=(\S+)\s*$/) {
      $Data->{$scheme}->{$1} = $2;
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'url-schemes-iphone.txt');
  for (($f->slurp)) {
    if (/^([0-9A-Za-z._+-]+)$/) {
      my $scheme = lc $1;
      $Data->{$scheme}->{application}->{ios} = 1;
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}
{
  my $f = file (__FILE__)->dir->parent->file ('src', 'url-schemes-iphone-args.txt');
  for (($f->slurp)) {
    if (/^([0-9A-Za-z._+-]+)$/) {
      my $scheme = lc $1;
      $Data->{$scheme}->{application}->{ios} = 1;
      $Data->{$scheme}->{authority} ||= 'fake';
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}
{
  my $f = file (__FILE__)->dir->parent->file ('src', 'url-schemes-windowsphone.txt');
  for (($f->slurp)) {
    if (/^([0-9A-Za-z._+-]+)\s*$/) {
      my $scheme = lc $1;
      $Data->{$scheme}->{application}->{windowsphone} = 1;
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}

for my $scheme (keys %{$Data}) {
  $Data->{$scheme}->{'scheme-default-port'} ||= $Data->{$scheme}->{'default-port'}
      if defined $Data->{$scheme}->{'default-port'};
  if (defined $Data->{$scheme}->{'no-tls'}) {
    $Data->{$scheme}->{secure} = 1;
  }
} # $scheme

open my $json_file, '>', 'data/url-schemes.json' or die "$0: url-schemes.json: $!";
print $json_file perl2json_bytes_for_record $Data;
close $json_file;

## License: Public Domain.
