use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use JSON::PS;
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

for my $doc (parse 'iana-mime-types.xml') {
  for my $el (@{$doc->document_element->children}) {
    next unless $el->local_name eq 'registry';
    my $type = ($el->query_selector ('title') or next)->text_content;
    $type =~ tr/A-Z/a-z/;
    $Data->{"$type/*"}->{type} = 'type';
    $Data->{"$type/*"}->{iana} = 'permanent';
    for my $el (@{$el->children}) {
      next unless $el->local_name eq 'record';
      my $subtype = ($el->query_selector ('name') or next)->text_content;
      my $info = '';
      if ($subtype =~ s/ - (.+)$//) {
        $info = $1;
      }
      $subtype =~ tr/A-Z/a-z/;
      my $dep_el = $el->query_selector ('deprecated');
      my $obs_el = $el->query_selector ('obsolete');
      
      $Data->{"$type/$subtype"}->{type} = 'subtype';
      $Data->{"$type/$subtype"}->{iana} = 'permanent';
      $Data->{"$type/$subtype"}->{deprecated} ||= 'deprecated' if $dep_el;
      $Data->{"$type/$subtype"}->{deprecated} ||= 'deprecated'
          if $info =~ /^DEPRECATED/;
      $Data->{"$type/$subtype"}->{deprecated} ||= 'obsolete' if $obs_el;
      $Data->{"$type/$subtype"}->{deprecated} ||= 'obsolete'
          if $info =~ /^OBSOLETE/;
      if ($info =~ m{in favor of (\S+/\S+)}) {
        $Data->{"$type/$subtype"}->{preferred_type} = lc $1;
      }
      warn "$type/$subtype $info"
          if length $info and not $info =~ /^(?:DEPRECATED|OBSOLETE)/;
    }
  }
}

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
my $attr;
for (file (__FILE__)->dir->parent->subdir ('src')->file ('mime-types.txt')->slurp) {
  if (m{^([0-9A-Za-z_+./*\#-]+)$}) {
    $type = $1;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} ||= $type =~ m{/\*$} ? 'type' : $type =~ m{^\*/\*\+} ? 'suffix' : $type =~ /\*/ ? 'pattern' : 'subtype';
    undef $attr;
    my $t2 = $type;
    $t2 =~ s{/.+$}{/*}s;
    if (not $type eq $t2 and $t2 =~ m{/\*$}) {
      $Data->{$t2} ||= {type => 'type'};
    }
  } elsif (m{^  ([0-9A-Za-z_-]+)$}) {
    $Data->{$type}->{$1} ||= 1;
  } elsif (m{^  ([0-9A-Za-z_.-]+)=""$}) {
    $attr = $1;
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
  } elsif (m{^  ->\s*(\S+)\s*\((SHOULD)\)$}) {
    $Data->{$type}->{deprecated} = $2;
    $Data->{$type}->{preferred_type} = $1;
  } elsif (m{^  #(\S+)$}) {
    $Data->{$type}->{fragment} = $1;
    if ($1 eq 'xpointer:rfc7303') {
      $Data->{$type}->{xpointer_schemes}->{''}->{element} = 'MUST';
      $Data->{$type}->{xpointer_schemes}->{'#'}->{shorthand} = 'MUST';
      $Data->{$type}->{xpointer_schemes}->{'#'}->{other} = 'MAY';
    }
  } elsif (defined $attr and m{^    (\S+)$}) {
    $Data->{$type}->{params}->{$attr}->{$1} = 1;
  } elsif (/\S/) {
    die "Broken line: $_";
  }
}

for (file (__FILE__)->dir->parent->subdir ('src')->file ('mime.types')->slurp) {
  if (/^(\S+)\s+(\S.*)/) {
    my $type = lc $1;
    my $exts = [split /\s+/, lc $2];
    $Data->{$type}->{type} = 'subtype';
    $Data->{$type}->{extensions}->{$_} = 1 for @$exts;
  } elsif (/^(\S+)\s*$/) {
    $Data->{lc $1}->{type} = 'subtype';
  } elsif (/\S/) {
    die "Broken line |$_|";
  }
}

$Data->{'*/*'}->{type} = 'subtype';
for (keys %$Data) {
  if ($Data->{$_}->{params} and $Data->{$_}->{params}->{charset}) {
    $Data->{$_}->{text} = 1 unless m{^(?:text|message/multipart)/};
  }
  $Data->{$_}->{preferred_cte} ||= 'quoted-printable' if $Data->{$_}->{text};
}

for my $type (keys %$Data) {
  $Data->{$type}->{any_xml} = 1 if $Data->{$type}->{xml};
  $Data->{$type}->{text} = 1 if $Data->{$type}->{any_xml};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
