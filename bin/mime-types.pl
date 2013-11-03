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
      $Data->{"$type/*"}->{iana} = 'permanent';
      next;
    }
    my $subtype = ($cells->[1] or next)->text_content;
    $subtype =~ s{\s*\(deprecated\)\s*$}{}gi;
    $subtype =~ s{\s*\(obsolete\)\s*$}{}gi;
    $subtype =~ m{^\s*([0-9A-Za-z_+.-]+)\s*$} or next;
    $subtype = $1;
    $subtype =~ tr/A-Z/a-z/;
    $Data->{"$type/$subtype"}->{type} = 'subtype';
    $Data->{"$type/$subtype"}->{iana} = 'permanent';
  }
}
$Data->{"example/*"}->{type} = 'type';
$Data->{"example/*"}->{iana} = 'permanent';

for my $doc (parse 'iana-mime-type-provisional.xml') {
  for (@{$doc->query_selector_all ('record > name')}) {
    my $type = $_->text_content;
    $type =~ m{\A[0-9A-Za-z_.+/-]+\z} or next;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} = 'subtype';
    $Data->{$type}->{iana} ||= 'provisional';
  }
}

for my $doc (parse 'iana-mime-type-suffixes.xml') {
  for (@{$doc->query_selector_all ('registry > registry > record > suffix')}) {
    my $suffix = $_->text_content;
    $suffix =~ /\A\+[0-9A-Za-z_.-]+\z/ or next;
    $suffix =~ tr/A-Z/a-z/;
    $Data->{"*/*$suffix"}->{type} = 'suffix';
    $Data->{"*/*$suffix"}->{iana} = 'permanent';
  }
}

for (file (__FILE__)->dir->parent->subdir ('local')->file ('apache-mime-types')->slurp) {
  if (m{\A(?:\# )?([0-9A-Za-z_+.-]+/[0-9A-Za-z_+.-]+)\s*([0-9A-Za-z_-][0-9A-Za-z_\s-]*)?\z}) {
    my $type = $1;
    my $exts = [split /\s+/, lc ($2 // '')];
    $Data->{$type}->{type} ||= 'subtype';
    $Data->{$type}->{extensions}->{$_} = 1 for @$exts;
  }
}

my $type;
for (file (__FILE__)->dir->parent->subdir ('src')->file ('mime-types.txt')->slurp) {
  if (m{^([0-9A-Za-z_+./*-]+)$}) {
    $type = $1;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} ||= $type =~ m{/\*$} ? 'type' : $type =~ m{^\*/\*\+} ? 'suffix' : $type =~ /\*/ ? 'pattern' : 'subtype';
  } elsif (m{^  ([0-9A-Za-z_-]+)$}) {
    $Data->{$type}->{$1} ||= 1;
  } elsif (m{^  ([0-9A-Za-z_-]+)=""$}) {
    my $attr = $1;
    $attr =~ tr/A-Z/a-z/;
    $Data->{$type}->{params}->{$attr} ||= {};
  } elsif (m{^  ([0-9A-Za-z_-]+):(\S+)$}) {
    $Data->{$type}->{$1} ||= $2;
  } elsif (m{^  ([0-9A-Za-z_-]+)\@(.+)$}) {
    my $prop = $1;
    my $values = [split /\s+/, $2];
    if ($prop eq 'mac') {
      $prop = 'mac_types';
      $values = [map { substr ($_ . '   ', 0, 4) } @$values];
    } elsif ($prop eq 'mac_creator') {
      $prop = 'mac_creator';
    } elsif ($prop eq 'ext') {
      $prop = 'extensions';
    }
    $Data->{$type}->{$prop}->{$_} = 1 for @$values;
  } elsif (/\S/) {
    die "Broken line: $_";
  }
}

$Data->{'*/*'}->{type} = 'subtype';
for (keys %$Data) {
  if ($Data->{$_}->{params} and $Data->{$_}->{params}->{charset}) {
    $Data->{$_}->{text} = 1 unless m{^(?:text|message/multipart)/};
  }
  $Data->{$_}->{preferred_cte} ||= 'quoted-printable' if $Data->{$_}->{text};
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
