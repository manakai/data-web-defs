use strict;
use warnings;
use JSON::PS;

our @ScriptableSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [ # "<!DOCTYPE HTML "
    "\xFF\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xDF\xFF\xDF\xDF\xDF\xDF\xFF",
    "\x3C\x21\x44\x4F\x43\x54\x59\x50\x45\x20\x48\x54\x4D\x4C\x20",
    "text/html", 0, 0,
  ],
  [ # "<!DOCTYPE HTML>"
    "\xFF\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xDF\xFF\xDF\xDF\xDF\xDF\xFF",
    "\x3C\x21\x44\x4F\x43\x54\x59\x50\x45\x20\x48\x54\x4D\x4C\x3E",
    "text/html", 0, 0,
  ],
  [
    "\xFF\xDF\xDF\xDF\xDF\xFF",
    "\x3C\x48\x54\x4D\x4C\x20", # "<HTML "
    "text/html", 1, 0,
  ],
  [
    "\xFF\xDF\xDF\xDF\xDF\xFF",
    "\x3C\x48\x54\x4D\x4C\x3E", # "<HTML>"
    "text/html", 1, 0,
  ],
  # XXX
  [
    "\xFF\xDF\xDF\xDF\xDF",
    "\x3C\x48\x45\x41\x44", # "<HEAD"
    "text/html", 1, 0,
  ],
  # XXX
  [
    "\xFF\xDF\xDF\xDF\xDF\xDF\xDF",
    "\x3C\x53\x43\x52\x49\x50\x54", # "<SCRIPT"
    "text/html", 1, 0,
  ],
  # XXX more
  [
    "\xFF\xFF\xFF\xFF\xFF",
    "\x25\x50\x44\x46\x2D",
    "application/pdf", 0, 0,
  ],
);

our @NonScriptableSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
    "\x25\x21\x50\x53\x2D\x41\x64\x6F\x62\x65\x2D",
    "application/postscript", 0, 1,
  ],
);

our @BOM1SniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [
    "\xFF\xFF\x00\x00",
    "\xFE\xFF\x00\x00", # UTF-16BE BOM
    "text/plain", 0, 0,
  ],
  [
    "\xFF\xFF\x00\x00",
    "\xFF\xFE\x00\x00", # UTF-16LE BOM
    "text/plain", 0, 0,
  ],
  [
    "\xFF\xFF\xFF\x00",
    "\xEF\xBB\xBF\x00", # UTF-8 BOM
    "text/plain", 0, 0,
  ],
);

our @BOM2SniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [
    "\xFF\xFF",
    "\xFE\xFF", # UTF-16BE BOM
    "text/plain", 0, 0,
  ],
  [
    "\xFF\xFF",
    "\xFF\xFE", # UTF-16LE BOM
    "text/plain", 0, 0,
  ],
  [
    "\xFF\xFF\xFF",
    "\xEF\xBB\xBF", # UTF-8 BOM
    "text/plain", 0, 0,
  ],
);

my @ImageSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [
    "\xFF\xFF\xFF\xFF\xFF\xFF",
    "\x47\x49\x46\x38\x37\x61",
    "image/gif", 0, 1,
  ],
  [
    "\xFF\xFF\xFF\xFF\xFF\xFF",
    "\x47\x49\x46\x38\x39\x61",
    "image/gif", 0, 1,
  ],
  [
    "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A",
    "image/png", 0, 1,
  ],
  [
    "\xFF\xFF\xFF",
    "\xFF\xD8\xFF",
    "image/jpeg", 0, 1,
  ],
  [
    "\xFF\xFF",
    "\x42\x4D",
    "image/bmp", 0, 1, 
  ],
  [
    "\xFF\xFF\xFF\xFF",
    "\x00\x00\x01\x00",
    "image/vnd.microsoft.icon", 0, 1,
  ],
  # XXX update
);

my @AudioOrVideoSniffingTable = (
  ## Mask, Pattern, Sniffed Type, Has leading "WS" flag, Security Flag
  ## (1 = Safe, 0 = Otherwise)
  [
    "\xFF\xFF\xFF\xFF",
    "\x2E\x73\x6E\x64",
    "audio/basic", 0, 1,
  ],
  # XXX more
);

my @ArchiveSniffingTable;
my @FontSniffingTable;
my @TextTrackSniffingTable;

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
  my $in = $_[0];
  return {
    mask => bytes $in->[0],
    pattern => bytes $in->[1],
    leading_ws => $in->[3],
    regexp => (regexp $in->[1], $in->[0], $in->[3]),
    computed => $in->[2],
  };
} # _row

my $Data = {};
$Data->{scriptable} = [map { _row $_ } @ScriptableSniffingTable];
$Data->{non_scriptable} = [map { _row $_ } @NonScriptableSniffingTable];
$Data->{bom1} = [map { _row $_ } @BOM1SniffingTable];
$Data->{bom2} = [map { _row $_ } @BOM2SniffingTable];
$Data->{image} = [map { _row $_ } @ImageSniffingTable];
$Data->{audio_or_video} = [map { _row $_ } @AudioOrVideoSniffingTable];
$Data->{archive} = [map { _row $_ } @ArchiveSniffingTable];
$Data->{font} = [map { _row $_ } @FontSniffingTable];
$Data->{text_track} = [map { _row $_ } @TextTrackSniffingTable];

print perl2json_bytes_for_record $Data;
