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

for (
  ["customevent" => "CustomEvent"],
  ["event" => "Event"],
  ["events" => "Event"],
  ["htmlevents" => "Event"],
  ["keyboardevent" => "KeyboardEvent"],
  ["messageevent" => "MessageEvent"],
  ["mouseevent" => "MouseEvent"],
  ["mouseevents" => "MouseEvent"],
  ["touchevent" => "TouchEvent"],
  ["uievent" => "UIEvent"],
  ["uievents" => "UIEvent"],
) {
  $Data->{create_event_string}->{$_->[0]} = $_->[1];
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
