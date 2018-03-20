use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $Data = {};
my $src_path = path (__FILE__)->parent->parent->child ('src');
my $IANAData = json_bytes2perl $src_path->parent->child ('local/iana/http-parameters.json')->slurp;
my $IANAUpgradeData = json_bytes2perl $src_path->parent->child ('local/iana/http-protocols.json')->slurp;
my $IANAAuthData = json_bytes2perl $src_path->parent->child ('local/iana/http-auth-schemes.json')->slurp;
my $IANAIMData = json_bytes2perl $src_path->parent->child ('local/iana/http-ims.json')->slurp;
my $IANASIPData = json_bytes2perl $src_path->parent->child ('local/iana/sip.json')->slurp;
my $IANAFCASTData = json_bytes2perl $src_path->parent->child ('local/iana/fcast.json')->slurp;

{
  my $json = json_bytes2perl $src_path->parent->child ('local/iana/headers.json')->slurp;
  for my $record (
    @{$json->{registries}->{'perm-headers'}->{records}},
    @{$json->{registries}->{'prov-headers'}->{records}},
  ) {
    my $name = $record->{value};
    my $key = lc $name;
    $Data->{headers}->{$key}->{name} ||= $name;
    my $proto = lc $record->{protocol};
    next if $proto eq 'none';
    $Data->{headers}->{$key}->{$proto}->{iana} = 1;
    if (defined $record->{status}) {
      if ($record->{status} eq 'deprecated') {
        $Data->{headers}->{$key}->{$proto}->{deprecated} = 1;
      } elsif ($record->{status} eq 'obsoleted') {
        $Data->{headers}->{$key}->{$proto}->{obsolete} = 1;
      } elsif ($record->{status} eq 'standard') {
        #
      } elsif ($record->{status} eq 'informational') {
        #
      } elsif ($record->{status} eq 'reserved') {
        #
      } elsif ($record->{status} eq 'experimental') {
        #
      } else {
        warn "Unknown status: $record->{status}";
      }
    }
  }
}

{
  my $json = json_bytes2perl $src_path->parent->child ('local/iana/rtsp.json')->slurp;
  for my $record (
    @{$json->{registries}->{'rtsp-parameters-2'}->{records}},
  ) {
    my $name = $record->{name};
    my $key = lc $name;
    $Data->{headers}->{$key}->{name} ||= $name;
    $Data->{headers}->{$key}->{rtsp}->{iana} = 1;
  }
}

{
  for my $record (@{$IANASIPData->{registries}->{'sip-parameters-2'}->{records}}) {
    my $name = $record->{value};
    my $deprecated = $name =~ s/\s*\([Dd]eprecated(?:\s+by [^()]+|)\)\s*$//;
    my $key = lc $name;
    $Data->{headers}->{$key}->{name} ||= $name;
    $Data->{headers}->{$key}->{sip}->{iana} = 1;
    $Data->{headers}->{$key}->{sip}->{deprecated} = 1 if $deprecated;
    if (defined $record->{compact} and length $record->{compact}) {
      my $name = $record->{compact};
      my $key = lc $name;
      $Data->{headers}->{$key}->{name} ||= $name;
      $Data->{headers}->{$key}->{sip}->{iana} = 1;
      $Data->{headers}->{$key}->{sip}->{deprecated} = 1 if $deprecated;
    }
  }
}

{
  for my $record (@{$IANAFCASTData->{registries}->{'types'}->{records}}) {
    my $name = $record->{value};
    my $key = lc $name;
    $Data->{headers}->{$key}->{name} ||= $name;
    $Data->{headers}->{$key}->{fcast}->{iana} = 1;
  }
}

