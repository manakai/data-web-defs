use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record);

our $X11Colors = {
                  'aliceblue' =>	[0xf0, 0xf8, 0xff],
                  'antiquewhite' =>	[0xfa, 0xeb, 0xd7],
                  'aqua' =>	[0x00, 0xff, 0xff],
                  'aquamarine' =>	[0x7f, 0xff, 0xd4],
                  'azure' =>	[0xf0, 0xff, 0xff],
                  'beige' =>	[0xf5, 0xf5, 0xdc],
                  'bisque' =>	[0xff, 0xe4, 0xc4],
                  'black' =>	[0x00, 0x00, 0x00],
                  'blanchedalmond' =>	[0xff, 0xeb, 0xcd],
                  'blue' =>	[0x00, 0x00, 0xff],
                  'blueviolet' =>	[0x8a, 0x2b, 0xe2],
                  'brown' =>	[0xa5, 0x2a, 0x2a],
                  'burlywood' =>	[0xde, 0xb8, 0x87],
                  'cadetblue' =>	[0x5f, 0x9e, 0xa0],
                  'chartreuse' =>	[0x7f, 0xff, 0x00],
                  'chocolate' =>	[0xd2, 0x69, 0x1e],
                  'coral' =>	[0xff, 0x7f, 0x50],
                  'cornflowerblue' =>	[0x64, 0x95, 0xed],
                  'cornsilk' =>	[0xff, 0xf8, 0xdc],
                  'crimson' =>	[0xdc, 0x14, 0x3c],
                  'cyan' =>	[0x00, 0xff, 0xff],
                  'darkblue' =>	[0x00, 0x00, 0x8b],
                  'darkcyan' =>	[0x00, 0x8b, 0x8b],
                  'darkgoldenrod' =>	[0xb8, 0x86, 0x0b],
                  'darkgray' =>	[0xa9, 0xa9, 0xa9],
                  'darkgreen' =>	[0x00, 0x64, 0x00],
                  'darkgrey' =>	[0xa9, 0xa9, 0xa9],
                  'darkkhaki' =>	[0xbd, 0xb7, 0x6b],
                  'darkmagenta' =>	[0x8b, 0x00, 0x8b],
                  'darkolivegreen' =>	[0x55, 0x6b, 0x2f],
                  'darkorange' =>	[0xff, 0x8c, 0x00],
                  'darkorchid' =>	[0x99, 0x32, 0xcc],
                  'darkred' =>	[0x8b, 0x00, 0x00],
                  'darksalmon' =>	[0xe9, 0x96, 0x7a],
                  'darkseagreen' =>	[0x8f, 0xbc, 0x8f],
                  'darkslateblue' =>	[0x48, 0x3d, 0x8b],
                  'darkslategray' =>	[0x2f, 0x4f, 0x4f],
                  'darkslategrey' =>	[0x2f, 0x4f, 0x4f],
                  'darkturquoise' =>	[0x00, 0xce, 0xd1],
                  'darkviolet' =>	[0x94, 0x00, 0xd3],
                  'deeppink' =>	[0xff, 0x14, 0x93],
                  'deepskyblue' =>	[0x00, 0xbf, 0xff],
                  'dimgray' =>	[0x69, 0x69, 0x69],
                  'dimgrey' =>	[0x69, 0x69, 0x69],
                  'dodgerblue' =>	[0x1e, 0x90, 0xff],
                  'firebrick' =>	[0xb2, 0x22, 0x22],
                  'floralwhite' =>	[0xff, 0xfa, 0xf0],
                  'forestgreen' =>	[0x22, 0x8b, 0x22],
                  'fuchsia' =>	[0xff, 0x00, 0xff],
                  'gainsboro' =>	[0xdc, 0xdc, 0xdc],
                  'ghostwhite' =>	[0xf8, 0xf8, 0xff],
                  'gold' =>	[0xff, 0xd7, 0x00],
                  'goldenrod' =>	[0xda, 0xa5, 0x20],
                  'gray' =>	[0x80, 0x80, 0x80],
                  'green' =>	[0x00, 0x80, 0x00],
                  'greenyellow' =>	[0xad, 0xff, 0x2f],
                  'grey' =>	[0x80, 0x80, 0x80],
                  'honeydew' =>	[0xf0, 0xff, 0xf0],
                  'hotpink' =>	[0xff, 0x69, 0xb4],
                  'indianred' =>	[0xcd, 0x5c, 0x5c],
                  'indigo' =>	[0x4b, 0x00, 0x82],
                  'ivory' =>	[0xff, 0xff, 0xf0],
                  'khaki' =>	[0xf0, 0xe6, 0x8c],
                  'lavender' =>	[0xe6, 0xe6, 0xfa],
                  'lavenderblush' =>	[0xff, 0xf0, 0xf5],
                  'lawngreen' =>	[0x7c, 0xfc, 0x00],
                  'lemonchiffon' =>	[0xff, 0xfa, 0xcd],
                  'lightblue' =>	[0xad, 0xd8, 0xe6],
                  'lightcoral' =>	[0xf0, 0x80, 0x80],
                  'lightcyan' =>	[0xe0, 0xff, 0xff],
                  'lightgoldenrodyellow' =>	[0xfa, 0xfa, 0xd2],
                  'lightgray' =>	[0xd3, 0xd3, 0xd3],
                  'lightgreen' =>	[0x90, 0xee, 0x90],
                  'lightgrey' =>	[0xd3, 0xd3, 0xd3],
                  'lightpink' =>	[0xff, 0xb6, 0xc1],
                  'lightsalmon' =>	[0xff, 0xa0, 0x7a],
                  'lightseagreen' =>	[0x20, 0xb2, 0xaa],
                  'lightskyblue' =>	[0x87, 0xce, 0xfa],
                  'lightslategray' =>	[0x77, 0x88, 0x99],
                  'lightslategrey' =>	[0x77, 0x88, 0x99],
                  'lightsteelblue' =>	[0xb0, 0xc4, 0xde],
                  'lightyellow' =>	[0xff, 0xff, 0xe0],
                  'lime' =>	[0x00, 0xff, 0x00],
                  'limegreen' =>	[0x32, 0xcd, 0x32],
                  'linen' =>	[0xfa, 0xf0, 0xe6],
                  'magenta' =>	[0xff, 0x00, 0xff],
                  'maroon' =>	[0x80, 0x00, 0x00],
                  'mediumaquamarine' =>	[0x66, 0xcd, 0xaa],
                  'mediumblue' =>	[0x00, 0x00, 0xcd],
                  'mediumorchid' =>	[0xba, 0x55, 0xd3],
                  'mediumpurple' =>	[0x93, 0x70, 0xdb],
                  'mediumseagreen' =>	[0x3c, 0xb3, 0x71],
                  'mediumslateblue' =>	[0x7b, 0x68, 0xee],
                  'mediumspringgreen' =>	[0x00, 0xfa, 0x9a],
                  'mediumturquoise' =>	[0x48, 0xd1, 0xcc],
                  'mediumvioletred' =>	[0xc7, 0x15, 0x85],
                  'midnightblue' =>	[0x19, 0x19, 0x70],
                  'mintcream' =>	[0xf5, 0xff, 0xfa],
                  'mistyrose' =>	[0xff, 0xe4, 0xe1],
                  'moccasin' =>	[0xff, 0xe4, 0xb5],
                  'navajowhite' =>	[0xff, 0xde, 0xad],
                  'navy' =>	[0x00, 0x00, 0x80],
                  'oldlace' =>	[0xfd, 0xf5, 0xe6],
                  'olive' =>	[0x80, 0x80, 0x00],
                  'olivedrab' =>	[0x6b, 0x8e, 0x23],
                  'orange' =>	[0xff, 0xa5, 0x00],
                  'orangered' =>	[0xff, 0x45, 0x00],
                  'orchid' =>	[0xda, 0x70, 0xd6],
                  'palegoldenrod' =>	[0xee, 0xe8, 0xaa],
                  'palegreen' =>	[0x98, 0xfb, 0x98],
                  'paleturquoise' =>	[0xaf, 0xee, 0xee],
                  'palevioletred' =>	[0xdb, 0x70, 0x93],
                  'papayawhip' =>	[0xff, 0xef, 0xd5],
                  'peachpuff' =>	[0xff, 0xda, 0xb9],
                  'peru' =>	[0xcd, 0x85, 0x3f],
                  'pink' =>	[0xff, 0xc0, 0xcb],
                  'plum' =>	[0xdd, 0xa0, 0xdd],
                  'powderblue' =>	[0xb0, 0xe0, 0xe6],
                  'purple' =>	[0x80, 0x00, 0x80],
                  'red' =>	[0xff, 0x00, 0x00],
                  'rosybrown' =>	[0xbc, 0x8f, 0x8f],
                  'royalblue' =>	[0x41, 0x69, 0xe1],
                  'saddlebrown' =>	[0x8b, 0x45, 0x13],
                  'salmon' =>	[0xfa, 0x80, 0x72],
                  'sandybrown' =>	[0xf4, 0xa4, 0x60],
                  'seagreen' =>	[0x2e, 0x8b, 0x57],
                  'seashell' =>	[0xff, 0xf5, 0xee],
                  'sienna' =>	[0xa0, 0x52, 0x2d],
                  'silver' =>	[0xc0, 0xc0, 0xc0],
                  'skyblue' =>	[0x87, 0xce, 0xeb],
                  'slateblue' =>	[0x6a, 0x5a, 0xcd],
                  'slategray' =>	[0x70, 0x80, 0x90],
                  'slategrey' =>	[0x70, 0x80, 0x90],
                  'snow' =>	[0xff, 0xfa, 0xfa],
                  'springgreen' =>	[0x00, 0xff, 0x7f],
                  'steelblue' =>	[0x46, 0x82, 0xb4],
                  'tan' =>	[0xd2, 0xb4, 0x8c],
                  'teal' =>	[0x00, 0x80, 0x80],
                  'thistle' =>	[0xd8, 0xbf, 0xd8],
                  'tomato' =>	[0xff, 0x63, 0x47],
                  'turquoise' =>	[0x40, 0xe0, 0xd0],
                  'violet' =>	[0xee, 0x82, 0xee],
                  'wheat' =>	[0xf5, 0xde, 0xb3],
                  'white' =>	[0xff, 0xff, 0xff],
                  'whitesmoke' =>	[0xf5, 0xf5, 0xf5],
                  'yellow' =>	[0xff, 0xff, 0x00],
                  'yellowgreen' =>	[0x9a, 0xcd, 0x32],
}; # $X11Colors

