use strict;
use warnings;
use Path::Tiny;
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
  } elsif (/^\s+(tcp|udp|tls)$/) {
    $Data->{$scheme}->{transport}->{$1} = 1;
  } elsif (/^\s+http\(s\)$/) {
    $Data->{$scheme}->{http} = 1;
  } elsif (/^\s+([\w-]+)\s*$/) {
    if ($1 eq 'application') {
      $Data->{$scheme}->{$1} = {};
    } else {
      $Data->{$scheme}->{$1} = 1;
    }
  } elsif (/^\s+([\w-]+)=(\S+|MUST NOT)\s*$/) {
    if ($1 eq 'application') {
      $Data->{$scheme}->{$1}->{$2} = 1;
    } else {
      $Data->{$scheme}->{$1} = $2;
    }
  } elsif (/\S/) {
    die "Broken data: $_";
  }
}

for my $file_name (qw(local/sw-url-schemes.txt)) {
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
  my $path = path (__FILE__)->parent->parent->child ('local/iana/url-schemes.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{'uri-schemes-1'}->{records}}) {
    my $scheme = $record->{value};
    $scheme =~ tr/A-Z/a-z/;
    if ($scheme =~ s/\s*\(obsolete\)$//) {
      $Data->{$scheme}->{obsolete} = 1;
    }
    $Data->{$scheme}->{iana} = lc $record->{status};
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('src/url-schemes-iphone.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^([0-9A-Za-z._+-]+)$/) {
      my $scheme = lc $1;
      $Data->{$scheme}->{application}->{ios} = 1;
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}
{
  my $path = path (__FILE__)->parent->parent->child ('src/url-schemes-iphone-args.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
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
  my $path = path (__FILE__)->parent->parent->child ('src/url-schemes-ihasapp.json');
  my $json = json_bytes2perl $path->slurp;
  for (keys %$json) {
    my $scheme = lc $_;
    $Data->{$scheme}->{application}->{ios} = 1;
    $Data->{$scheme}->{itunes_ids}->{$_} = 1 for @{$json->{$_}};
  }
}
{
  my $path = path (__FILE__)->parent->parent->child ('src/url-schemes-windowsphone.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
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
  if ($Data->{$scheme}->{'x-callback-url'}) {
    $Data->{$scheme}->{query} ||= 'nv';
  }

  ## <https://url.spec.whatwg.org/#http-scheme>
  $Data->{$scheme}->{network} = 1 if $Data->{$scheme}->{http};
  $Data->{$scheme}->{fetch} = 1 if $Data->{$scheme}->{network};

  $Data->{$scheme}->{'web-core'} = 1 if $Data->{$scheme}->{fetch};
  $Data->{$scheme}->{browser} = 1 if $Data->{$scheme}->{'web-core'};
} # $scheme

## Port blocking [FETCH]
for (qw(
  1 7 9 11 13 15 17 19 20 21 22 23 25 37 42 43 53 77 79 87 95 101 102
  103 104 109 110 111 113 115 117 119 123 135 139 143 179 389 427 465 512
  513 514 515 526 530 531 532 540 548 556 563 587 601 636 993 995 2049
  3659 4045 6000 6665 6666 6667 6668 6669 6697
)) {
  $Data->{http}->{bad_ports}->{$_} = 1;
  $Data->{https}->{bad_ports}->{$_} = 1;
  $Data->{ftp}->{bad_ports}->{$_} = 1;
}
delete $Data->{ftp}->{bad_ports}->{20};
delete $Data->{ftp}->{bad_ports}->{21};

open my $json_file, '>', 'data/url-schemes.json' or die "$0: url-schemes.json: $!";
print $json_file perl2json_bytes_for_record $Data;
close $json_file;

## License: Public Domain.
