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
    $prop->{spec} = 'HTML' if defined $prop->{id};
    if ($in->{content_model}) {
      if (not $in->{content_model}->{_complex} and
          1 == keys %{$in->{content_model}}) {
        $prop->{content_model} = each %{$in->{content_model}};
      }
    }
    for (keys %{$in->{categories} or {}}) {
      next if $_ eq '_complex';
      $Data->{categories}->{$_}->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} = 1;
      $Data->{categories}->{$_}->{spec} ||= 'HTML';
    }
    for my $attr_name (keys %{$in->{attrs} or {}}) {
      my $i = $in->{attrs}->{$attr_name};
      my $p = $prop->{attrs}->{''}->{$attr_name} ||= {};
      $p->{conforming} = 1;
      $p->{desc} = $i->{desc} if defined $i->{desc};
      if (defined $i->{id}) {
        $p->{id} = $i->{id};
        $p->{spec} = 'HTML';
      }
    }
  }
  for my $attr_name (keys %{$json->{global_attrs} or {}}) {
    my $prop = $json->{global_attrs}->{$attr_name};
    my $p = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr_name} ||= {};
    $p->{conforming} = 1;
    $p->{desc} = $prop->{desc} if defined $prop->{desc};
    if (defined $prop->{id}) {
      $p->{id} = $prop->{id};
      $p->{spec} = 'HTML';
    };
  }
}

for my $attr_name (keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}}) {
  next unless $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{id} =~ /^handler-/;
  for (qw(id spec desc)) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{frameset}->{attrs}->{''}->{$attr_name}->{$_} = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{$_};
  }
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
  'frameset' => 'frames',
  'frame' => 'frames',
};