my $SystemColors = {};

$SystemColors->{lc $_} = {camelcase_name => $_, conforming => 1} for qw(
ActiveBorder ActiveCaption AppWorkspace Background ButtonFace
ButtonHighlight ButtonShadow ButtonText CaptionText GrayText Highlight
HighlightText InactiveBorder InactiveCaption InactiveCaptionText
InfoBackground InfoText Menu MenuText Scrollbar ThreeDDarkShadow
ThreeDFace ThreeDHighlight ThreeDLightShadow ThreeDShadow Window
WindowFrame WindowText
);

## <https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#System_Colors>
$SystemColors->{lc $_} = {camelcase_name => $_} for qw(
-moz-ButtonDefault -moz-ButtonHoverFace -moz-ButtonHoverText
-moz-CellHighlight -moz-CellHighlightText -moz-Combobox -moz-ComboboxText
-moz-Dialog -moz-DialogText -moz-dragtargetzone -moz-EvenTreeRow
-moz-Field -moz-FieldText -moz-html-CellHighlight
-moz-html-CellHighlightText -moz-mac-accentdarkestshadow
-moz-mac-accentdarkshadow -moz-mac-accentface
-moz-mac-accentlightesthighlight -moz-mac-accentlightshadow
-moz-mac-accentregularhighlight -moz-mac-accentregularshadow
-moz-mac-chrome-active -moz-mac-chrome-inactive -moz-mac-focusring
-moz-mac-menuselect -moz-mac-menushadow -moz-mac-menutextselect
-moz-MenuHover -moz-MenuHoverText -moz-MenuBarText -moz-MenuBarHoverText
-moz-nativehyperlinktext -moz-OddTreeRow -moz-win-communicationstext
-moz-win-mediatext
);