for (
  ['fcast-headers.txt', 'fcast'],
  ['icap-headers.txt', 'icap'],
  ['shttp-headers.txt', 's-http'],
  ['ssdp-headers.txt', 'ssdp'],
  ['http-headers.txt', 'http'],
  ['sip-headers.txt', 'sip'],
) {
  my $header_name;
  my ($file_name, $proto) = @$_;
  for (split /\x0D?\x0A/, $src_path->child ($file_name)->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      my $name = $1;
      $name =~ s/:$//;
      $header_name = lc $name;
      $Data->{headers}->{$header_name}->{name} = $name;
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
      $Data->{headers}->{$header_name}->{$proto}->{multiple} = '#';
    } elsif ($type =~ s/^1#//) {
      $Data->{headers}->{$header_name}->{$proto}->{value_is_list} = '+';
      $Data->{headers}->{$header_name}->{$proto}->{multiple} = '#';
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
  } elsif (m{^(connection-option|message-framing|routing|request-modifier|(?:response-|)control-data|payload-processing|representation-metadata|payload|validator|trace-unsafe|control|conditional|content-negotiation|authentication-credentials|request-context|cookie|authentication-challenge|response-context|obsolete|deprecated|fingerprinting|trailer|proxy|cache|robot|origin-server|accept-|fcast-metadata|fcast-cid-metadata|forbidden response|forbidden|simple|CORS included|CORS non-wildcard request-header|proxy-removed)\s*$}) {
    my $key = lc $1;
    $key =~ tr/ -/__/;
    $key = {'control_data' => 'response_control_data'}->{$key} || $key;
    $Data->{headers}->{$header_name}->{$proto}->{$key} = 1;
  } elsif (m{^(304-representation-metadata)(?:\s+(MAY)|)$}) {
    $Data->{headers}->{$header_name}->{$proto}->{'304_representation_metadata'} = $2 || 'MUST';
    $Data->{headers}->{$header_name}->{$proto}->{'206_representation_metadata'} = 'MUST' unless $2;
  } elsif (/^(byteranges)\s+(MUST|SHOULD|MAY)$/) {
    $Data->{headers}->{$header_name}->{$proto}->{$1} = $2;
  } elsif (/^(wildcard|multiple)$/) {
    $Data->{headers}->{$header_name}->{$1} = 1;
  } elsif (/^(multiple) (#SHOULD NOT)$/) {
    $Data->{headers}->{$header_name}->{$proto}->{$1} = $2;
  } elsif (/^(simple) (contextual)$/) {
    $Data->{headers}->{$header_name}->{$proto}->{$1} = $2;
  } elsif (/^sw (\S.*)$/) {
    $Data->{headers}->{$header_name}->{$proto}->{suikawiki} = $1;
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

  if ($header->{$proto}->{connection_option}) {
    $header->{$proto}->{proxy_removed} = 1;
  }
}
delete $Data->{headers}->{prefer}->{http}->{proxy_removed};

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
  } elsif (/^(deprecated|compression)$/) {
    $Data->{codings}->{$coding_name}->{transfer}->{$1} = 1;
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
  } elsif (/^(deprecated|compression)$/) {
    $Data->{codings}->{$coding_name}->{content}->{$1} = 1;
  } elsif (/^bad$/) {
    delete $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'};
    delete $Data->{codings}->{$coding_name}->{content}->{'Accept-Encoding'};
  } elsif (/^Accept-Encoding only$/) {
    delete $Data->{codings}->{$coding_name}->{content}->{'Content-Encoding'};
  } elsif (/^sw (\S.*)$/) {
    $Data->{codings}->{$coding_name}->{content}->{suikawiki} = $1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

undef $coding_name;
{
  for my $record (@{$IANAIMData->{registries}->{'inst-man-values'}->{records}}) {
    my $coding_name = lc $record->{name};
    $Data->{codings}->{$coding_name}->{im}->{'IM'} = 1;
    $Data->{codings}->{$coding_name}->{im}->{'A-IM'} = 1;
    $Data->{codings}->{$coding_name}->{im}->{iana} = 1;
  }
}
for (split /\x0D?\x0A/, $src_path->child ('http-ims.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = lc $1;
    $coding_name = $name;
    $Data->{ims}->{$coding_name}->{im}->{'IM'} = 1;
    $Data->{ims}->{$coding_name}->{im}->{'A-IM'} = 1;
    next;
  } elsif (/\S/) {
    die "Coding not defined at first line" unless defined $coding_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Data->{codings}->{$coding_name}->{im}->{spec} = "RFC$1";
      $Data->{codings}->{$coding_name}->{im}->{id} = $2;
    } else {
      $Data->{codings}->{$coding_name}->{im}->{url} = $url;
    }
  } elsif (/^(obsolete|delta-coding|compression)$/) {
    my $v = $1;
    $v =~ tr/-/_/;
    $Data->{codings}->{$coding_name}->{im}->{$v} = 1;
  } elsif (/^A-IM only$/) {
    delete $Data->{codings}->{$coding_name}->{im}->{'IM'};
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

{
  for my $record (@{$IANAAuthData->{registries}->{authschemes}->{records}}) {
    my $name = lc $record->{value};
    $Data->{auth_schemes}->{$name}->{name} = $record->{value};
    $Data->{auth_schemes}->{$name}->{iana} = 1;
  }
  my $name;
  my $param_type;
  my $param_name;
  for (split /\x0D?\x0A/, $src_path->child ('http-auth-schemes.txt')->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      $name = lc $1;
      $Data->{auth_schemes}->{$name}->{name} ||= $1;
      undef $param_type;
      undef $param_name;
      next;
    } elsif (/\S/) {
      die "auth-scheme not defined at first line" unless defined $name;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Data->{auth_schemes}->{$name}->{spec} = "RFC$1";
        $Data->{auth_schemes}->{$name}->{id} = $2;
      } else {
        $Data->{auth_schemes}->{$name}->{url} = $url;
      }
    } elsif (defined $param_type and defined $param_name and
             /^  spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Data->{auth_schemes}->{$name}->{$param_type}->{auth_params}->{$param_name}->{spec} = "RFC$1";
        $Data->{auth_schemes}->{$name}->{$param_type}->{auth_params}->{$param_name}->{id} = $2;
      } else {
        $Data->{auth_schemes}->{$name}->{$param_type}->{auth_params}->{$param_name}->{url} = $url;
      }
    } elsif (/^(obsolete|origin server|proxy)$/) {
      my $v = $1;
      $v =~ tr/ /_/;
      $Data->{auth_schemes}->{$name}->{$v} = 1;
    } elsif (defined $param_type and defined $param_name and
             /^  (obsolete)$/) {
      $Data->{auth_schemes}->{$name}->{$param_type}->{auth_params}->{$param_name}->{$1} = 1;
    } elsif (/^(challenge|credentials) (auth-param|token68|non-standard)$/) {
      $Data->{auth_schemes}->{$name}->{$1}->{syntax} = $2;
    } elsif (/^(challenge|credentials|info) (\S+)=""$/) {
      $param_type = $1;
      $param_name = lc $2;
      $Data->{auth_schemes}->{$name}->{$1}->{auth_params}->{$param_name}->{name} = $2;
      $Data->{auth_schemes}->{$name}->{$1}->{syntax} ||= 'auth-param';
    } elsif (/^(http)$/) {
      $Data->{auth_schemes}->{$name}->{protocols}->{HTTP} = 'MAY';
      $Data->{auth_schemes}->{$name}->{protocols}->{RTSP} = 'MAY';
    } elsif (/^(sip|msrp)$/) {
      $Data->{auth_schemes}->{$name}->{protocols}->{uc $1} = 'MAY';
    } elsif (/^(sip) (MUST NOT)$/) {
      $Data->{auth_schemes}->{$name}->{protocols}->{SIP} = $2;
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
}

{
  for my $record (@{$IANAData->{registries}->{preferences}->{records}}) {
    my $name = lc $record->{name};
    $Data->{preferences}->{$name}->{name} = $record->{name};
    $Data->{preferences}->{$name}->{iana} = 1;
  }
  my $name;
  my $param_name;
  for (split /\x0D?\x0A/, $src_path->child ('http-preferences.txt')->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      $name = lc $1;
      $Data->{preferences}->{$name}->{name} ||= $1;
      undef $param_name;
      next;
    } elsif (/\S/) {
      die "preference not defined at first line" unless defined $name;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Data->{preferences}->{$name}->{spec} = "RFC$1";
        $Data->{preferences}->{$name}->{id} = $2;
      } else {
        $Data->{preferences}->{$name}->{url} = $url;
      }
    } elsif (defined $param_name and /^  spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Data->{preferences}->{$name}->{params}->{$param_name}->{spec} = "RFC$1";
        $Data->{preferences}->{$name}->{params}->{$param_name}->{id} = $2;
      } else {
        $Data->{preferences}->{$name}->{params}->{$param_name}->{url} = $url;
      }
    } elsif (/^([\w-]+)=""$/) {
      $param_name = $1;
      $Data->{preferences}->{$name}->{params}->{$param_name} ||= {};
    } elsif (/^value none$/) {
      $Data->{preferences}->{$name}->{value_optionality} = 'MUST NOT';
    } elsif (/^value (delta-seconds|non-negative integer)$/) {
      $Data->{preferences}->{$name}->{value_optionality} = 'MUST';
      $Data->{preferences}->{$name}->{value_type} = $1;
    } elsif (/^value=([\w-]+)$/) {
      $Data->{preferences}->{$name}->{value_optionality} = 'MUST';
      $Data->{preferences}->{$name}->{enumerated}->{$1} ||= {};
    } elsif (/^value$/) {
      $Data->{preferences}->{$name}->{value_optionality} = 'MUST';
    } elsif (defined $param_name and /^  (MUST)$/) {
      $Data->{preferences}->{$name}->{params}->{$param_name}->{optionality} = $1;
    } elsif (defined $param_name and /^  value (URL|non-negative integer)$/) {
      $Data->{preferences}->{$name}->{params}->{$param_name}->{value_type} = $1;
    } elsif (/^(obsolete)$/) {
      $Data->{preferences}->{$name}->{$1} = 1;
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
}

{
  my $data;
  for (split /\x0D?\x0A/, $src_path->child ('http-equiv.txt')->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      my $name = lc $1;
      $data = $Data->{headers}->{$name}->{http_equiv} ||= {};
      $data->{name} ||= $1;
      $Data->{headers}->{$name}->{name} ||= $1;
      next;
    } elsif (/\S/) {
      die "Header not defined at first line" unless defined $data;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $data->{spec} = "RFC$1";
        $data->{id} = $2;
      } elsif ($url =~ m{^https?://html.spec.whatwg.org/#(.+)$}) {
        $data->{spec} = 'HTML';
        $data->{id} = $1;
      } else {
        $data->{url} = $url;
      }
    } elsif (/^value (language tag|non-empty text)$/) {
      $data->{value_type} = $1;
    } elsif (/^(conforming|obsolete)$/) {
      $data->{$1} = 1;
    } elsif (/^(non-conforming)$/) {
      delete $data->{conforming};
    } elsif (/^WHATWG Wiki (allowed|proposed)$/) {
      #$data->{whatwg_wiki_status} = $1;
      #$data->{conforming} = 1;
    } elsif (/(.+) state/) {
      $data->{enumerated_attr_state_name} = $1;
    } elsif (/\S/) {
      die "Broken line |$_|";
    }
  }
}

