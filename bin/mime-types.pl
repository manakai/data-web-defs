use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Web::XML::Parser;
use Web::DOM::Document;

sub parse ($) {
  my @doc;
  for (glob file (__FILE__)->dir->parent->subdir ('local')->file ($_[0])) {
    my $f = file ($_);
    my $doc = Web::DOM::Document->new;
    local $/ = undef;
    if ($_[0] =~ /html/) {
      $doc->manakai_is_html (1);
      $doc->inner_html (decode 'utf-8', scalar $f->slurp);
    } else {
      Web::XML::Parser->new->parse_char_string
          ((decode 'utf-8', scalar $f->slurp) => $doc);
    }
    push @doc, $doc;
  }
  return @doc;
} # parse

my $Data = {};
for my $doc (parse 'sw-mime-types-xml-*') {
  for (@{$doc->query_selector_all ('table > tbody > tr')}) {
    my $cells = $_->query_selector_all ('td');
    my $type = ($cells->[0] or next)->text_content;
    $type =~ m{^\s*([0-9A-Za-z_+./*-]+)\s*$} or next;
    $type = $1;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type}
        = $type =~ m{\A[^/]*\*[^/]*\z} ? 'type_only_pattern'
        : $type =~ m{\A[^/]+\z} ? 'type_only'
        : $type =~ m{\A[^/*]+/\*\z} ? 'type'
        : $type =~ m{\A\*/\*\+[^/*]+\z} ? 'suffix'
        : $type =~ m{\*} ? 'pattern'
        : 'subtype';
  }
}

for my $doc (parse 'iana-mime-types-html-*') {
  my $type;
  for (@{$doc->query_selector_all ('table > tbody > tr > td > table > tbody > tr')}) {
    my $cells = $_->query_selector_all ('td');
    my $t = ($cells->[0] or next)->text_content;
    if ($t =~ m{^\s*([0-9A-Za-z_+.-]+)\s*$}) {
      $type = $1;
      $Data->{"$type/*"}->{type} = 'type';
      $Data->{"$type/*"}->{iana} = 1;
      next;
    }
    my $subtype = ($cells->[1] or next)->text_content;
    $subtype =~ s{\s*\(deprecated\)\s*$}{}gi;
    $subtype =~ s{\s*\(obsolete\)\s*$}{}gi;
    $subtype =~ m{^\s*([0-9A-Za-z_+.-]+)\s*$} or next;
    $subtype = $1;
    $subtype =~ tr/A-Z/a-z/;
    $Data->{"$type/$subtype"}->{type} = 'subtype';
    $Data->{"$type/$subtype"}->{iana} = 1;
  }
}
$Data->{"example/*"}->{type} = 'type';
$Data->{"example/*"}->{iana} = 1;

for my $doc (parse 'iana-mime-type-suffixes.xml') {
  for (@{$doc->query_selector_all ('registry > registry > record > suffix')}) {
    my $suffix = $_->text_content;
    $suffix =~ /\A\+[0-9A-Za-z_.-]+\z/ or next;
    $suffix =~ tr/A-Z/a-z/;
    $Data->{"*/*$suffix"}->{type} = 'suffix';
    $Data->{"*/*$suffix"}->{iana} = 1;
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