my @bgfg = qw{
  ActiveCaption   CaptionText
  ButtonFace      ButtonText
  Highlight       HighlightText
  InactiveCaption InactiveCaptionText
  InfoBackground  InfoText
  Menu            MenuText
  Window          WindowText
  -moz-ButtonHoverFace -moz-ButtonHoverText
  -moz-CellHighlight -moz-CellHighlightText
  -moz-Combobox   -moz-ComboboxText
  -moz-Dialog     -moz-DialogText
  -moz-EvenTreeRow -moz-FieldText
  -moz-Field      -moz-FieldText
  -moz-html-CellHighlight -moz-html-CellHighlightText
  -moz-MenuHover  -moz-MenuHoverText
  -moz-OddTreeRow -moz-FieldText
};
#  -moz-MenuHover  -moz-MenuBarHoverText
while (@bgfg) {
  my $bg = lc shift @bgfg;
  my $fg = lc shift @bgfg;
  $SystemColors->{$bg}->{foreground} = $fg;
}

my @typical = qw(
    ActiveBorder 180,180,180
    ActiveCaption 153,180,209
    AppWorkspace 171,171,171
    Background 0,0,0
    ButtonFace 240,240,240
    ButtonHighlight 255,255,255
    ButtonShadow 160,160,160
    ButtonText 0,0,0
    CaptionText 0,0,0
    GrayText 109,109,109
    Highlight 51,153,255
    HighlightText 255,255,255
    InactiveBorder 244,247,252
    InactiveCaption 191,205,219
    InactiveCaptionText 0,0,0
    InfoBackground 255,255,199
    InfoText 0,0,0
    Menu 240,240,240
    MenuText 0,0,0
    Scrollbar 200,200,200
    ThreeDDarkShadow 105,105,105
    ThreeDFace 240,240,240
    ThreeDHighlight 255,255,255
    ThreeDLightShadow 227,227,227
    ThreeDShadow 160,160,160
    Window 255,255,255
    WindowFrame 100,100,100
    WindowText 0,0,0
);
while (@typical) {
  my $n = shift @typical;
  my $def = [map { 0+$_ } split /,/, shift @typical];
  $SystemColors->{lc $n}->{typical} = $def;
}

