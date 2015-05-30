use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;

my $Data = {};

my $lists = {};
{
  $lists->{tls12_required}->{$_} = 1
      for qw(TLS_RSA_WITH_AES_128_CBC_SHA);
  $lists->{tls12_recommended}->{$_} = 1
      for qw(TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
             TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
             TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
             TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384); # RFC 7525
  $lists->{h2_required}->{$_} = 1
      for qw(TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256);

  for (grep { length } split /\x0D?\x0A/, $root_path->child ('src/tls-http2-blacklist.txt')->slurp) {
    $lists->{h2_blacklist}->{$_} = 1;
  }
}

{
  my $path = $root_path->child ('local/iana/tls.json');
  my $json = json_bytes2perl $path->slurp;

  for my $record (@{$json->{registries}->{'tls-parameters-4'}->{records}}) {
    my @value;
    if ($record->{value} =~ /^0x([0-9A-Fa-f]+),0x([0-9A-Fa-f]+)$/) {
      push @value, (hex $1) * 0x100 + hex $2;
    } elsif ($record->{value} =~ /^0x([0-9A-Fa-f]+),0x([0-9A-Fa-f]+)-([0-9A-Fa-f]+)$/) {
      push @value, (hex $1) * 0x100 + $_ for (hex $2)..(hex $3);
    } elsif ($record->{value} =~ /^0x([0-9A-Fa-f]+),\*$/) {
      push @value, (hex $1) * 0x100 + $_ for 0..255;
    }

    for my $code (@value) {
      if ($record->{description} =~ /^Reserved/) {
        $Data->{cipher_suites}->{$code}->{code} = $code;
        $Data->{cipher_suites}->{$code}->{iana} = 1;
        $Data->{cipher_suites}->{$code}->{reserved} = 1;
      } elsif ($record->{description} =~ /^Unassigned/) {
        #
      } elsif ($record->{description} =~ /\A[A-Za-z0-9_]+\z/) {
        $Data->{cipher_suites}->{$code}->{code} = $code;
        $Data->{cipher_suites}->{$code}->{name} = $record->{description};
        $Data->{cipher_suites}->{$code}->{iana} = 1;
        $Data->{cipher_suites}->{$code}->{dtls} = 1
            if $record->{dtls} eq 'Y';
        for my $list (keys %$lists) {
          if ($lists->{$list}->{$record->{description}}) {
            $Data->{cipher_suites}->{$code}->{$list} = 1;
          }
        }
      } else {
        warn $record->{description};
      }
    }
  }
}

{
  my $path = $root_path->child ('local/mozilla-ciphers.json');
  my $json = json_bytes2perl $path->slurp;
  for (@{$json->{ciphers}}) {
    if ($_->{"hex value"} =~ /^0x([0-9A-Fa-f]+),0x([0-9A-Fa-f]+)$/) {
      my $code = (hex $1) * 0x100 + (hex $2);
      $Data->{cipher_suites}->{$code}->{nss} = $_->{NSS}
          if length $_->{NSS};
      $Data->{cipher_suites}->{$code}->{openssl} = $_->{OpenSSL}
          if length $_->{OpenSSL};
      $Data->{cipher_suites}->{$code}->{gnutls} = $_->{GnuTLS}
          if length $_->{GnuTLS};
    }
  }
}

for (
[0x00,0x03..0x05], # RFC7465
[0x00,0x17..0x18], # RFC7465
[0x00,0x1C], # RFC5246
[0x00,0x1D], # RFC5246
[0x00,0x20], # RFC7465
[0x00,0x24], # RFC7465
[0x00,0x28], # RFC7465
[0x00,0x2B], # RFC7465
[0x00,0x8A], # RFC7465
[0x00,0x8E], # RFC7465
[0x00,0x92], # RFC7465
[0x00,0x47..0x5C], # IANAREG
[0x00,0x60..0x66], # IANAREG
[0xFE,0xFE..0xFF], # IANAREG
) {
  my $f = shift @$_;
  for (@$_) {
    $Data->{cipher_suites}->{$f * 0x100 + $_}->{obsolete} = 1;
  }
}

sub b16 ($) {
  return join '', map { sprintf '%02X', ord $_ } split //, $_[0];
} # b16

{
  my $path = $root_path->child ('local/iana/tls-exts.json');
  my $json = json_bytes2perl $path->slurp;

  for my $record (@{$json->{registries}->{"alpn-protocol-ids"}->{records}}) {
    if ($record->{description} =~ /^(0x[0-9A-Fa-f]+(?:\s+0x[0-9A-Fa-f]+)+)/) {
      my $id = [map { hex $_ } split /\s+/, $1];
      my $id_hex = join '', map { sprintf '%02X', $_ } @$id;
      my $id_str = join '', map { chr $_ } @$id;
      $Data->{alpn_ids}->{$id_hex}->{hex} = $id_hex;
      $Data->{alpn_ids}->{$id_hex}->{string} = $id_str;
      $Data->{alpn_ids}->{$id_hex}->{iana} = 1;
    }
  }

  $Data->{alpn_ids}->{b16 $_}->{hex} ||= b16 $_,
  $Data->{alpn_ids}->{b16 $_}->{string} ||= $_,
  $Data->{alpn_ids}->{b16 $_}->{obsolete} = 1 for qw(
    spdy/1 spdy/2 spdy/3 spdy/3.1 h2-11 h2-12 h2-13 h2-14 h2-15
  );
  $Data->{alpn_ids}->{b16 $_}->{hex} ||= b16 $_,
  $Data->{alpn_ids}->{b16 $_}->{string} ||= $_,
  $Data->{alpn_ids}->{b16 $_}->{reserved} = 1 for qw(h2c);
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
