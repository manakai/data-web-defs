use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record);

my $Data = {};

$Data->{system_fonts}->{$_}->{conforming} = 1
    for qw(caption icon menu message-box small-caption status-bar);

$Data->{system_fonts}->{$_} ||= {} for qw(
-moz-window -moz-document -moz-desktop -moz-info -moz-dialog
-moz-button -moz-pull-down-menu -moz-list -moz-field
-moz-workspace
);

## <http://msdn.microsoft.com/en-us/library/windows/desktop/ms724947(v=vs.85).aspx>
$Data->{system_fonts}->{icon}->{win32} = ['SPI_GETICONTITLELOGFONT', 0x001F];

## <http://msdn.microsoft.com/en-us/library/windows/desktop/ms724947(v=vs.85).aspx>
## <http://msdn.microsoft.com/en-us/library/windows/desktop/ff729175(v=vs.85).aspx>
for (
  [caption => 'lfCaptionFont'],
  [menu => 'lfMenuFont'],
  ['message-box' => 'lfMessageFont'],
  ['small-caption' => 'lfSmCaptionFont'],
  ['status-bar' => 'lfStatusFont'],
) {
  $Data->{system_fonts}->{$_->[0]}->{win32} = ['SPI_GETNONCLIENTMETRICS', 0x0029, $_->[1]];
}

$Data->{generic_font_families}->{$_}->{conforming} = 1
    for qw(serif sans-serif cursive fantasy monospace);

$Data->{font_family_keywords}->{$_} ||= {}
    for qw(-manakai-default -moz-use-system-font);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