## <http://msdn.microsoft.com/en-us/library/windows/desktop/ms724371(v=vs.85).aspx>
my @win32color = qw(
COLOR_3DDKSHADOW 21 COLOR_3DFACE 15 COLOR_3DHIGHLIGHT 20
COLOR_3DHILIGHT 20 COLOR_3DLIGHT 22 COLOR_3DSHADOW 16
COLOR_ACTIVEBORDER 10 COLOR_ACTIVECAPTION 2 COLOR_APPWORKSPACE 12
COLOR_BACKGROUND 1 COLOR_BTNFACE 15 COLOR_BTNHIGHLIGHT 20
COLOR_BTNHILIGHT 20 COLOR_BTNSHADOW 16 COLOR_BTNTEXT 18
COLOR_CAPTIONTEXT 9 COLOR_DESKTOP 1 COLOR_GRADIENTACTIVECAPTION 27
COLOR_GRADIENTINACTIVECAPTION 28 COLOR_GRAYTEXT 17 COLOR_HIGHLIGHT 13
COLOR_HIGHLIGHTTEXT 14 COLOR_HOTLIGHT 26 COLOR_INACTIVEBORDER 11
COLOR_INACTIVECAPTION 3 COLOR_INACTIVECAPTIONTEXT 19 COLOR_INFOBK 24
COLOR_INFOTEXT 23 COLOR_MENU 4 COLOR_MENUHILIGHT 29 COLOR_MENUBAR 30
COLOR_MENUTEXT 7 COLOR_SCROLLBAR 0 COLOR_WINDOW 5 COLOR_WINDOWFRAME 6
COLOR_WINDOWTEXT 8
);
my %win32color;
while (@win32color) {
  my $n = shift @win32color;
  my $c = shift @win32color;
  $win32color{$n} = $c;
}

