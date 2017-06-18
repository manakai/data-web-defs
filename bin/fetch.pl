use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

my $RootPath = path (__FILE__)->parent->parent;
my $Data = {};

$Data->{initiator}->{values}->{$_} = {}
    for '', qw(download imageset manifest xslt);
$Data->{initiator}->{default} = '';
$Data->{initiator}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-initiator>;

$Data->{parser_metadata}->{values}->{$_} = {}
    for '', 'parser-inserted', 'not-parser-inserted';
$Data->{parser_metadata}->{default} = '';
$Data->{parser_metadata}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-parser-metadata>;

$Data->{response_tainting}->{values}->{$_} = {}
    for 'basic', 'cors', 'opaque';
$Data->{response_tainting}->{default} = 'basic';
$Data->{response_tainting}->{url} = q<https://fetch.spec.whatwg.org/#concept-request-response-tainting>;

$Data->{response_type}->{values}->{$_} = {}
    for qw(basic cors default error opaque opaqueredirect);
$Data->{response_type}->{default} = 'default';
$Data->{response_type}->{url} = q<https://fetch.spec.whatwg.org/#concept-response-type>;

$Data->{script_type}->{values}->{$_}->{service_worker_type} = 1,
$Data->{script_type}->{values}->{$_}->{enumerated_attr_state} = $_
    for qw(classic module);
$Data->{script_type}->{default} = 'classic';
$Data->{script_type}->{url} = q<https://w3c.github.io/ServiceWorker/#dfn-type>;
$Data->{script_type}->{invalid_value_default} = 'invalid';
$Data->{script_type}->{missing_value_default} = 'classic';

$Data->{update_via_cache_mode}->{values}->{$_}->{enumerated_attr_state} = $_
    for qw(imports all none);
$Data->{update_via_cache_mode}->{default} = 'imports';
$Data->{update_via_cache_mode}->{url} = q<https://w3c.github.io/ServiceWorker/#dfn-update-via-cache>;
$Data->{update_via_cache_mode}->{invalid_value_default} =
$Data->{update_via_cache_mode}->{missing_value_default} = 'imports';

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
      $Data->{$d->{key}}->{values}->{$_}->{$d->{enum}} = 1;
    }
    $Data->{$d->{key}}->{default} = $d->{default};
    $Data->{$d->{key}}->{url} = $d->{url};
  } # $d
}

$Data->{mode}->{values}->{websocket} ||= {};

for (keys %{$Data->{destination}->{values}}) {
  $Data->{destination}->{values}->{$_}->{destination} = 1
      if $Data->{destination}->{values}->{$_}->{RequestDestination};
  $Data->{destination}->{values}->{$_}->{potential_destination} = 1
      if $Data->{destination}->{values}->{$_}->{destination} and not $_ eq '';
}

## <https://fetch.spec.whatwg.org/#concept-potential-destination>
$Data->{destination}->{values}->{fetch}->{url} = q<https://fetch.spec.whatwg.org/#concept-potential-destination>;
$Data->{destination}->{values}->{fetch}->{potential_destination} = 1;

## <https://html.spec.whatwg.org/#attr-link-as>
for (keys %{$Data->{destination}->{values}}) {
  $Data->{destination}->{values}->{$_}->{enumerated_attr_state} = $_
      if $Data->{destination}->{values}->{$_}->{potential_destination};
}
#$Data->{destination}->{values}->{invalid_value_default} =
#$Data->{destination}->{values}->{missing_value_default} = undef;

## <https://fetch.spec.whatwg.org/#subresource-request>
$Data->{destination}->{values}->{$_}->{subresource} = 1
    for '', qw(audio font image manifest script style track video xslt);

## <https://fetch.spec.whatwg.org/#potential-navigation-or-subresource-request>
$Data->{destination}->{values}->{$_}->{potential_navigation_or_subresource} = 1
    for 'object', 'embed';

## <https://fetch.spec.whatwg.org/#non-subresource-request>
$Data->{destination}->{values}->{$_}->{non_subresource} = 1
    for qw(document report serviceworker sharedworker worker);

## <https://fetch.spec.whatwg.org/#navigation-request>
$Data->{destination}->{values}->{$_}->{navigation} = 1
    for qw(document);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
