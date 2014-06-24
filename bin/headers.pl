use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $Data = {};
my $src_path = path (__FILE__)->parent->parent->child ('src');

my $header_name;
for (split /\x0D?\x0A/, $src_path->child ('http-headers.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $header_name = lc $name;
    $Data->{headers}->{$header_name}->{name} = $name;
    next;
  } elsif (/\S/) {
    die "Header not defined at first line" unless defined $header_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{headers}->{$header_name}->{http}->{spec} = "RFC$1";
      $Data->{headers}->{$header_name}->{http}->{id} = $2;
    } else {
      $Data->{headers}->{$header_name}->{http}->{url} = $url;
    }
  } elsif (/^value\s+(.+)$/) {
    my $type = $1;
    $type =~ s/\s+$//;
    if ($type =~ s/^\#//) {
      $Data->{headers}->{$header_name}->{http}->{value_is_list} = '*';
      $Data->{headers}->{$header_name}->{http}->{multiple} = 1;
    } elsif ($type =~ s/^1#//) {
      $Data->{headers}->{$header_name}->{http}->{value_is_list} = '+';
      $Data->{headers}->{$header_name}->{http}->{multiple} = 1;
    }
    if ($type =~ /^([a-z0-9-]+)$/) {
      $Data->{headers}->{$header_name}->{http}->{value_type} = $type;
    } elsif ($type =~ /^1\*DIGIT$/) {
      $Data->{headers}->{$header_name}->{http}->{value_type} = 'non-negative integer';
    } elsif (length $type) {
      die "Bad value type |$type|";
    }
  } elsif (/^([0-9x]{3})\s+(MUST|MUST NOT|SHOULD|SHOULD NOT)$/) {
    $Data->{headers}->{$header_name}->{http}->{response}->{$1} = $2;
  } elsif (/^(\?\?\?)\s+(MUST|MUST NOT|SHOULD|SHOULD NOT)$/) {
    $Data->{headers}->{$header_name}->{http}->{response}->{'*'} = $2;
  } elsif (m{^(HTTP/1.1)\s*$}) {
    $Data->{headers}->{$header_name}->{http}->{not_for_http10} = 1;
  } elsif (m{^(request)\s*$}) {
    $Data->{headers}->{$header_name}->{http}->{request}->{'*'} ||= '';
  } elsif (m{^(response)\s*$}) {
    $Data->{headers}->{$header_name}->{http}->{response}->{xxx} ||= '';
  } elsif (m{^(connection-option|message-framing|routing|request-modifier|authentication|response-control-data|payload-processing)\s*$}) {
    my $key = $1;
    $key =~ s/-/_/g;
    $Data->{headers}->{$header_name}->{http}->{$key} = 1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

for (keys %{$Data->{headers}}) {
  my $header = $Data->{headers}->{$_};
  $header->{http}->{not_for_trailer} = 1
      if $header->{http}->{message_framing} or
         $header->{http}->{routing} or
         $header->{http}->{request_modifier} or
         $header->{http}->{authentication} or
         $header->{http}->{response_control_data} or
         $header->{http}->{payload_processing};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