## <https://github.com/mozilla/gecko-dev/blob/master/widget/windows/nsLookAndFeel.cpp>
my @win32 = qw(
    ActiveBorder      COLOR_ACTIVEBORDER
    ActiveCaption     COLOR_ACTIVECAPTION
    AppWorkspace      COLOR_APPWORKSPACE
    Background        COLOR_BACKGROUND
    ButtonFace        COLOR_BTNFACE
    ButtonHighlight   COLOR_BTNHIGHLIGHT
    ButtonShadow      COLOR_BTNSHADOW
    ButtonText        COLOR_BTNTEXT
    CaptionText       COLOR_CAPTIONTEXT
    GrayText          COLOR_GRAYTEXT
    Highlight         COLOR_HIGHLIGHT
    HighlightText     COLOR_HIGHLIGHTTEXT
    InactiveBorder    COLOR_INACTIVEBORDER
    InactiveCaption   COLOR_INACTIVECAPTION
    InactiveCaptionText COLOR_INACTIVECAPTIONTEXT
    InfoBackground    COLOR_INFOBK
    InfoText          COLOR_INFOTEXT
    Menu              COLOR_MENU
    MenuText          COLOR_MENUTEXT
    Scrollbar         COLOR_SCROLLBAR
    ThreeDDarkShadow  COLOR_3DDKSHADOW
    ThreeDFace        COLOR_3DFACE
    ThreeDHighlight   COLOR_3DHIGHLIGHT
    ThreeDLightShadow COLOR_3DLIGHT
    ThreeDShadow      COLOR_3DSHADOW
    Window            COLOR_WINDOW
    WindowFrame       COLOR_WINDOWFRAME
    WindowText        COLOR_WINDOWTEXT

    -moz-ButtonDefault COLOR_3DDKSHADOW
    -moz-ButtonHoverFace COLOR_BTNFACE
    -moz-ButtonHoverText COLOR_BTNTEXT
    -moz-CellHighlight COLOR_3DFACE
    -moz-CellHighlightText COLOR_WINDOWTEXT
    -moz-Combobox     COLOR_WINDOW
    -moz-ComboboxText COLOR_WINDOWTEXT
    -moz-Dialog       COLOR_3DFACE
    -moz-DialogText   COLOR_WINDOWTEXT
    -moz-dragtargetzone COLOR_HIGHLIGHTTEXT
    -moz-EvenTreeRow  COLOR_WINDOW
    -moz-Field        COLOR_WINDOW
    -moz-FieldText    COLOR_WINDOWTEXT
    -moz-html-CellHighlight COLOR_HIGHLIGHT
    -moz-html-CellHighlightText COLOR_HIGHLIGHTTEXT
    -moz-MenuHover COLOR_HIGHLIGHT
    -moz-MenuHoverText COLOR_HIGHLIGHTTEXT
    -moz-MenuBarText COLOR_MENUTEXT
    -moz-MenuBarHoverText COLOR_HIGHLIGHTTEXT
    -moz-nativehyperlinktext COLOR_HOTLIGHT
    -moz-OddTreeRow  COLOR_WINDOW
    -moz-win-communicationstext COLOR_WINDOWTEXT
    -moz-win-mediatext COLOR_WINDOWTEXT
);
#-moz-mac-accentdarkestshadow
#-moz-mac-accentdarkshadow -moz-mac-accentface
#-moz-mac-accentlightesthighlight -moz-mac-accentlightshadow
#-moz-mac-accentregularhighlight -moz-mac-accentregularshadow
#-moz-mac-chrome-active -moz-mac-chrome-inactive -moz-mac-focusring
#-moz-mac-menuselect -moz-mac-menushadow -moz-mac-menutextselect
while (@win32) {
  my $n = lc shift @win32;
  my $c = shift @win32;
  $SystemColors->{$n}->{win32} = [$c, $win32color{$c}];
}

my $Data = {named_colors => $X11Colors, system_colors => $SystemColors};

$Data->{keywords}->{$_}->{conforming} = 1
    for qw(currentcolor transparent invert);

$Data->{keywords}->{$_} ||= {}
    for qw(
flavor
-manakai-default -manakai-invert-or-currentcolor
),
## <https://developer.mozilla.org/en-US/docs/Web/CSS/color_value#Mozilla_Color_Preference_Extensions>
qw(
-moz-activehyperlinktext -moz-default-background-color
-moz-default-color -moz-hyperlinktext -moz-visitedhyperlinktext
);

$Data->{keywords}->{$_}->{outline_only} = 1
    for qw(invert -manakai-invert-or-currentcolor);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
