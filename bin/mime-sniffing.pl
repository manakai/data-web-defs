use strict;
use warnings;
use Regexp::Assemble;
use JSON::PS;

## <https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type>
our @ScriptableSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [ # "<!DOCTYPE HTML "
    "FF FF DF DF DF DF DF DF DF FF DF DF DF DF FF",
    "3C 21 44 4F 43 54 59 50 45 20 48 54 4D 4C TT",
    "text/html", 0,
  ],
  [
    "FF DF DF DF DF FF",
    "3C 48 54 4D 4C TT", # "<HTML "
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF FF",
    "3C 48 45 41 44 TT", # "<HEAD"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF DF DF FF",
    "3C 53 43 52 49 50 54 TT", # "<SCRIPT"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF DF DF FF",
    "3C 49 46 52 41 4D 45 TT", # "<IFRAME"
    "text/html", 1,
  ],
  [
    "FF DF FF FF",
    "3C 48 31 TT", # "<H1"
    "text/html", 1,
  ],
  [
    "FF DF DF DF FF",
    "3C 44 49 56 TT", # "<DIV"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF FF",
    "3C 46 4F 4E 54 TT", # "<FONT"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF DF FF",
    "3C 54 41 42 4C 45 TT", # "<TABLE"
    "text/html", 1,
  ],
  [
    "FF DF FF",
    "3C 41 TT", # "<A"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF DF FF",
    "3C 53 54 59 4C 45 TT", # "<STYLE"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF DF FF",
    "3C 54 49 54 4C 45 TT", # "<TITLE"
    "text/html", 1,
  ],
  [
    "FF DF FF",
    "3C 42 TT", # "<B"
    "text/html", 1,
  ],
  [
    "FF DF DF DF DF FF",
    "3C 42 4F 44 59 TT", # "<BODY"
    "text/html", 1,
  ],
  [
    "FF DF DF FF",
    "3C 42 52 TT", # "<BR"
    "text/html", 1,
  ],
  [
    "FF DF FF",
    "3C 50 TT", # "<P"
    "text/html", 1,
  ],
  [
    "FF FF FF FF",
    "3C 21 2D 2D", # "<!--"
    "text/html", 1,
  ],
  [
    "FF FF FF FF FF",
    "3C 3F 78 6D 6C", # "<?xml"
    "text/xml", 1,
  ],
  [
    "FF FF FF FF FF",
    "25 50 44 46 2D",
    "application/pdf", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type>
our @NonScriptableSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF FF FF FF FF FF FF FF FF FF",
    "25 21 50 53 2D 41 64 6F 62 65 2D",
    "application/postscript", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type>
our @BOM1SniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF 00 00",
    "FE FF 00 00", # UTF-16BE BOM
    "text/plain", 0,
  ],
  [
    "FF FF 00 00",
    "FF FE 00 00", # UTF-16LE BOM
    "text/plain", 0,
  ],
  [
    "FF FF FF 00",
    "EF BB BF 00", # UTF-8 BOM
    "text/plain", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#rules-for-text-or-binary>
our @BOM2SniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF",
    "FE FF", # UTF-16BE BOM
    "text/plain", 0,
  ],
  [
    "FF FF",
    "FF FE", # UTF-16LE BOM
    "text/plain", 0,
  ],
  [
    "FF FF FF",
    "EF BB BF", # UTF-8 BOM
    "text/plain", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#image-type-pattern-matching-algorithm>
my @ImageSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF FF FF",
    "00 00 01 00",
    "image/x-icon", 0,
  ],
  [
    "FF FF FF FF",
    "00 00 02 00",
    "image/x-icon", 0,
  ],
  [
    "FF FF",
    "42 4D",
    "image/bmp", 0,
  ],
  [
    "FF FF FF FF FF FF",
    "47 49 46 38 37 61",
    "image/gif", 0,
  ],
  [
    "FF FF FF FF FF FF",
    "47 49 46 38 39 61",
    "image/gif", 0,
  ],
  [
    "FF FF FF FF 00 00 00 00 FF FF FF FF FF FF",
    "52 49 46 46 00 00 00 00 57 45 42 50 56 50",
    "image/webp", 0,
  ],
  [
    "FF FF FF FF FF FF FF FF",
    "89 50 4E 47 0D 0A 1A 0A",
    "image/png", 0,
  ],
  [
    "FF FF FF",
    "FF D8 FF",
    "image/jpeg", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#audio-or-video-type-pattern-matching-algorithm>
my @AudioOrVideoSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF FF FF",
    "2E 73 6E 64",
    "audio/basic", 0,
  ],
  [
    "FF FF FF FF 00 00 00 00 FF FF FF FF",
    "46 4F 52 4D 00 00 00 00 41 49 46 46",
    "audio/aiff", 0,
  ],
  [
    "FF FF FF",
    "49 44 33",
    "audio/mpeg", 0,
  ],
  [
    "FF FF FF FF FF",
    "4F 67 67 53 00",
    "application/ogg", 0,
  ],
  [
    "FF FF FF FF FF FF FF FF",
    "4D 54 68 64 00 00 00 06",
    "audio/midi", 0,
  ],
  [
    "FF FF FF FF 00 00 00 00 FF FF FF FF",
    "52 49 46 46 00 00 00 00 41 56 49 20",
    "video/avi", 0,
  ],
  [
    "FF FF FF FF 00 00 00 00 FF FF FF FF",
    "52 49 46 46 00 00 00 00 57 41 56 45",
    "audio/wave", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#font-type-pattern-matching-algorithm>
my @FontSniffingTable = (
  [
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 FF FF",
    "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 4C 50",
    "application/vnd.ms-fontobject", 0,
  ],
  [
    "FF FF FF FF",
    "00 01 00 00",
    "font/ttf", 0,
  ],
  [
    "FF FF FF FF",
    "4F 54 54 4F",
    "font/otf", 0,
  ],
  [
    "FF FF FF FF",
    "74 74 63 66",
    "font/collection", 0,
  ],
  [
    "FF FF FF FF",
    "77 4F 46 46",
    "application/font-woff", 0,
  ],
);

## <https://mimesniff.spec.whatwg.org/#archive-type-pattern-matching-algorithm>
my @ArchiveSniffingTable = (
  [
    "FF FF FF",
    "1F 8B 08",
    "application/x-gzip", 0,
  ],
  [
    "FF FF FF FF",
    "50 4B 03 04",
    "application/zip", 0,
  ],
  [
    "FF FF FF FF FF FF FF",
    "52 61 72 20 1A 07 00",
    "application/x-rar-compressed", 0,
  ],
);

my @TextTrackSniffingTable = (
  [
    "FF FF FF FF FF FF",
    "57 45 42 56 54 54",
    "text/vtt", 0,
  ],
);

sub parse ($) {
  my $s = shift;
  return join '', map { pack 'C', hex $_ } split /\s+/, $s;
} # parse

sub bytes ($) {
  my $s = shift;
  return join ' ', map { sprintf '%02X', ord $_ } split //, $s;
} # bytes

sub regexp ($$$) {
  my ($pattern, $mask, $ws) = @_;
  my @r;
  for (0..((length $pattern) - 1)) {
    my $byte = ord substr $pattern, $_, 1;
    my $m = ord substr $mask, $_, 1;
    my $r = '';
    my $last_started = -3;
    my $last_matched = -2;
    for (0x00..0xFF) {
      if (($_ & $m) == $byte) {
        if ($last_matched + 1 == $_) {
          $last_matched = $_;
          $r .= '-\\xFF' if $last_matched == 0xFF;
        } else {
          $r .= sprintf '\\x%02X', $_;
          $last_matched = $last_started = $_;
        }
      } else {
        if ($last_matched + 1 == $_) {
          if ($last_started != $last_matched) {
            $r .= sprintf '-\\x%02X', ord $last_matched;
          }
        }
      }
    }
    die "Empty ($pattern)" unless length $r;
    $r = "[$r]" if $r =~ /-/ or 4 < length $r;
    $r =~ s/\\x(3[0-9]|[46][1-9A-F]|[57][0-9A])/pack 'C', hex $1/ge;
    push @r, $r;
  }
  unshift @r, '[\x09\x0A\x0C\x0D\x20]*' if $ws;
  return join '', @r;
} # regexp

sub _row ($) {
  my @in;
  if ($_[0]->[1] =~ /TT/g) {
    die "There are multiple TTs" if $_[0]->[1] =~ /TT/g;
    for ("20", "3E") { # tag-terminating byte
      my $v = [@{$_[0]}];
      $v->[1] =~ s/TT/$_/;
      push @in, $v;
    }
  } else {
    push @in, $_[0];
  }
  my @out;
  for my $in (@in) {
    $in->[0] = parse $in->[0];
    $in->[1] = parse $in->[1];
    push @out, {
      mask => bytes $in->[0],
      pattern => bytes $in->[1],
      leading_ws => $in->[3],
      regexp => (regexp $in->[1], $in->[0], $in->[3]),
      computed => $in->[2],
    };
  }
  return @out;
} # _row

my $Data = {};
$Data->{tables}->{scriptable} = {defs => [map { _row $_ } @ScriptableSniffingTable]};
$Data->{tables}->{non_scriptable} = {defs => [map { _row $_ } @NonScriptableSniffingTable]};
$Data->{tables}->{bom1} = {defs => [map { _row $_ } @BOM1SniffingTable]};
$Data->{tables}->{bom2} = {defs => [map { _row $_ } @BOM2SniffingTable]};
$Data->{tables}->{image} = {defs => [map { _row $_ } @ImageSniffingTable]};
$Data->{tables}->{audio_or_video} = {defs => [map { _row $_ } @AudioOrVideoSniffingTable]};
$Data->{tables}->{archive} = {defs => [map { _row $_ } @ArchiveSniffingTable]};
$Data->{tables}->{font} = {defs => [map { _row $_ } @FontSniffingTable]};
$Data->{tables}->{text_track} = {defs => [map { _row $_ } @TextTrackSniffingTable]};

for (values %{$Data->{tables}}) {
  my $type_to_regexps = {};
  for (@{$_->{defs}}) {
    push @{$type_to_regexps->{$_->{computed}} ||= []}, $_->{regexp};
  }
  for my $type (keys %$type_to_regexps) {
    my $ra = Regexp::Assemble->new;
    $ra->add ($_) for @{$type_to_regexps->{$type}};
    my $re = $ra->re;
    $re =~ s/([\x00-\x20\x7F-\xFF])/sprintf '\\x%02X', ord $1/ge;
    $_->{regexps}->{$type} = $re;
  }
}

for (
  '74 65 78 74 2F 70 6C 61 69 6E',
  '74 65 78 74 2F 70 6C 61 69 6E 3B 20 63 68 61 72 73 65 74 3D 49 53 4F 2D 38 38 35 39 2D 31',
  '74 65 78 74 2F 70 6C 61 69 6E 3B 20 63 68 61 72 73 65 74 3D 69 73 6F 2D 38 38 35 39 2D 31',
  '74 65 78 74 2F 70 6C 61 69 6E 3B 20 63 68 61 72 73 65 74 3D 55 54 46 2D 38',
) {
  my $bytes = parse $_;
  push @{$Data->{apache_bug_content_types} ||= []}, {
    hex => bytes $bytes,
    chars => $bytes,
  };
}

$Data->{mp3}->{samplerates} = [map { 0+$_ } qw(
  44100 48000 32000
)];

$Data->{mp3}->{mp3rates} = [map { 0+$_ } qw(
  0 32000 40000 48000 56000 64000 80000 96000 112000 128000 160000
  192000 224000 256000 320000
)];

$Data->{mp3}->{mp25rates} = [map { 0+$_ } qw(
  0 8000 16000 24000 32000 40000 48000 56000 64000 80000 96000 112000
  128000 144000 160000
)];

print perl2json_bytes_for_record $Data;

## License: Public Domain.  See doc/mime-sniffing.txt.
