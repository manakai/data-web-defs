use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'html-extracted.json');
  my $json = file2perl $f;
  for my $el_name (keys %{$json->{elements}}) {
    my $in = $json->{elements}->{$el_name};
    my $prop = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} ||= {};
    $prop->{conforming} = 1;
    for (qw(desc start_tag end_tag id)) {
      $prop->{$_} = $in->{$_} if defined $in->{$_};
    }
    if ($in->{content_model}) {
      if (not $in->{content_model}->{_complex} and
          1 == keys %{$in->{content_model}}) {
        $prop->{content_model} = each %{$in->{content_model}};
      }
    }
    for (keys %{$in->{categories} or {}}) {
      next if $_ eq '_complex';
      $Data->{categories}->{$_}->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} = 1;
    }
    for my $attr_name (keys %{$in->{attrs} or {}}) {
      my $i = $in->{attrs}->{$attr_name};
      my $p = $prop->{attrs}->{''}->{$attr_name} ||= {};
      $p->{conforming} = 1;
      $p->{desc} = $i->{desc} if defined $i->{desc};
      $p->{id} = $i->{id} if defined $i->{id};
    }
  }
  for my $attr_name (keys %{$json->{global_attrs} or {}}) {
    my $prop = $json->{global_attrs}->{$attr_name};
    my $p = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr_name} ||= {};
    $p->{conforming} = 1;
    $p->{desc} = $prop->{desc} if defined $prop->{desc};
    $p->{id} = $prop->{id} if defined $prop->{id};
  }
}

