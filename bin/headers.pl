use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $Data = {};
my $src_path = path (__FILE__)->parent->parent->child ('src');
my $IANAData = json_bytes2perl $src_path->parent->child ('local/iana/http-parameters.json')->slurp;
my $IANAUpgradeData = json_bytes2perl $src_path->parent->child ('local/iana/http-protocols.json')->slurp;

for (
  ['http-headers.txt', 'http'],
  ['icap-headers.txt', 'icap'],
) {
  my $header_name;
  my ($file_name, $proto) = @$_;
  for (split /\x0D?\x0A/, $src_path->child ($file_name)->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      my $name = $1;
      $header_name = lc $name;
      $Data->{headers}->{$header_name}->{name} ||= $name;
      next;
    } elsif (/\S/) {
      die "Header not defined at first line" unless defined $header_name;
    }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{headers}->{$header_name}->{$proto}->{spec} = "RFC$1";
      $Data->{headers}->{$header_name}->{$proto}->{id} = $2;
    } else {
      $Data->{headers}->{$header_name}->{$proto}->{url} = $url;
    }
  } elsif (/^value\s+(.+)$/) {
    my $type = $1;
    $type =~ s/\s+$//;
    if ($type =~ s/^\#//) {
      $Data->{headers}->{$header_name}->{$proto}->{value_is_list} = '*';
      $Data->{headers}->{$header_name}->{$proto}->{multiple} = 1;
    } elsif ($type =~ s/^1#//) {
      $Data->{headers}->{$header_name}->{$proto}->{value_is_list} = '+';
      $Data->{headers}->{$header_name}->{$proto}->{multiple} = 1;
    }
    if ($type =~ /^([A-Za-z0-9 -]+)$/) {
      $Data->{headers}->{$header_name}->{$proto}->{value_type} = {
        'media-type' => 'MIME type',
        'language-tag' => 'language tag',
      }->{$type} || $type;
    } elsif ($type =~ /^1\*DIGIT$/) {
      $Data->{headers}->{$header_name}->{$proto}->{value_type} = 'non-negative integer';
    } elsif (length $type) {
      die "Bad value type |$type|";
    }
  } elsif (/^([0-9x?]{3})(?:\s+(MUST|MUST NOT|SHOULD|SHOULD NOT|MAY|ignored)|)$/) {
    my $code = $1;
    my $kwd = $2 // '';
    $code =~ s/\?/x/g;
    $Data->{headers}->{$header_name}->{$proto}->{response}->{$code} = $kwd;
  } elsif (/^(x|request \S+)\s+(MUST|MUST NOT|SHOULD|SHOULD NOT|MAY|ignored)$/) {
    my $method = $1;
    my $kwd = $2;
    $method = '*' if $method eq 'x';
    $method =~ s/^request //;
    $Data->{headers}->{$header_name}->{$proto}->{request}->{$method} = $kwd;
  } elsif (m{^(HTTP/1.1)\s*$}) {
    $Data->{headers}->{$header_name}->{$proto}->{not_for_http10} = 1;
  } elsif (m{^(request)\s*$}) {
    $Data->{headers}->{$header_name}->{$proto}->{request}->{'*'} ||= '';
  } elsif (m{^(response)\s*$}) {
    $Data->{headers}->{$header_name}->{$proto}->{response}->{xxx} ||= '';
  } elsif (m{^(connection-option|message-framing|routing|request-modifier|(?:response-|)control-data|payload-processing|representation-metadata|payload|validator|trace-unsafe|control|conditional|content-negotiation|authentication-credentials|request-context|cookie|authentication-challenge|response-context|obsolete|fingerprinting)\s*$}) {
    my $key = $1;
    $key =~ s/-/_/g;
    $key = {'control_data' => 'response_control_data'}->{$key} || $key;
    $Data->{headers}->{$header_name}->{$proto}->{$key} = 1;
  } elsif (m{^(304-representation-metadata)(?:\s+(MAY)|)$}) {
    $Data->{headers}->{$header_name}->{$proto}->{'304_representation_metadata'} = $2 || 'MUST';
    $Data->{headers}->{$header_name}->{$proto}->{'206_representation_metadata'} = 'MUST' unless $2;
  } elsif (/^(byteranges)\s+(MUST|SHOULD|MAY)$/) {
    $Data->{headers}->{$header_name}->{$proto}->{$1} = $2;
  } elsif (/^(wildcard)$/) {
    $Data->{headers}->{$header_name}->{$1} = 1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}
}

