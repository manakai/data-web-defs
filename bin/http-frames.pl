use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;

our $Data = {};

{
  my $json = json_bytes2perl $root_path->child ('local/iana/ws.json')->slurp;

  for my $record (@{$json->{registries}->{'extension-name'}->{records}}) {
    my $id = $record->{id};
    $Data->{ws}->{extensions}->{$id}->{name} = $id;
    $Data->{ws}->{extensions}->{$id}->{iana} = 1;
  }
  for (qw(x-webkit-deflate-frame)) {
    $Data->{ws}->{extensions}->{$_}->{name} = $_;
    $Data->{ws}->{extensions}->{$_}->{obsolete} = 1;
  }
  for (qw(permessage-deflate)) {
    $Data->{ws}->{extensions}->{$_}->{name} = $_;
  }

  for my $record (@{$json->{registries}->{'subprotocol-name'}->{records}}) {
    my $id = $record->{id};
    $Data->{ws}->{protocols}->{$id}->{name} = $id;
    $Data->{ws}->{protocols}->{$id}->{iana} = 1;
  }

  for my $record (@{$json->{registries}->{'close-code-number'}->{records}}) {
    my $id = $record->{value};
    next unless $id =~ /^[0-9]+$/;
    $id += 0;
    $Data->{ws}->{status_codes}->{$id}->{code} = $id;
    $Data->{ws}->{status_codes}->{$id}->{iana} = 1;
    $Data->{ws}->{status_codes}->{$id}->{close} = 1;
  }
  delete $Data->{ws}->{status_codes}->{1004}->{close};
  delete $Data->{ws}->{status_codes}->{1005}->{close};
  delete $Data->{ws}->{status_codes}->{1006}->{close};
  delete $Data->{ws}->{status_codes}->{1015}->{close};
}

{
  my $json = json_bytes2perl $root_path->child ('local/iana/http2.json')->slurp;

  my %ce = map { $_ => 1 } qw(
COMPRESSION_ERROR
ENHANCE_YOUR_CALM
FLOW_CONTROL_ERROR
FRAME_SIZE_ERROR
INADEQUATE_SECURITY
PROTOCOL_ERROR
SETTINGS_TIMEOUT
STREAM_CLOSED
  );
  my %se = map { $_ => 1 } qw(
COMPRESSION_ERROR
CONNECT_ERROR
FLOW_CONTROL_ERROR
PROTOCOL_ERROR
STREAM_CLOSED
REFUSED_STREAM
FRAME_SIZE_ERROR
  );
  for my $record (@{$json->{registries}->{'error-code'}->{records}}) {
    my $id = $record->{value};
    next unless $id =~ /^0x[0-9A-Fa-f]+$/;
    $id = hex $id;
    $Data->{http2}->{error_codes}->{$id}->{code} = $id;
    $Data->{http2}->{error_codes}->{$id}->{name} = $record->{name};
    $Data->{http2}->{error_codes}->{$id}->{iana} = 1;
    $Data->{http2}->{error_codes}->{$id}->{connection_error} = 1
        if $ce{$record->{name}} or $se{$record->{name}};
    $Data->{http2}->{error_codes}->{$id}->{stream_error} = 1
        if $se{$record->{name}};
  }

  for my $record (@{$json->{registries}->{'settings'}->{records}}) {
    my $id = $record->{value};
    next unless $id =~ /^0x[0-9A-Fa-f]+$/;
    $id = hex $id;
    $Data->{http2}->{settings}->{$id}->{code} = $id;
    if ($record->{description} eq 'Reserved') {
      $Data->{http2}->{settings}->{$id}->{reserved} = 1;
    } else {
      $Data->{http2}->{settings}->{$id}->{name} = $record->{description};
    }
    $Data->{http2}->{settings}->{$id}->{iana} = 1;
    if ($record->{initial} =~ /^[0-9]+$/) {
      $Data->{http2}->{settings}->{$id}->{initial_integer} = 0+$record->{initial};
    } elsif ($record->{initial} eq '(infinite)') {
      $Data->{http2}->{settings}->{$id}->{initial_infinity} = 1;
    }
  }
}

require ($root_path->child ('bin/http-frames-hpack.pl')->absolute);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
