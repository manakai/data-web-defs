use strict;
use warnings;
use JSON::PS;

my $Data = {};

for (
  ["animationend", "webkitAnimationEnd"],
  ["animationiteration", "webkitAnimationIteration"],
  ["animationstart", "webkitAnimationStart"],
  ["transitionend", "webkitTransitionEnd"],
) {
  $Data->{event_types}->{$_->[0]}->{legacy} = $_->[1];
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
