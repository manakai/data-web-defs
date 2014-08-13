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
                   map { /^\s*([A-Za-z0-9_-]+)/ ? $1 : '' }
                   split /,/, ($cells->[1] ? $cells->[1]->text_content : '')];
  $Methods->{$method}->{protocols}->{$_} = 1 for @$protocols;
  $Methods->{$method}->{wildcard} = 1 if $method =~ /\*/;
}

for ((map { [$_, 'RTSP'] } @{(parse 'iana-rtsp.xml')->query_selector_all ('registry[id="rtsp-parameters-1"] record')}),
     (map { [$_, 'SIP'] } @{(parse 'iana-sip.xml')->query_selector_all ('registry[id="sip-parameters-6"] record')})) {
  my ($el, $proto) = @$_;
  my $method = ($el->query_selector ('value') or next)->text_content;
  next unless $method =~ /\A[0-9A-Za-z_-]+\z/;
  $Methods->{$method}->{protocols}->{$proto} = 1;
  $Methods->{$method}->{iana}->{$proto} = 1;
}

## <http://fetch.spec.whatwg.org/#simple-method>
$Methods->{$_}->{simple} = 1 for qw(GET HEAD POST);

## <http://fetch.spec.whatwg.org/#concept-method-normalize>
$Methods->{$_}->{case_insensitive} = 1
    for qw(DELETE GET HEAD OPTIONS POST PUT);

## <http://fetch.spec.whatwg.org/#concept-forbidden-methods>
$Methods->{$_}->{xhr_insecure} = 1 for qw(CONNECT TRACE TRACK);

## <http://xhr.spec.whatwg.org/#dom-xmlhttprequest-send>
$Methods->{$_}->{xhr_no_request_body} = 1 for qw(GET HEAD);

## <http://tools.ietf.org/html/rfc2616#section-9.1.1>
#$Methods->{$_}->{safe} = 1 for qw(GET HEAD);
## <https://tools.ietf.org/html/rfc7231#section-4.2.1>
## <https://tools.ietf.org/html/rfc7231#section-4.2.2>
$Methods->{$_}->{safe} = 1,
$Methods->{$_}->{idempotent} = 1
    for qw(GET HEAD OPTIONS TRACE);

## <http://tools.ietf.org/html/rfc2616#section-9.1.2>
#$Methods->{$_}->{idempotent} = 1 for qw(GET HEAD PUT DELETE TRACE OPTIONS);
## <https://tools.ietf.org/html/rfc7231#section-4.2.2>
$Methods->{$_}->{idempotent} = 1 for qw(PUT DELETE);

## <https://tools.ietf.org/html/rfc7231#section-4.2.3>
$Methods->{$_}->{cacheable} = 1 for qw(GET HEAD POST);

## <https://tools.ietf.org/html/rfc7231#page-22>
$Methods->{$_}->{required} = 1 for qw(GET HEAD);

my $method_name;
for (split /\x0D?\x0A/, $root_path->child ('src', 'http-methods.txt')->slurp_utf8) {
  if (/^\s*#/) {
    next;
  } elsif (/^\*\s*(\S+)\s*$/) {
    my $name = $1;
    $method_name = $name;
    $Methods->{$method_name} ||= {};
    next;
  } elsif (/\S/) {
    die "Method not defined at first line" unless defined $method_name;
  }

  if (/^spec\s+(\S+)\s*$/) {
    my $url = $1;
    if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
      $Methods->{$method_name}->{spec} = "RFC$1";
      $Methods->{$method_name}->{id} = $2;
    } else {
      $Methods->{$method_name}->{url} = $url;
    }
  } elsif (m{^(request-body)\s+(undefined|MAY|MUST|MUST NOT)\s*$}) {
    my $key = $1;
    my $value = $2;
    $key =~ s/-/_/g;
    $Methods->{$method_name}->{$key} = $value;
  } elsif (m{^(XXX)\s*$}) {
    my $key = $1;
    $key =~ s/-/_/g;
    $Methods->{$method_name}->{$key} = 1;
  } elsif (/\S/) {
    die "Bad line: |$_|\n";
  }
}

print perl2json_bytes_for_record $Methods;

## License: Public Domain.
