use strict;
use warnings;
use Encode;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules', '*', 'lib');
use JSON::PS;
use Web::XML::Parser;
use Web::DOM::Document;

my $root_path = path (__FILE__)->parent->parent;

sub parse ($) {
  my $doc = Web::DOM::Document->new;
  my $path = $root_path->child ('local', $_[0]);
  local $/ = undef;
  Web::XML::Parser->new->parse_char_string ($path->slurp_utf8 => $doc);
  return $doc;
} # parse

my $Methods = {};
for (@{(parse 'sw-http-methods.xml')->query_selector_all
           ('table > tbody > tr')}) {
  my $cells = $_->query_selector_all ('td');
  my $method = ($cells->[0] or next)->text_content;
  $method =~ /^\s*([0-9A-Za-z_*-]+)\s*$/ or next;
  $method = $1;
  next if $method eq 'request-method';
  my $protocols = [grep { length $_ }
                   map { {HTCPCP => 'HTTP'}->{$_} // $_ }
                   map { /^\s*([A-Za-z0-9_-]+)/ ? $1 : '' }
                   split /,/, ($cells->[1] ? $cells->[1]->text_content : '')];
  $Methods->{$method}->{protocols}->{$_} = 1 for @$protocols;
  $Methods->{$method}->{wildcard} = 1 if $method =~ /\*/;
}

{
  my $path = $root_path->child ('local/iana/http-methods.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{methods}->{records}}) {
    $Methods->{$record->{value}}->{protocols}->{HTTP} = 1;
    $Methods->{$record->{value}}->{iana}->{HTTP} = 1;
    $Methods->{$record->{value}}->{safe} = 1
        if $record->{safe} eq 'yes';
    $Methods->{$record->{value}}->{idempotent} = 1
        if $record->{idempotent} eq 'yes';
  }
}

for ((map { [$_, 'RTSP'] } @{(parse 'iana/rtsp.xml')->query_selector_all ('registry[id="rtsp-parameters-1"] record')}),
     (map { [$_, 'SIP'] } @{(parse 'iana/sip.xml')->query_selector_all ('registry[id="sip-parameters-6"] record')})) {
  my ($el, $proto) = @$_;
  my $method = ($el->query_selector ('value') or next)->text_content;
  next unless $method =~ /\A[0-9A-Za-z_-]+\z/;
  $Methods->{$method}->{protocols}->{$proto} = 1;
  $Methods->{$method}->{iana}->{$proto} = 1;
}

## <https://fetch.spec.whatwg.org/#simple-method>
$Methods->{$_}->{simple} = 1 for qw(GET HEAD POST);

## <https://fetch.spec.whatwg.org/#concept-method-normalize>
$Methods->{$_}->{case_insensitive} = 1
    for qw(DELETE GET HEAD OPTIONS POST PUT);

## <https://fetch.spec.whatwg.org/#concept-forbidden-methods>
$Methods->{$_}->{xhr_insecure} = 1 for qw(CONNECT TRACE TRACK);

## <https://xhr.spec.whatwg.org/#dom-xmlhttprequest-send>,
## <https://fetch.spec.whatwg.org/#dom-request>
$Methods->{$_}->{xhr_no_request_body} = 1 for qw(GET HEAD);

for (
  ['http-methods.txt' => 'http', 'HTTP'],
  ['icap-methods.txt' => 'icap', 'ICAP'],
  ['shttp-methods.txt' => 's-http', 'S-HTTP'],
  ['ssdp-methods.txt' => 'ssdp', 'SSDP'],
) {
  my ($file_name, $proto, $PROTO) = @$_;
  my $method_name;
  for (split /\x0D?\x0A/, $root_path->child ('src', $file_name)->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*(\S+)\s*$/) {
      my $name = $1;
      $method_name = $name;
      $Methods->{$method_name}->{protocols}->{$PROTO} = 1;
      next;
    } elsif (/\S/) {
      die "Method not defined at first line" unless defined $method_name;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $Methods->{$method_name}->{$proto}->{spec} = "RFC$1";
        $Methods->{$method_name}->{$proto}->{id} = $2;
      } else {
        $Methods->{$method_name}->{$proto}->{url} = $url;
      }
    } elsif (m{^(request-body)\s+(undefined|MAY|MUST|MUST NOT)\s*$}) {
      my $key = $1;
      my $value = $2;
      $key =~ s/-/_/g;
      $Methods->{$method_name}->{$proto}->{$key} = $value;
    } elsif ($proto eq 'http' and m{^(safe|idempotent)\s*$}) {
      my $key = $1;
      $key =~ s/-/_/g;
      $Methods->{$method_name}->{$key} = 1;
    } elsif (m{^(required|ims|range|not-for-representation|write-lock|safe|idempotent|cacheable|obsolete|param body)\s*$}) {
      my $key = $1;
      $key =~ s/[ -]/_/g;
      $Methods->{$method_name}->{$proto}->{$key} = 1;
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
}

print perl2json_bytes_for_record $Methods;

## License: Public Domain.
