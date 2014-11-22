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
  my $path = $root_path->child ('local')->child ($_[0]);
  local $/ = undef;
  Web::XML::Parser->new->parse_char_string
      ((decode 'utf-8', scalar $path->slurp) => $doc);
  return $doc;
} # parse

my $StatusCodes = {};
for (@{(parse 'sw-http-statuses.xml')->query_selector_all
           ('table > tbody > tr')}) {
  my $cells = $_->query_selector_all ('td');
  my $code = ($cells->[0] or next)->text_content;
  $code =~ /^\s*([0-9]+)\s*$/ or next;
  $code = $1;
  my $reason = $cells->[1] ? $cells->[1]->text_content : '';
  my $protocols = [grep { length $_ }
                   map { /^\s*([A-Za-z0-9_-]+)/ ? $1 : '' }
                   split /,/, ($cells->[2] ? $cells->[2]->text_content : '')];
  $StatusCodes->{$code}->{conflict} = 1
      if $StatusCodes->{$code} and
         $StatusCodes->{$code}->{reason} ne $reason;
  $StatusCodes->{$code}->{reason} = $reason;
  $StatusCodes->{$code}->{protocols}->{$_} = $reason for @$protocols;
}

for ((map { [$_, 'HTTP'] } @{(parse 'iana-http-statuses.xml')->query_selector_all ('record')}),
     (map { [$_, 'RTSP'] } @{(parse 'iana-rtsp.xml')->query_selector_all ('registry[id="rtsp-parameters-3"] record')}),
     (map { [$_, 'SIP'] } @{(parse 'iana-sip.xml')->query_selector_all ('registry[id="sip-parameters-7"] record')})) {
  my ($el, $proto) = @$_;
  my $code = ($el->query_selector ('value') or next)->text_content;
  next unless $code =~ /\A[0-9]+\z/;
  my $reason = $el->query_selector ('description');
  $reason = $reason ? $reason->text_content : '';
  next if $reason eq 'Unassigned';
  next if $reason eq 'Reserved';
  $reason =~ s/ \(Experimental\)$//;
  $StatusCodes->{$code}->{lc $proto}->{deprecated} = 1
      if $reason =~ s/ \(Deprecated\)$//;
  $StatusCodes->{$code}->{conflict} = 1
      if ($StatusCodes->{$code}->{protocols}->{$proto} and
          $StatusCodes->{$code}->{protocols}->{$proto} ne $reason) or
         (not $StatusCodes->{$code}->{protocols}->{$proto} and
          $StatusCodes->{$code}->{reason} and
          $StatusCodes->{$code}->{reason} ne $reason);
  if ($reason =~ /^\(.+\)$/) {
    $StatusCodes->{$code}->{protocols}->{$proto} ||= $reason;
  } else {
    $StatusCodes->{$code}->{protocols}->{$proto} = $reason;
  }
  $StatusCodes->{$code}->{iana}->{$proto} = 1;
}

for (keys %$StatusCodes) {
  my $proto = $StatusCodes->{$_}->{protocols};
  $StatusCodes->{$_}->{reason}
      = $proto->{HTTP} || $proto->{SIP} || $proto->{RTSP} ||
        $proto->{MRCP} || $StatusCodes->{$_}->{reason} || '';
}

for (
  ['http-status-codes.txt', 'http'],
  ['icap-status-codes.txt', 'icap'],
  ['shttp-status-codes.txt', 's-http'],
  ['ssdp-status-codes.txt', 'ssdp'],
) {
  my ($file_name, $proto) = @$_;
  my $method_name;
  for (split /\x0D?\x0A/, $root_path->child ('src', $file_name)->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^\*\s*([0-9]+)\s*$/) {
      my $name = $1;
      $method_name = $name;
      $StatusCodes->{$method_name} ||= {};
      next;
    } elsif (/^\*\s*([0-9]xx)\s*$/) {
      my $name = $1;
      $method_name = '';
      next;
    } elsif (/\S/) {
      die "Status code not defined at first line" unless defined $method_name;
    }

    if (/^spec\s+(\S+)\s*$/) {
      my $url = $1;
      if ($url =~ m{^https?://tools.ietf.org/html/rfc(\d+)#(.+)$}) {
        $StatusCodes->{$method_name}->{$proto}->{spec} = "RFC$1";
        $StatusCodes->{$method_name}->{$proto}->{id} = $2;
      } else {
        $StatusCodes->{$method_name}->{$proto}->{url} = $url;
      }
    } elsif (/^(cacheable|reserved|obsolete|deprecated)$/) {
      $StatusCodes->{$method_name}->{$proto}->{$1} = 1;
    } elsif (/^redirect$/) {
      $StatusCodes->{$method_name}->{$proto}->{redirect} = 'true';
    } elsif (/^no redirect$/) {
      $StatusCodes->{$method_name}->{$proto}->{redirect} = 'false';
    } elsif (/\S/) {
      die "Bad line: |$_|\n";
    }
  }
}
delete $StatusCodes->{''};

print perl2json_bytes_for_record $StatusCodes;

## License: Public Domain.
