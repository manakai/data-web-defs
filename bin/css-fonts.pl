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

{
  use utf8;
  for (
    {name => "MS PGothic",
     url => q<http://www.microsoft.com/typography/fonts/font.aspx?FMID=1271>},
    {name => "IPAMonaPGothic",
     url => q<http://www.geocities.jp/ipa_mona/>},
    {name => "Monapo",
     url => q<http://www.geocities.jp/ep3797/modified_fonts_01.html>},
    {name => "Mona",
     url => q<http://monafont.sourceforge.net/>},
    {name => "小夏",
     url => q<http://www.masuseki.com/?u=be/konatu.htm>},
  ) {
    push @{$Data->{aa_2ch_font_family} ||= []}, $_->{name};
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
