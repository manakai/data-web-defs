use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $RootPath = path (__FILE__)->parent->parent;
my $Data = {};

$Data->{initiator}->{$_}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-initiator>
    for '', qw(download imageset manifest xslt);
$Data->{initiator}->{''}->{default} = 1;

$Data->{parser_metadata}->{$_}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-parser-metadata>
    for '', 'parser-inserted', 'not-parser-inserted';
$Data->{parser_metadata}->{''}->{default} = 1;

$Data->{response_tainting}->{$_}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-response-tainting>
    for 'basic', 'cors', 'opaque';
$Data->{response_tainting}->{basic}->{default} = 1;

$Data->{response_type}->{$_}->{url} = q<https://fetch.spec.whatwg.org/#concept-response-type>
    for qw(basic cors default error opaque opaqueredirect);
$Data->{response_type}->{default}->{default} = 1;

{
  my $path = $RootPath->child ('data/dom.json');
  my $json = json_bytes2perl $path->slurp;

  for my $d (
    {key => 'type',
     enum => 'RequestType',
     url => 'https://fetch.spec.whatwg.org/#concept-request-type',
     default => ''},
    {key => 'destination',
     enum => 'RequestDestination',
     url => 'https://fetch.spec.whatwg.org/#concept-request-destination',
     default => ''},
    {key => 'mode',
     enum => 'RequestMode',
     url => 'https://fetch.spec.whatwg.org/#concept-request-mode',
     default => 'no-cors'},
    {key => 'credentials_mode',
     enum => 'RequestCredentials',
     url => 'https://fetch.spec.whatwg.org/#concept-request-credentials-mode',
     default => 'omit'},
    {key => 'cache_mode',
     enum => 'RequestCache',
     url => 'https://fetch.spec.whatwg.org/#concept-request-cache-mode',
     default => 'default'},
    {key => 'redirect_mode',
     enum => 'RequestRedirect',
     url => 'https://fetch.spec.whatwg.org/#concept-request-redirect-mode',
     default => 'follow'},
  ) {
    my $rd = $json->{idl_defs}->{$d->{enum}};
    my $v = $rd->[1]->{value};
    for (sort { $a cmp $b } keys %{$v->[1]}) {
      $Data->{$d->{key}}->{$_}->{url} = $d->{url};
      $Data->{$d->{key}}->{$_}->{$d->{enum}} = 1;
    }
    $Data->{$d->{key}}->{$d->{default}}->{default} = 1;
  } # $d
}

$Data->{mode}->{websocket}->{url} = 'https://fetch.spec.whatwg.org/#concept-request-mode';

for (keys %{$Data->{destination}}) {
  $Data->{destination}->{$_}->{destination} = 1
      if $Data->{destination}->{$_}->{RequestDestination};
  $Data->{destination}->{$_}->{potential_destination} = 1
      if $Data->{destination}->{$_}->{destination} and not $_ eq '';
}

## <https://fetch.spec.whatwg.org/#concept-potential-destination>
$Data->{destination}->{fetch}->{url} = q<https://fetch.spec.whatwg.org/#concept-potential-destination>;
$Data->{destination}->{fetch}->{potential_destination} = 1;

## <https://fetch.spec.whatwg.org/#subresource-request>
$Data->{destination}->{$_}->{subresource} = 1
    for '', qw(audio font image manifest script style track video xslt);

## <https://fetch.spec.whatwg.org/#potential-navigation-or-subresource-request>
$Data->{destination}->{$_}->{potential_navigation_or_subresource} = 1
    for 'object', 'embed';

## <https://fetch.spec.whatwg.org/#non-subresource-request>
$Data->{destination}->{$_}->{non_subresource} = 1
    for qw(document report serviceworker sharedworker worker);

## <https://fetch.spec.whatwg.org/#navigation-request>
$Data->{destination}->{$_}->{navigation} = 1
    for qw(document);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
