use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Web::XML::Parser;
use Web::DOM::Document;

my $Data = {};

for my $data (
  {key => 'specs', file_name => 'specs.txt'},
  {key => 'statuses', file_name => 'spec-statuses.txt'},
  {key => 'groups', file_name => 'spec-groups.txt'},
  {key => 'generators', file_name => 'spec-generators.txt'},
) {
  my $key;
  for ((file (__FILE__)->dir->parent->subdir ('src')->file ($data->{file_name})->slurp)) {
    if (/^(\S.*)$/) {
      $key = $1;
      $Data->{$data->{key}}->{$key} ||= {};
    } elsif (/^  ([^\s=]+)=(.*)/) {
      $Data->{$data->{key}}->{$key}->{$1} = $2;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
