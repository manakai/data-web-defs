use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Encode;
use Web::HTML::Parser;
use Web::DOM::Document;

sub get_url ($) {
  my $url = shift;
  return scalar `curl \Q$url\E`;
} # get_url

sub uunescape ($) {
  my $s = decode 'utf-8', shift;
  $s =~ s{\s+$}{}s;
  $s =~ s{^\s+}{}s;
  $s =~ s{\\$}{ }ge;
  $s =~ s{\\?\\u([0-9A-Fa-f]{4})}{chr hex $1}ge;
  $s =~ s{u0020$}{ }ge;
  return decode 'utf-16le', encode 'ucs-2le', $s;
} # uunescape

sub htunescape ($) {
  my $s = decode 'utf-8', shift;
  $s =~ s/&lt;/</g;
  $s =~ s/&gt;/</g;
  $s =~ s/&quot;/"/g;
  $s =~ s/&amp;/&/g;
  return $s;
} # htunescape

my $Data;

## Gecko
{
  my $en = get_url q<https://raw.github.com/mozilla/gecko-dev/master/dom/locales/en-US/chrome/layout/HtmlForm.properties>;
  if ($en =~ /^IsIndexPromptWithSpace\s*=(.+)/m) {
    $Data->{'en'}->{gecko} = uunescape $1;
  } else {
    die "Can't get Gecko |en| data";
  }

  my $doc = new Web::DOM::Document;
  my $parser = new Web::HTML::Parser;
  $parser->parse_byte_string (undef, (get_url q<https://hg.mozilla.org/l10n-central/>) => $doc);
  my @locale = map { $_->text_content } @{$doc->query_selector_all ('a.list > b')};
  die "Can't get Gecko locale list" unless @locale;
  for my $locale (@locale) {
    my $data = get_url qq<https://hg.mozilla.org/l10n-central/$locale/raw-file/tip/dom/chrome/layout/HtmlForm.properties>;
    if ($data =~ /^IsIndexPromptWithSpace\s*=(.+)/m) {
      $Data->{lc $locale}->{gecko} = uunescape $1;
    }
    sleep 1;
  }
}

## Chromium
{
  my $doc = new Web::DOM::Document;
  my $parser = new Web::HTML::Parser;
  $parser->parse_byte_string (undef, (get_url q<http://src.chromium.org/viewvc/chrome/trunk/src/webkit/glue/resources/>) => $doc);
  my @locale = map { $_->text_content =~ /webkit_strings_([\w-]+)\.xtb/ ? ($1) : () } @{$doc->query_selector_all ('td:first-child a')};
  die "Can't get Chromium locale list" unless @locale;
  for my $locale (@locale) {
    my $data = get_url qq<https://raw.github.com/mirror/chromium/trunk/webkit/glue/resources/webkit_strings_$locale.xtb>;
    if ($data =~ m{<translation\s+id=["']8141602879876242471["']\s*>(.+?)</translation\s*>}s) {
      $Data->{lc $locale}->{chromium} = htunescape $1;
    }
    sleep 1;
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
