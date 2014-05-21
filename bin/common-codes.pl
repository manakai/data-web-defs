use strict;
use warnings;
use JSON::PS;

local $/ = undef;
my $rec20 = json_bytes2perl <>;

print join ' ', sort { $a cmp $b } keys %$rec20;

## License: Public Domain.
