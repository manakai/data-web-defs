use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;
my $src_path = $root_path->child ('intermediate/wpa-mime-types.json');
my $Data = json_bytes2perl $src_path->slurp;

for my $type (keys %$Data) {
  my $data = $Data->{$type};
  $data->{url} = 'https://www.iana.org/assignments/media-types/'.$type;
  if (not $data->{required_params} or
      not $data->{optional_params}) {
    unless ($data->{parse_error}) {
      warn $type;
      $data->{parse_error} = 1;
    }
  }
}

{
  my $type;
  my $data = {};
  for (split /[\x0D\x0A]+/, $root_path->child ('src/mime-type-iana-template.txt')->slurp) {
    if (/^\s*#/) {
      #
    } elsif (m{^https://www.iana.org/.+/([^/]+/[^/]+)$}) {
      $type = $1;
      $type =~ tr/A-Z/a-z/;
      $Data->{$type} = $data = {};
      $data->{url} = 'https://www.iana.org/assignments/media-types/'.$type;
    } elsif (m{^  (req|opt) -$}) {
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'} = 'none';
    } elsif (m{^  (req|opt) ([A-Za-z0-9_-]+)=""$}) {
      die "Bad $1 - $type" if defined $data->{$1 eq 'req' ? 'required_params' : 'optional_params'} and not ref $data->{$1 eq 'req' ? 'required_params' : 'optional_params'};
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'}->{$2} = {};
    } elsif (m{^  (req|opt) ([A-Za-z0-9_-]+)="" (RFC 3023 application/xml|XML character encoding, default UTF-8|UTF-8 uppercase|RFC 3023 application/xml utf-8 \| utf-16)$}) {
      die "Bad $1 - $type" if defined $data->{$1 eq 'req' ? 'required_params' : 'optional_params'} and not ref $data->{$1 eq 'req' ? 'required_params' : 'optional_params'};
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'}->{$2} = $3;
    } elsif (m{^  (req|opt) ([A-Za-z0-9_-]+)="" (\w+)$}) {
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'}->{$2} = {type => $2};
    } elsif (m{^  (req|opt) ([A-Za-z0-9_-]+)="" \[obsolete\]$}) {
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'}->{$2} = {obsolete => 1};
    } elsif (m{^  (req|opt) ([A-Za-z0-9_-]+)="" \[SHOULD\]$}) {
      $data->{$1 eq 'req' ? 'required_params' : 'optional_params'}->{$2} = {SHOULD => 1};
    } elsif (m{^  fragment -$}) {
      $data->{fragment} = 'none';
    } elsif (m{^  COMMON$}) {
      $data->{intended_usage} = 'common';
    } elsif (m{^  LIMITED USE$}) {
      $data->{intended_usage} = 'limited use';
    } elsif (m{^  CTE (base64|quoted-printable)$}) {
      $data->{preferred_cte} = $1;
    } elsif (m{^  \.([A-Za-z0-9_-]+)$}) {
      $data->{exts}->{$1} = 1;
    } elsif (m{^  Mac creator (\S...)$}) {
      $data->{mac_creator} = $1;
    } elsif (m{^  Mac type (\S...)$}) {
      $data->{mac_type} = $1;
    } elsif (m{^  multipart/encrypted protocol$}) {
      $data->{multipart_encrypted_protocol} = 1;
    } elsif (m{^  multipart/signed protocol$}) {
      $data->{multipart_signed_protocol} = 1;
    } elsif (m{^  plugin$}) {
      $data->{plugin} = 1;
    } elsif (/\S/) {
      die "Bad line |$_|";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