my $proto = 'http';
for (keys %{$Data->{headers}}) {
  my $header = $Data->{headers}->{$_};
  next unless $header->{$proto};

  ## RFC 7230 "determining how to process the payload" (Not explicitly
  ## specified...)
  $header->{$proto}->{payload_processing} = 1
      if $header->{$proto}->{representation_metadata} or
         $header->{$proto}->{payload};

  ## RFC 7230 "e.g., controls and conditionals in Section 5 of [RFC7231]"
  $header->{$proto}->{request_modifier} = 1
      if $header->{$proto}->{control} or
         $header->{$proto}->{conditional};

  ## RFC 7230 "authentication" (it's not clear...)
  $header->{$proto}->{authentication} = 1
      if $header->{$proto}->{authentication_credentials} or
         $header->{$proto}->{authentication_challenge} or
         $header->{$proto}->{cookie};

  ## Per RFC 7230 Trailer:'s definition (it's not clear...)
  $header->{$proto}->{not_for_trailer} = 1
      if $header->{$proto}->{message_framing} or
         $header->{$proto}->{routing} or
         $header->{$proto}->{request_modifier} or
         $header->{$proto}->{request_authentication} or
         $header->{$proto}->{response_control_data} or
         $header->{$proto}->{payload_processing};

  ## Per RFC 7231 4.3.8., "sensitive data that might be disclosed by
  ## the response.  For example, ... stored user credentials [RFC7235]
  ## or cookies [RFC6265]"
  $header->{$proto}->{trace_unsafe} = 1
      if $header->{$proto}->{authentication_credentials} or
         $header->{$proto}->{cookie};

  ## <https://tools.ietf.org/html/rfc7232#section-4.1>,
  ## <http://wiki.suikawiki.org/n/representation%20metadata$233#anchor-4>
  if ($header->{$proto}->{representation_metadata} or
      $header->{$proto}->{validator}) {
    $header->{$proto}->{response}->{304} = 'SHOULD NOT'
        unless $header->{$proto}->{'304_representation_metadata'};
    $header->{$proto}->{'206_representation_metadata'} ||= 'SHOULD NOT';
  }
}