sub add_data ($) {
  my $x = shift;
  my $registry = $IANAData;
  if (defined $x->{iana_registry_file_name}) {
    $registry = json_bytes2perl $src_path->parent->child ('local/iana/', $x->{iana_registry_file_name})->slurp;
  }
  for my $record (@{$registry->{registries}->{$x->{iana_registry_name} // ''}->{records}}) {
    my $name = $record->{$x->{iana_value_key}};
    $Data->{$x->{key}}->{lc $name}->{name} = $name;
    $name = lc $name;
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
      $Data->{$x->{key}}->{lc $1}->{name} = $1;
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
    } elsif (/^(?:(request|response)\s+|)value\s+(#|1#|)(delta-seconds|field-name|absolute URL|non-negative integer|integer|HTTP node|HTTP-date|ASCII URL|text|)\s*$/) {
      my ($type, $n, $value_type) = ($1, $2, $3);
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      if ($n eq '#') {
        $v->{value_is_list} = '*';
        #$v->{multiple} = '#';
      } elsif ($n eq '1#') {
        $v->{value_is_list} = '+';
        #$v->{multiple} = '#';
      }
      $v->{value_type} = $value_type if length $value_type;
    } elsif (/^(?:(request|response)\s+|)value\s+SHOULD\s+(token|quoted-string)\s*$/) {
      my $type = $1;
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      $v->{value_should} = $2;
    } elsif (/^(?:(request|response)\s+|)value\s+(MUST|MAY|MUST NOT|SHOULD|SHOULD NOT)\s*$/) {
      my $type = $1;
      my $v = $Data->{$x->{key}}->{$name} ||= {};
      $v = $v->{$type} ||= {} if defined $type;
      $v->{value_optionality} = $2;
    } elsif (/^(mime|http|vpim|sip)$/) {
      $Data->{$x->{key}}->{$name}->{protocols}->{uc $1} = 1;
    } elsif (m{^(multipart/form-data)$}) {
      $Data->{$x->{key}}->{$name}->{protocols}->{$1} = 1;
    } elsif (/^(rfc2068_warn_code)\s+(\S+)$/) {
      $Data->{$x->{key}}->{$name}->{$1} = $2;
    } elsif (/^(obsolete|multiple)$/) {
      $Data->{$x->{key}}->{$name}->{$1} = 1;
    } elsif (/^(SHOULD NOT) -> (\S+)$/) {
      $Data->{$x->{key}}->{$name}->{deprecated} = 'SHOULD NOT';
      $Data->{$x->{key}}->{$name}->{preferred_name} = $2;
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
add_data +{iana_registry_name => 'forwarded',
           iana_value_key => 'name',
           key => 'forwarded',
           src_file_name => 'http-forwarded.txt'};
add_data +{iana_registry_file_name => 'cont-disp.json',
           iana_registry_name => 'cont-disp-1',
           iana_value_key => 'name',
           key => 'disposition_types',
           src_file_name => 'disposition-types.txt'};
add_data +{iana_registry_file_name => 'cont-disp.json',
           iana_registry_name => 'cont-disp-2',
           iana_value_key => 'name',
           key => 'disposition_params',
           src_file_name => 'disposition-params.txt'};
add_data +{key => 'cookie_attrs',
           src_file_name => 'http-cookie-attrs.txt'};
add_data +{key => 'keep_alive_params',
           src_file_name => 'http-keep-alive.txt'};
add_data +{key => 'meter_directives',
           src_file_name => 'http-meter-directives.txt'};
add_data +{key => 'safe_natures',
           src_file_name => 'http-safe.txt'};
add_data +{key => 'addition_types',
           src_file_name => 'http-additions.txt'};
add_data +{key => 'list_directives',
           src_file_name => 'http-list-directives.txt'};
add_data +{key => 'negotiate_directives',
           src_file_name => 'http-negotiate-directives.txt'};
add_data +{key => 'tcn_directives',
           src_file_name => 'http-tcn-directives.txt'};
add_data +{key => 'extension_declarations',
           src_file_name => 'http-ext-decls.txt'};
add_data +{key => 'p3p_directives',
           src_file_name => 'http-p3p.txt'};
add_data +{key => 'hsts_directives',
           src_file_name => 'http-hsts.txt'};
add_data +{key => 'pkp_directives',
           src_file_name => 'http-pkp.txt'};
add_data +{iana_registry_file_name => 'alt-svc.json',
           iana_registry_name => 'alt-svc-parameters',
           iana_value_key => 'value',
           key => 'alt_svc_params',
           src_file_name => 'http-alt-svc.txt'};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
