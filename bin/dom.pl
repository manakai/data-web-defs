use strict;
use warnings;
use Path::Class;
use JSON::PS;

my $Data = {};

sub read_text ($$) {
  my ($file_name, $file_key) = @_;
  my $f = file (__FILE__)->dir->parent->file ('src', $file_name);
  my $key;
  for (($f->slurp)) {
    if (/^(\S+)$/) {
      $key = $1;
      $Data->{$file_key}->{$key} ||= {};
    } elsif (/^  ([^=]+)=(.*)$/) {
      $Data->{$file_key}->{$key}->{$1} = $2;
    } elsif (/\S/) {
      die "$file_name: Broken data |$_|";
    }
  }
} # read_text

read_text 'dom-nodes.txt' => 'node_types';

## <http://dom.spec.whatwg.org/#dom-document-createevent>
$Data->{create_event}->{$_->[0]} = $_->[1]
    for
        [customevent => 'CustomEvent'],
        [event => 'Event'],
        [events => 'Event'],
        [htmlevents => 'Event'],
        [keyboardevent => 'KeyboardEvent'],
        [keyevents => 'KeyboardEvent'],
        [messageevent => 'MessageEvent'],
        [mouseevent => 'MouseEvent'],
        [mouseevents => 'MouseEvent'],
        [touchevent => 'TouchEvent'],
        [uievent => 'UIEvent'],
        [uievents => 'UIEvent'];

print perl2json_bytes_for_record $Data;

## License: Public Domain.
