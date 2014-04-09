use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record);

my $Data = {};

for (path (__FILE__)->parent->parent->child ('src/task-sources.txt')->lines_utf8) {
  if (/^\s*#/) {
    #
  } elsif (/^(~|)([0-9A-Za-z_.: -]+?)(\*|)(?:\[([A-Z0-9:._-]+)\]|)$/) {
    $Data->{task_sources}->{$2} ||= {};
    $Data->{task_sources}->{$2}->{multiple} = 1 if $3;
    $Data->{task_sources}->{$2}->{spec} = $4 if defined $4;
    $Data->{task_sources}->{$2}->{id} = $2 if defined $4 and $4 eq 'HTML';
    $Data->{task_sources}->{$2}->{status} = 'Obsolete' if $1;
  } elsif (/\S/) {
    die "Broken line: $_";
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
