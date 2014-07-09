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
      $Data->{headers}->{$header_name}->{http}->{value_type} = {
        'media-type' => 'MIME type',
        'language-tag' => 'language tag',
      }->{$type} || $type;
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
  } elsif (m{^(connection-option|message-framing|routing|request-modifier|authentication|response-control-data|payload-processing|representation-metadata|payload|validator|trace-unsafe|control|conditional|content-negotiation|authentication-credentials|request-context)\s*$}) {
    my $key = $1;
    $key =~ s/-/_/g;
    $Data->{headers}->{$header_name}->{http}->{$key} = 1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

for (keys %{$Data->{headers}}) {
  my $header = $Data->{headers}->{$_};

  ## Not explicitly specified...
  $header->{http}->{payload_processing} = 1
      if $header->{http}->{representation_metadata} or
         $header->{http}->{payload};

  ## RFC 7230 "e.g., controls and conditionals in Section 5 of [RFC7231]"
  $header->{http}->{request_modifier} = 1
      if $header->{http}->{control} or
         $header->{http}->{conditional};

  ## Per RFC 7230 Trailer:'s definition
  $header->{http}->{not_for_trailer} = 1
      if $header->{http}->{message_framing} or
         $header->{http}->{routing} or
         $header->{http}->{request_modifier} or
         $header->{http}->{authentication} or
         $header->{http}->{response_control_data} or
         $header->{http}->{payload_processing};
}

my $protocol_name;
for (split /\x0D?\x0A/, $src_path->child ('http-protocols.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $protocol_name = $name;
    $Data->{protocols}->{$protocol_name} ||= {};
    next;
  } elsif (/\S/) {
    die "Protocol not defined at first line" unless defined $protocol_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{protocols}->{$protocol_name}->{spec} = "RFC$1";
      $Data->{protocols}->{$protocol_name}->{id} = $2;
    } else {
      $Data->{protocols}->{$protocol_name}->{url} = $url;
    }
  } elsif (m{^(upgrade|start-line|via|server-protocol)\s*$}) {
    my $key = $1;
    $key =~ s/-/_/g;
    $Data->{protocols}->{$protocol_name}->{$key} = 1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

my $coding_name;
for (split /\x0D?\x0A/, $src_path->child ('http-transfer-codings.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $coding_name = $name;
    $Data->{codings}->{$coding_name}->{transfer}->{TE} = 1;
    $Data->{codings}->{$coding_name}->{transfer}->{'Transfer-Encoding'} = 1;
    next;
  } elsif (/\S/) {
    die "Coding not defined at first line" unless defined $coding_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{codings}->{$coding_name}->{transfer}->{spec} = "RFC$1";
      $Data->{codings}->{$coding_name}->{transfer}->{id} = $2;
    } else {
      $Data->{codings}->{$coding_name}->{transfer}->{url} = $url;
    }
  } elsif (/^deprecated\s*->\s*(\S+)$/) {
    $Data->{codings}->{$coding_name}->{transfer}->{deprecated} = 1;
    $Data->{codings}->{$coding_name}->{transfer}->{preferred_name} = $1;
  } elsif (/^deprecated$/) {
    $Data->{codings}->{$coding_name}->{transfer}->{deprecated} = 1;
  } elsif (/^bad$/) {
    delete $Data->{codings}->{$coding_name}->{transfer}->{TE};
    delete $Data->{codings}->{$coding_name}->{transfer}->{'Transfer-Encoding'};
  } elsif (/^not-in-TE$/) {
    delete $Data->{codings}->{$coding_name}->{transfer}->{TE};
  } elsif (/^TE-only$/) {
    delete $Data->{codings}->{$coding_name}->{transfer}->{'Transfer-Encoding'};
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

undef $coding_name;
for (split /\x0D?\x0A/, $src_path->child ('http-content-codings.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $coding_name = $name;
    $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{content}->{'Accept-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{content} ||= {};
    next;
  } elsif (/\S/) {
    die "Coding not defined at first line" unless defined $coding_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{codings}->{$coding_name}->{content}->{spec} = "RFC$1";
      $Data->{codings}->{$coding_name}->{content}->{id} = $2;
    } else {
      $Data->{codings}->{$coding_name}->{content}->{url} = $url;
    }
  } elsif (/^deprecated\s*->\s*(\S+)$/) {
    $Data->{codings}->{$coding_name}->{content}->{deprecated} = 1;
    $Data->{codings}->{$coding_name}->{content}->{preferred_name} = $1;
  } elsif (/^deprecated$/) {
    $Data->{codings}->{$coding_name}->{content}->{deprecated} = 1;
  } elsif (/^bad$/) {
    delete $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'};
    delete $Data->{codings}->{$coding_name}->{content}->{'Accept-Encoding'};
  } elsif (/^Accept-Encoding only$/) {
    delete $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'};
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