{
  for my $record (@{$IANAUpgradeData->{registries}->{'http-upgrade-tokens-1'}->{records}}) {
    my $name = $record->{value};
    $Data->{protocols}->{$name}->{iana} = 1;
    if (defined $record->{expected} and length $record->{expected}) {
      $Data->{protocols}->{$name}->{need_version} = 1;
    }
  }
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

{
  for my $record (@{$IANAData->{registries}->{'transfer-coding'}->{records}}) {
    my $coding_name = $record->{name};
    $Data->{codings}->{$coding_name}->{transfer}->{TE} = 1;
    $Data->{codings}->{$coding_name}->{transfer}->{'Transfer-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{transfer}->{iana} = 1;
    my $desc = $record->{description};
    if ($desc =~ /^Deprecated \(alias for (\w+)\)$/) {
      $Data->{codings}->{$coding_name}->{transfer}->{deprecated} = 1;
      $Data->{codings}->{$coding_name}->{transfer}->{preferred_name} = $1;
    } elsif ($desc =~ /^\(withdrawn /) {
      $Data->{codings}->{$coding_name}->{transfer}->{obsolete} = 1;
    }
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
{
  for my $record (@{$IANAData->{registries}->{'content-coding'}->{records}}) {
    my $coding_name = $record->{name};
    $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{content}->{'Accept-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{content}->{iana} = 1;
    my $desc = $record->{description};
    if ($desc =~ /^Deprecated \(alias for (\w+)\)$/) {
      $Data->{codings}->{$coding_name}->{content}->{deprecated} = 1;
      $Data->{codings}->{$coding_name}->{content}->{preferred_name} = $1;
    } elsif ($desc =~ /^Reserved \(/) {
      $Data->{codings}->{$coding_name}->{content}->{reserved} = 1;
    }
  }
}
for (split /\x0D?\x0A/, $src_path->child ('http-content-codings.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $coding_name = $name;
    $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'} = 1;
    $Data->{codings}->{$coding_name}->{content}->{'Accept-Encoding'} = 1;
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

sub add_data ($) {
  my $x = shift;
  my $registry = $IANAData;
  if (defined $x->{iana_registry_file_name}) {
    $registry = json_bytes2perl $src_path->parent->child ('local/iana/', $x->{iana_registry_file_name})->slurp;
  }
  for my $record (@{$registry->{registries}->{$x->{iana_registry_name}}->{records}}) {
    my $name = $record->{$x->{iana_value_key}};
    $Data->{$x->{key}}->{$name}->{$x->{iana_key} // 'iana'} = 1;
    my $desc = $record->{description};
    if (defined $desc and $desc =~ /^reserved as /) {
      $Data->{$x->{key}}->{$name}->{reserved} = 1;
    }
    if ($x->{key} eq 'warn_codes' and defined $desc) {
      $desc =~ s/: .+$//s;
      $Data->{$x->{key}}->{$name}->{default_warn_text} = $desc;
    }
  }
  my $name;
  for (split /\x0D?\x0A/, $src_path->child ($x->{src_file_name})->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      $name = lc $1;
      next;
    } elsif (/\S/) {
      die "Unit not defined at first line" unless defined $name;
    }

    if (/^(?:(request|response)\s+|)spec\s+(\S+)\s*$/) {
      my $type = $1;
      my $url = $2;
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $v->{spec} = "RFC$1";
        $v->{id} = $2;
      } else {
        $v->{url} = $url;
      }
    } elsif (/^(?:(request|response)\s+|)value\s+(#|1#|)(delta-seconds|field-name|absolute URL|non-negative integer|integer)\s*$/) {
      my ($type, $n, $value_type) = ($1, $2, $3);
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      if ($n eq '#') {
        $v->{value_is_list} = '*';
        $v->{multiple} = 1;
      } elsif ($n eq '1#') {
        $v->{value_is_list} = '+';
        $v->{multiple} = 1;
      }
      $v->{value_type} = $value_type;
    } elsif (/^(?:(request|response)\s+|)value\s+SHOULD\s+(token|quoted-string)\s*$/) {
      my $type = $1;
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      $v->{value_should} = $2;
    } elsif (/^(?:(request|response)\s+|)value\s+(MUST|MAY|MUST NOT)\s*$/) {
      my $type = $1;
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      $v->{value_optionality} = $2;
    } elsif (/^(rfc2068_warn_code)\s+(\S+)$/) {
      $Data->{$x->{key}}->{$name}->{$1} = $2;
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
} # add_data

add_data +{iana_registry_name => 'range-units',
           iana_value_key => 'name',
           key => 'range_units',
           src_file_name => 'http-range-units.txt'};
add_data +{iana_registry_file_name => 'http-cache-control.json',
           iana_registry_name => 'cache-directives',
           iana_value_key => 'value',
           key => 'cache_directives',
           src_file_name => 'http-cache-directives.txt'};
add_data +{iana_registry_name => '___dummy___',
           iana_value_key => 'value',
           key => 'pragma_directives',
           src_file_name => 'http-pragma-directives.txt'};
add_data +{iana_registry_file_name => 'http-warn-codes.json',
           iana_registry_name => 'warn-codes',
           iana_value_key => 'value',
           key => 'warn_codes',
           src_file_name => 'http-warn-codes.txt'};
add_data +{iana_registry_file_name => 'sip.json',
           iana_registry_name => 'sip-parameters-5',
           iana_value_key => 'value',
           iana_key => 'iana_sip',
           key => 'warn_codes',
           src_file_name => 'sip-warn-codes.txt'};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
