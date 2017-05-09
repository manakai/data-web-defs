use strict;
use warnings;
use JSON::PS;

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
  # XXX
  [
    "FF DF DF DF DF",
    "3C 48 45 41 44", # "<HEAD"
    "text/html", 1,
  ],
  # XXX
  [
    "FF DF DF DF DF DF DF",
    "3C 53 43 52 49 50 54", # "<SCRIPT"
    "text/html", 1,
  ],
  # XXX more
  [
    "FF FF FF FF FF",
    "25 50 44 46 2D",
    "application/pdf", 0,
  ],
);

our @NonScriptableSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF FF FF FF FF FF FF FF FF FF",
    "25 21 50 53 2D 41 64 6F 62 65 2D",
    "application/postscript", 0,
  ],
);

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

my @ImageSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
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
    "FF FF FF FF FF FF FF FF",
    "89 50 4E 47 0D 0A 1A 0A",
    "image/png", 0,
  ],
  [
    "FF FF FF",
    "FF D8 FF",
    "image/jpeg", 0,
  ],
  [
    "FF FF",
    "42 4D",
    "image/bmp", 0,
  ],
  [
    "FF FF FF FF",
    "00 00 01 00",
    "image/vnd.microsoft.icon", 0,
  ],
  # XXX update
);

my @AudioOrVideoSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag
  [
    "FF FF FF FF",
    "2E 73 6E 64",
    "audio/basic", 0,
  ],
  # XXX more
);

my @ArchiveSniffingTable;
my @FontSniffingTable;
my @TextTrackSniffingTable;

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

print perl2json_bytes_for_record $Data;
