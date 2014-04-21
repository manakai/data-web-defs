use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use JSON::PS;
use Web::XML::Parser;
use Web::DOM::Document;

sub parse ($) {
  my $doc = Web::DOM::Document->new;
  my $f = file (__FILE__)->dir->parent->subdir ('local')->file ($_[0]);
  local $/ = undef;
  Web::XML::Parser->new->parse_char_string
      ((decode 'utf-8', scalar $f->slurp) => $doc);
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

## <http://xhr.spec.whatwg.org/#dom-xmlhttprequest-open>
$Methods->{$_}->{case_insensitive} = 1
    for qw(CONNECT DELETE GET HEAD OPTIONS POST PUT TRACE TRACK);

## <http://fetch.spec.whatwg.org/#concept-forbidden-methods>
$Methods->{$_}->{xhr_insecure} = 1 for qw(CONNECT TRACE TRACK);

## <http://xhr.spec.whatwg.org/#dom-xmlhttprequest-send>
$Methods->{$_}->{xhr_no_request_body} = 1 for qw(GET HEAD);

## <http://tools.ietf.org/html/rfc2616#section-9.1.1>
$Methods->{$_}->{safe} = 1 for qw(GET HEAD);

## <http://tools.ietf.org/html/rfc2616#section-9.1.2>
$Methods->{$_}->{idempotent} = 1 for qw(GET HEAD PUT DELETE TRACE OPTIONS);

print perl2json_bytes_for_record $Methods;

## License: Public Domain.
