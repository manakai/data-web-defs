use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $RootPath = path (__FILE__)->parent->parent;
my $DataPath = $RootPath->child ('intermediate/ua-names.json');

my $Data = json_bytes2perl $DataPath->slurp;

{
  my $VAR1;
  my $data = do {
    eval $RootPath->child ('local/ua-names.pl')->slurp;
  } or die $@;
  for (
    ['chrome',  'desktop', 'windows', 'chrome,windows'],
    ['chrome',  'desktop', 'mac',     'chrome,mac'],
    ['chrome',  'desktop', 'linux',   'chrome,linux'],
    ['chrome',  'tablet',  'android', 'chrome,android'],
    ['chrome',  'mobile',  'android', 'chrome,mobile,android'],

    ['gecko',   'desktop', 'windows', 'firefox,windows'],
    ['gecko',   'desktop', 'mac',     'firefox,mac'],
    ['gecko',   'desktop', 'linux',   'firefox,linux'],
    ['gecko',   'tablet',  'android', 'firefox,tablet,android'],
    ['gecko',   'mobile',  'android', 'firefox,mobile,android'],

    ['webkit',  'desktop', 'mac',     'webkit,mac'],
    ['webkit',  'tablet',  'ipad',    'webkit,tablet,ios'],
    ['webkit',  'mobile',  'iphone',  'webkit,mobile,ios'],
  ) {
    my ($mode, $type, $os, $key) = @$_;
    my $value = $data->{$key};
    $Data->{$type}->{$os}->{$mode} = $value if defined $value;
  }
}

$DataPath->spew (perl2json_bytes_for_record $Data);

## License: Public Domain.