for my $attr_name (keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}}) {
  next unless $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{id} =~ /^handler-/;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{frameset}->{attrs}->{''}->{$attr_name}->{id} = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{id};
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{frameset}->{attrs}->{''}->{$attr_name}->{desc} = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{desc};
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'element-interfaces.txt');
  my $ns = '';
  my $ln = '*';
  for (($f->slurp)) {
    if (/^\@ns (\S+)$/) {
      $ns = $1;
    } elsif (/^(\S+)\s(\S+)$/) {
      $ln = $1;
      $Data->{elements}->{$ns}->{$ln}->{interface} = $2;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'elements.txt');
  for (($f->slurp)) {
    if (/^([^=]+)=(.+)$/) {
      my $value = $2;
      my @path = split /\|/, $1, -1;
      my $name = pop @path;
      my $data = $Data;
      for (@path) {
        $data = $data->{$_} ||= {};
      }
      $data->{$name} = $value;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

use Encode;
use Web::DOM::Document;
use Web::XML::Parser;
my $statuses = {};
{
  my $doc = Web::DOM::Document->new;
  {
    my $f = file (__FILE__)->dir->parent->file ('local', 'html-status.xml');
    Web::XML::Parser->new->parse_char_string
        ((decode 'utf-8', scalar $f->slurp) => $doc);
  }
  for (@{$doc->query_selector_all ('annotations > entry[section][status]')}) {
    $statuses->{$_->get_attribute ('section')} = $_->get_attribute ('status');
  }
}

my $id_for_status = {
  'attr-lang' => 'the-lang-and-xml:lang-attributes',
  'attr-translate' => 'global-attributes', # ...
  'attr-class' => 'classes',
  'attr-hyperlink-href' => 'links',
  'attr-hyperlink-target' => 'links',
  'attr-hyperlink-ping' => 'links',
  'attr-hyperlink-rel' => 'links',
  'attr-hyperlink-hreflang' => 'links',
  'attr-hyperlink-type' => 'links',
  'attr-hyperlink-usemap' => 'authoring',
  'attr-link-sizes' => 'rel-icon',
  'attr-media-src' => 'location-of-the-media-resource',
  'attr-media-crossorigin' => 'location-of-the-media-resource',
  'attr-media-preload' => 'loading-the-media-resource',
  'attr-media-loop' => 'offsets-into-the-media-resource',
  'attr-media-autoplay' => 'media-elements', # ...
  'attr-media-mediagroup' => 'synchronising-multiple-media-elements', # ...
  'attr-media-controls' => 'user-interface',
  'attr-media-muted' => 'user-interface',
  #attr-input-accept => ... the-input-element
  #attr-input-src => ... the-input-element
  #attr-input-alt => ... the-input-element
  'attr-input-maxlength' => 'common-input-element-attributes', # ...
  'attr-input-minlength' => 'common-input-element-attributes', # ...
  'attr-input-size' => 'the-size-attribute',
  'attr-input-readonly' => 'the-readonly-attribute',
  'attr-input-required' => 'the-required-attribute',
  'attr-input-multiple' => 'the-multiple-attribute',
  'attr-input-pattern' => 'the-pattern-attribute',
  'attr-input-min' => 'the-min-and-max-attributes',
  'attr-input-max' => 'the-min-and-max-attributes',
  'attr-input-step' => 'the-step-attribute',
  'attr-input-list' => 'the-list-attribute',
  'attr-input-placeholder' => 'the-placeholder-attribute',
  'attr-fae-form' => 'association-of-controls-and-forms',
  'attr-fe-name' => 'attributes-common-to-form-controls', # ...
  'attr-fe-dirname' => 'attributes-common-to-form-controls', # ...
  'attr-fe-disabled' => 'attributes-common-to-form-controls', # ...
  'attr-fs-action' => 'form-submission-0',
  'attr-fs-formaction' => 'form-submission-0',
  'attr-fs-method' => 'form-submission-0',
  'attr-fs-formmethod' => 'form-submission-0',
  'attr-fs-enctype' => 'form-submission-0',
  'attr-fs-formenctype' => 'form-submission-0',
  'attr-fs-target' => 'form-submission-0',
  'attr-fs-formtarget' => 'form-submission-0',
  'attr-fs-novalidate' => 'form-submission-0',
  'attr-fs-formnovalidate' => 'form-submission-0',
  'attr-fe-autofocus' => 'attributes-common-to-form-controls', # ...
  'attr-fe-inputmode' => 'attributes-common-to-form-controls', # ...
  'attr-fe-autocomplete' => 'autofilling-form-controls:-the-autocomplete-attribute',
  'attr-mod-cite' => 'attributes-common-to-ins-and-del-elements',
  'attr-mod-datetime' => 'attributes-common-to-ins-and-del-elements',
  'attr-dim-width' => 'dimension-attributes',
  'attr-dim-height' => 'dimension-attributes',
  'attr-meta-http-equiv' => 'pragma-directives',
  'attr-table-sortable' => 'table-sorting-model',
  'attr-tdth-colspan' => 'attributes-common-to-td-and-th-elements',
  'attr-tdth-rowspan' => 'attributes-common-to-td-and-th-elements',
  'attr-tdth-headers' => 'attributes-common-to-td-and-th-elements',
  'attr-contenteditable' => 'contenteditable',
  'attr-contextmenu' => 'context-menus',
  'attr-inert' => 'inert-subtrees', # the-inert-attribute
  'attr-spellcheck' => 'spelling-and-grammar-checking',
  'attr-tabindex' => 'focus', # ...
  'attr-itemscope' => 'items',
  'attr-itemtype' => 'items',
  'attr-itemid' => 'items',
  'attr-itemref' => 'items',
  'attr-itemprop' => 'names:-the-itemprop-attribute',
  'attr-img-border' => 'obsolete-but-conforming-features',
  'attr-script-language' => 'obsolete-but-conforming-features',
  'attr-a-name' => 'obsolete-but-conforming-features',
};

for my $ns (keys %{$Data->{elements}}) {
  for my $ln (keys %{$Data->{elements}->{$ns}}) {
    my $v = $Data->{elements}->{$ns}->{$ln};
    if ($v->{id} and $statuses->{$v->{id}}) {
      $v->{status} ||= $statuses->{$v->{id}};
      delete $v->{status} if $v->{status} eq 'UNKNOWN';
    }

    for my $ans (keys %{$v->{attrs} || {}}) {
      for my $aln (keys %{$v->{attrs}->{$ans}}) {
        my $w = $v->{attrs}->{$ans}->{$aln};
        if ($w->{id} and $statuses->{$w->{id}}) {
          $w->{status} ||= $statuses->{$w->{id}};
        } elsif ($w->{id} and $id_for_status->{$w->{id}} and
                 $statuses->{$id_for_status->{$w->{id}}}) {
          $w->{status} ||= $statuses->{$id_for_status->{$w->{id}}};
        } elsif ($w->{id} and $w->{id} =~ /^handler-/) {
          $w->{status} ||= $statuses->{'event-handlers-on-elements,-document-objects,-and-window-objects'};
          $w->{value_type} ||= 'event handler';
        } elsif ($ans eq '' and $statuses->{"the-$aln-attribute"}) {
          $w->{status} ||= $statuses->{"the-$aln-attribute"};
        }
        delete $w->{status} if defined $w->{status} and $w->{status} eq 'UNKNOWN';
        $w->{status} ||= $v->{status} if defined $v->{status};
      }
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'attr-types.txt');
  my $ns;
  my $last_attr;
  for (($f->slurp)) {
    if (/^\@ns (\S+)$/) {
      $ns = $1;
    } elsif (/^(\S+)\s+(\S+)\s+(.+)$/) {
      $last_attr = $Data->{elements}->{$ns}->{$1}->{attrs}->{''}->{$2} ||= {};
      $last_attr->{value_type} = $3;
    } elsif (/^  (\S+)\s+(\S+)\s+(.+)$/) {
      my ($keyword, $id, $label) = ($1, $2, $3);
      my $canonical = $label =~ s/\s*!s*$//;
      $keyword = '' if $keyword eq '#empty';
      my $invalid = $label =~ s/\s+X\s*$// || $keyword =~ /^#/;
      $last_attr->{enumerated}->{$keyword}->{id} = $id if $id ne '-';
      $last_attr->{enumerated}->{$keyword}->{label} = $label if $label ne '-';
      $last_attr->{enumerated}->{$keyword}->{canonical} = 1 if $canonical;
      $last_attr->{enumerated}->{$keyword}->{conforming} = 1 unless $invalid;
      $last_attr->{enumerated}->{$keyword}->{non_conforming} = 1
          if $invalid and not $keyword =~ /^#/;
    } elsif (/\S/) {
      die "Broken line: $_";
    }
  }
}

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xmlns'}->{status} = $statuses->{'global-attributes'};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xml:lang'}->{status} = $statuses->{'the-lang-and-xml:lang-attributes'};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
