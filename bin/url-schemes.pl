use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use Encode;

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
    $Data->{$scheme} = {props => {}};
  } elsif (/^\s+([\w-]+)\s*$/) {
    $Data->{$scheme}->{props}->{$1} = 1;
  } elsif (/^\s+([\w-]+)=(\S+)\s*$/) {
    $Data->{$scheme}->{props}->{$1} = $2;
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
      $Data->{$scheme}->{props} ||= {};
    } elsif (/^\s+([\w-]+)\s*$/) {
      $Data->{$scheme}->{props}->{$1} = 1;
    } elsif (/^\s+([\w-]+)=(\S+)\s*$/) {
      $Data->{$scheme}->{props}->{$1} = $2;
    } elsif (/\S/) {
      die "Broken data: $_";
    }
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
open my $json_file, '>', 'data/url-schemes.json' or die "$0: url-schemes.json: $!";
print $json_file perl2json_bytes_for_record $Data;
close $json_file;

## License: Public Domain.