for my $ns (keys %{$Data->{elements}}) {
  for my $ln (keys %{$Data->{elements}->{$ns}}) {
    my $v = $Data->{elements}->{$ns}->{$ln};
    if ($v->{id} and $statuses->{$v->{id}} and $v->{spec} eq 'HTML') {
      $v->{status} ||= $statuses->{$v->{id}};
      delete $v->{status} if $v->{status} eq 'UNKNOWN' or $v->{status} =~ /^(?:SPLIT|TBW|WIP|OCBE)/;
    }

    for my $ans (keys %{$v->{attrs} || {}}) {
      for my $aln (keys %{$v->{attrs}->{$ans}}) {
        my $w = $v->{attrs}->{$ans}->{$aln};
        if ($w->{id} and $statuses->{$w->{id}} and $w->{spec} eq 'HTML') {
          $w->{status} ||= $statuses->{$w->{id}};
        } elsif ($w->{id} and $id_for_status->{$w->{id}} and
                 $statuses->{$id_for_status->{$w->{id}}}) {
          $w->{status} ||= $statuses->{$id_for_status->{$w->{id}}};
        } elsif ($w->{id} and $w->{id} =~ /^handler-/ and $w->{spec} eq 'HTML') {
          $w->{status} ||= $statuses->{'event-handlers-on-elements,-document-objects,-and-window-objects'};
          $w->{value_type} ||= 'event handler';
        } elsif ($ans eq '' and $statuses->{"the-$aln-attribute"}) {
          $w->{status} ||= $statuses->{"the-$aln-attribute"};
        }
        delete $w->{status} if defined $w->{status} and ($w->{status} eq 'UNKNOWN' or $w->{status} =~ /^(?:SPLIT|TBW|WIP|OCBE)/);
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
      if ($id ne '-') {
        $last_attr->{enumerated}->{$keyword}->{id} = $id;
        $last_attr->{enumerated}->{$keyword}->{spec} = 'HTML';
      }
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

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'obsvocab.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $f->slurp);
  my $dl = $doc->get_element_by_id ('index')->query_selector ('dl');
  my $el_name;
  for my $el (@{$dl->children}) {
    if ($el->local_name eq 'dt') {
      if ($el->text_content =~ /^\s*The\s+(\S+)\s+element\s*$/) {
        $el_name = $1;
        $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{spec} ||= 'OBSVOCAB';
        $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{id} ||= $el_name;
      } else {
        $el_name = '*';
      }
    } elsif ($el->local_name eq 'dd') {
      my $a = $el->first_element_child;
      if ($a and $a->local_name eq 'a') {
        my $attr_name = $a->text_content;
        my $id = $a->title || $a->get_attribute ('href');
        if (defined $id and length $id) {
          $id =~ s/^\#//;
          $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{spec} ||= 'OBSVOCAB';
          $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{id} ||= $id;
        }
      }
    }
  }
}

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xmlns'}->{status} = $statuses->{'global-attributes'};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xml:lang'}->{status} = $statuses->{'the-lang-and-xml:lang-attributes'};

for (qw(acronym bgsound dir noframes isindex listing nextid
        noembed plaintext rb strike xmp basefont big blink
        center font multicol nobr spacer tt)) {
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{spec} = 'HTML';
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{id} = $_;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{status} = $statuses->{'non-conforming-features'};
}

my @obs_attr = qw(
  a charset attr-a-charset
  link charset attr-link-charset
  a acords attr-a-coords
  a shape attr-a-shape
  a methods attr-a-methods
  link methods attr-link-methods
  a name attr-a-name
  embed name attr-embed-name
  img name attr-img-name
  option name attr-option-name
  a rev attr-a-rev
  link rev attr-link-rev
  a urn attr-a-urn
  link urn attr-link-urn
  form accept attr-form-accept
  area nohref attr-area-nohref
  head profile attr-head-profile
  html version attr-html-version
  input ismap attr-input-ismap
  input usemap attr-input-usemap
  iframe longdesc attr-iframe-longdesc
  img longdesc attr-img-longdesc
  img lowsrc attr-img-lowsrc
  link target attr-link-target
  meta scheme attr-meta-scheme
  object archive attr-object-archive
  object classid attr-object-classid
  object code attr-object-code
  object codebase attr-object-codebase
  object codetype attr-object-codetype
  object declare attr-object-declare
  object standby attr-object-standby
  param type attr-param-type
  param valuetype attr-param-valuetype
  script language attr-script-language
  script event attr-script-for
  script for attr-script-for
  table datapagesize attr-table-datapagesize
  table summary attr-table-summary
  td abbr attr-td-abbr
  td axis attr-tdth-axis
  th axis attr-tdth-axis
  td scope attr-td-scope
  a datasrc attr-datasrc
  applet datasrc attr-datasrc
  button datasrc attr-datasrc
  div datasrc attr-datasrc
  frame datasrc attr-datasrc
  iframe datasrc attr-datasrc
  img datasrc attr-datasrc
  input datasrc attr-datasrc
  label datasrc attr-datasrc
  legend datasrc attr-datasrc
  marquee datasrc attr-datasrc
  object datasrc attr-datasrc
  option datasrc attr-datasrc
  select datasrc attr-datasrc
  span datasrc attr-datasrc
  table datasrc attr-datasrc
  textarea datasrc attr-datasrc
  a datafld attr-datafld
  applet datafld attr-datafld
  button datafld attr-datafld
  div datafld attr-datafld
  fieldset datafld attr-datafld
  frame datafld attr-datafld
  iframe datafld attr-datafld
  img datafld attr-datafld
  input datafld attr-datafld
  label datafld attr-datafld
  legend datafld attr-datafld
  marquee datafld attr-datafld
  object datafld attr-datafld
  param datafld attr-datafld
  select datafld attr-datafld
  span datafld attr-datafld
  textarea datafld attr-datafld
  button dataformatas attr-dataformatas
  div dataformatas attr-dataformatas
  input dataformatas attr-dataformatas
  label dataformatas attr-dataformatas
  legend dataformatas attr-dataformatas
  marquee dataformatas attr-dataformatas
  object dataformatas attr-dataformatas
  option dataformatas attr-dataformatas
  select dataformatas attr-dataformatas
  span dataformatas attr-dataformatas
  table dataformatas attr-dataformatas
  body alink attr-body-alink
  body bgcolor attr-body-bgcolor
  body link attr-body-link
  body marginbottom attr-body-marginbottom
  body marginheight attr-body-marginheight
  body marginleft attr-body-marginleft
  body marginright attr-body-marginright
  body margintop attr-body-margintop
  body marginwidth attr-body-marginwidth
  body text attr-body-text
  body vlink attr-body-vlink
  br clear attr-br-clear
  caption align attr-caption-align
  col align attr-col-align
  col char attr-col-char
  col charoff attr-col-charoff
  col valign attr-col-valign
  col width attr-col-width
  div align attr-div-align
  dl compact attr-dl-compact
  embed align attr-embed-align
  embed hspace attr-embed-hspace
  embed vspace attr-embed-vspace
  hr align attr-hr-align
  hr color attr-hr-color
  hr noshade attr-hr-noshade
  hr size attr-hr-size
  hr width attr-hr-width
  h1 align attr-hx-align
  h2 align attr-hx-align
  h3 align attr-hx-align
  h4 align attr-hx-align
  h5 align attr-hx-align
  h6 align attr-hx-align
  iframe align attr-iframe-align
  iframe allowtransparency attr-iframe-allowtransparency
  iframe frameborder attr-iframe-frameborder
  iframe hspace attr-iframe-hspace
  iframe marginheight attr-iframe-marginheight
  iframe marginwidth attr-iframe-marginwidth
  iframe scrolling attr-iframe-scrolling
  iframe vspace attr-iframe-vspace
  input align attr-input-align
  input hspace attr-input-hspace
  input vspace attr-input-vspace
  img align attr-img-align
  img border attr-img-border
  img hspace attr-img-hspace
  img vspace attr-img-vspace
  legend align attr-legend-align
  li type attr-li-type
  menu compact attr-menu-compact
  object align attr-object-align
  object border attr-object-border
  object hspace attr-object-hspace
  object vspace attr-object-vspace
  ol compact attr-ol-compact
  p align attr-p-align
  pre width attr-pre-width
  table align attr-table-align
  table bgcolor attr-table-bgcolor
  table border attr-table-border
  table bordercolor attr-table-bordercolor
  table cellpadding attr-table-cellpadding
  table cellspacing attr-table-cellspacing
  table frame attr-table-frame
  table rules attr-table-rules
  table width attr-table-width
  tbody align attr-tbody-align
  tbody char attr-tbody-char
  tbody charoff attr-tbody-charoff
  tbody valign attr-tbody-valign
  thead align attr-tbody-align
  thead char attr-tbody-char
  thead charoff attr-tbody-charoff
  thead valign attr-tbody-valign
  tfoot align attr-tbody-align
  tfoot char attr-tbody-char
  tfoot charoff attr-tbody-charoff
  tfoot valign attr-tbody-valign
  td align attr-tdth-align
  th align attr-tdth-align
  td bgcolor attr-tdth-bgcolor
  th bgcolor attr-tdth-bgcolor
  td char attr-tdth-char
  th char attr-tdth-char
  td charoff attr-tdth-charoff
  th charoff attr-tdth-charoff
  td height attr-tdth-height
  th height attr-tdth-height
  td nowrap attr-tdth-nowrap
  th nowrap attr-tdth-nowrap
  td valign attr-tdth-valign
  th valign attr-tdth-valign
  td width attr-tdth-width
  th width attr-tdth-width
  tr align attr-tr-align
  tr bgcolor attr-tr-bgcolor
  tr char attr-tr-char
  tr charoff attr-tr-charoff
  tr valign attr-tr-valign
  ul compact attr-ul-compact
  ul type attr-ul-type
  body background attr-background
  table background attr-background
  thead background attr-background
  tbody background attr-background
  tfoot background attr-background
  tr background attr-background
  td background attr-background
  th background attr-background
);
while (@obs_attr) {
  my $el_name = shift @obs_attr;
  my $attr_name = shift @obs_attr;
  my $attr_id = shift @obs_attr;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{spec} = 'HTML';
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{id} = $attr_id;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{status} = $statuses->{'non-conforming-features'};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
