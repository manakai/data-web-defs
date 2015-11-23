use strict;
use warnings;
use JSON::PS;

my $Data = {};

{
  ## <https://html.spec.whatwg.org/#selectors>
  for (qw(

accept accept-charset align alink axis bgcolor charset checked clear
codetype color compact declare defer dir direction disabled enctype
face frame hreflang http-equiv lang language link media method
multiple nohref noresize noshade nowrap readonly rel rev rules scope
scrolling selected shape target text type valign valuetype vlink

  )) {
    $Data->{attr_value_case_insensitive}->{$_} = 1;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

