use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::PS qw(perl2json_bytes_for_record file2perl);

sub HTML_NS () { 'http://www.w3.org/1999/xhtml' }
sub ATOM_NS () { 'http://www.w3.org/2005/Atom' }
sub THR_NS () { 'http://purl.org/syndication/thread/1.0' }
sub APP_NS () { 'http://www.w3.org/2007/app' }
sub FH_NS () { 'http://purl.org/syndication/history/1.0' }
sub ATOMDELETED_NS () { 'http://purl.org/atompub/tombstones/1.0' }
sub ATOM03_NS () { 'http://purl.org/atom/ns#' }
sub DSIG_NS () { 'http://www.w3.org/2000/09/xmldsig#' }

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
      $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{categories}->{$_} = 1;
      $Data->{categories}->{$_}->{spec} ||= 'HTML';
      $Data->{categories}->{$_}->{id} ||= $_;
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
  $Data->{input} = $json->{input};
  $Data->{input}->{attrs} = delete $Data->{input}->{content_attrs};
  push @{$Data->{_errors} ||= []}, $json->{_errors}
      if @{$json->{_errors} or []};
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
    if (/^\s*#/) {
      #
    } elsif (/^([^=]+)=(.+)$/) {
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

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'attr-types.txt');
  my $ns;
  my $last_attr;
  for (($f->slurp)) {
    if (/^\@ns (\S+)$/) {
      $ns = $1;
    } elsif (/^(\S+)\s+(\S+)\s+([^=:]+):([^=]+)=(.+)$/) {
      $last_attr = $Data->{elements}->{$ns}->{$1}->{attrs}->{''}->{$2} ||= {};
      $last_attr->{value_type} = $3;
      $last_attr->{item_type} = $4;
      $last_attr->{id_type} = $5;
    } elsif (/^(\S+)\s+(\S+)\s+([^=:]+):(.+)$/) {
      $last_attr = $Data->{elements}->{$ns}->{$1}->{attrs}->{''}->{$2} ||= {};
      $last_attr->{value_type} = $3;
      $last_attr->{item_type} = $4;
    } elsif (/^(\S+)\s+(\S+)\s+([^=]+)=(.+)$/) {
      $last_attr = $Data->{elements}->{$ns}->{$1}->{attrs}->{''}->{$2} ||= {};
      $last_attr->{value_type} = $3;
      $last_attr->{id_type} = $4;
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

## Heading elements
for my $el_name (qw(h1 h2 h3 h4 h5 h6)) {
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{id} = 'the-h1,-h2,-h3,-h4,-h5,-and-h6-elements';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{spec} = 'HTML';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{content_model} = 'phrasing content';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{conforming} = 1;
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{desc} = 'Section heading';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'flow content'} = 1;
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'heading content'} = 1;
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'palpable content'} = 1;
}

## |sub| and |sup|
for my $el_name (qw(sub sup)) {
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{spec} = 'HTML';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{id} = 'the-sub-and-sup-elements';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{content_model} = 'phrasing content';
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'flow content'} = 1;
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'phrasing content'} = 1;
  $Data->{elements}->{(HTML_NS)}->{$el_name}->{categories}->{'palpable content'} = 1;
}

my $input_states = [grep {
  $Data->{elements}->{(HTML_NS)}->{input}->{attrs}->{''}->{type}->{enumerated}->{$_}->{conforming} and not /^#/;
} keys %{$Data->{elements}->{(HTML_NS)}->{input}->{attrs}->{''}->{type}->{enumerated}}];

for ('flow content', 'phrasing content') {
  $Data->{elements}->{(HTML_NS)}->{area}->{states}->{'in-map'}
      ->{categories}->{$_} = 1;
  $Data->{elements}->{(HTML_NS)}->{link}->{states}->{'itemprop-attr'}
      ->{categories}->{$_} = 1;
  $Data->{elements}->{(HTML_NS)}->{meta}->{states}->{'itemprop-attr'}
      ->{categories}->{$_} = 1;
}
$Data->{elements}->{(HTML_NS)}->{style}->{states}->{'scoped-attr'}
    ->{categories}->{'flow content'} = 1;

$Data->{elements}->{(HTML_NS)}->{audio}->{states}->{'controls-attr'}
    ->{categories}->{'interactive content'} = 1;
$Data->{elements}->{(HTML_NS)}->{video}->{states}->{'controls-attr'}
    ->{categories}->{'interactive content'} = 1;
$Data->{elements}->{(HTML_NS)}->{img}->{states}->{'usemap-attr'}
    ->{categories}->{'interactive content'} = 1;
$Data->{elements}->{(HTML_NS)}->{object}->{states}->{'usemap-attr'}
    ->{categories}->{'interactive content'} = 1;
$Data->{elements}->{(HTML_NS)}->{th}->{states}->{'sorting-interface'}
    ->{categories}->{'interactive content'} = 1;
$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{categories}->{'interactive content'} = 1;

$Data->{elements}->{(HTML_NS)}->{audio}->{states}->{'controls-attr'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{dl}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{menu}->{states}->{'toolbar'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{ul}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{ol}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;

$Data->{elements}->{(HTML_NS)}->{video}->{categories}->{'media element'} = 1;
$Data->{elements}->{(HTML_NS)}->{audio}->{categories}->{'media element'} = 1;

$Data->{elements}->{'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}->{RDF}
    ->{categories}->{'metadata content'} = 1;
for ('embedded content', 'phrasing content', 'flow content',
     'palpable content') {
  $Data->{elements}->{'http://www.w3.org/2000/svg'}->{svg}
      ->{categories}->{$_} = 1;
  $Data->{elements}->{'http://www.w3.org/1998/Math/MathML'}->{math}
      ->{categories}->{$_} = 1;
}

## <http://www.whatwg.org/specs/web-apps/current-work/#concept-button>
## <http://www.whatwg.org/specs/web-apps/current-work/#concept-submit-button>
$Data->{input}->{states}->{$_}->{button} = 1
    for qw(button submit image reset);
$Data->{input}->{states}->{$_}->{submit_button} = 1
    for qw(submit image);
$Data->{elements}->{(HTML_NS)}->{button}->{button} = 1;
$Data->{elements}->{(HTML_NS)}->{button}->{states}->{'submit-button'}
    ->{submit_button} = 1;

## <http://www.whatwg.org/specs/web-apps/current-work/#the-canvas-element>
## <http://www.whatwg.org/specs/web-apps/current-work/#supported-interactive-canvas-fallback-element>
$Data->{elements}->{(HTML_NS)}->{$_}->{canvas_fallback} = 1
    for qw(a button);
$Data->{elements}->{(HTML_NS)}->{$_}->{supported_canvas_fallback} = 1
    for qw(button table caption thead tbody tfoot tr th td);
$Data->{elements}->{(HTML_NS)}->{a}->{states}->{'hyperlink-noimage'}
    ->{supported_canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{select}->{states}->{'listbox'}
    ->{canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{select}->{states}->{'listbox'}
    ->{supported_canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{option}->{states}->{'in-select-listbox'}
    ->{supported_canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{img}->{states}->{'usemap-attr'}
    ->{canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{th}->{states}->{'sorting-interface'}
    ->{canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{supported_canvas_fallback} = 1;
$Data->{input}->{states}->{$_}->{canvas_fallback} = 1
    for qw(checkbox radio submit reset button image);
$Data->{input}->{states}->{$_}->{supported_canvas_fallback} = 1
    for qw(checkbox radio submit reset button);

## <input>
for (grep { $_ ne 'hidden' } @$input_states) {
  $Data->{input}->{states}->{$_}->{categories}->{'interactive content'} = 1;
  $Data->{input}->{states}->{$_}->{categories}->{'category-label'} = 1;
  $Data->{input}->{states}->{$_}->{categories}->{'palpable content'} = 1;
}
$Data->{elements}->{(HTML_NS)}->{input}->{categories}->{$_} = 1
    for 'category-listed', 'category-submit', 'category-reset',
        'category-form-attr', 'form-associated element';

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
  'attr-img-generator-unable-to-provide-required-alt' => 'guidance-for-markup-generators',
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
        next if defined $w->{status};
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
        delete $w->{status} unless defined $w->{spec};
      }
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

## <http://www.whatwg.org/specs/web-apps/current-work/#url-property-elements>.
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{categories}->{'URL property elements'} = 1
    for qw(a area audio embed iframe img link object source track video);
$Data->{categories}->{'URL property elements'}->{spec} = 'HTML';
$Data->{categories}->{'URL property elements'}->{id} = 'URL property elements';
$Data->{categories}->{'URL property elements'}->{label} = 'URL property elements';

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xmlns'}->{status} = $statuses->{'global-attributes'};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{'xml:lang'}->{status} = $statuses->{'the-lang-and-xml:lang-attributes'};

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{html}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {head => 1}},
   min => 1, max => 1},
  {elements => {'http://www.w3.org/1999/xhtml' => {body => 1}},
   min => 1, max => 1},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{head}->{content_model} = 'metadata content';
for ($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{head}->{child_elements}->{'http://www.w3.org/1999/xhtml'} ||= {}) {
  $_->{title}->{min} = 0;
  $_->{title}->{max} = 1;
  $_->{title}->{has_additional_rules} = 1;
  $_->{base}->{min} = 0;
  $_->{base}->{max} = 1;
}
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{title}->{content_model} = 'text';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{nav}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{nav}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{main} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{aside}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{aside}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{main} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{hgroup}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {h1 => 1, h2 => 1, h3 => 1, h4 => 1, h5 => 1, h6 => 1}},
   categories => {'script-supporting elements' => 1},
   min => 1},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{header}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{header}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{main} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{header}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{header} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{header}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{main} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{header} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{address} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{header} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{disallowed_descendants}->{categories}->{'heading content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{address}->{disallowed_descendants}->{categories}->{'sectioning content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{ol}->{complex_content_model} =
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{ul}->{complex_content_model} =
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dir}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {li => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dt}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dt}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{header} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dt}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dt}->{disallowed_descendants}->{categories}->{'heading content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dt}->{disallowed_descendants}->{categories}->{'sectioning content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{a}->{content_model} = 'transparent';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{a}->{disallowed_descendants}->{categories}->{'interactive content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{object}->{complex_content_model} =
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{applet}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {param => 1}},
   min => 0},
  {transparent => 1},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{video}->{disallowed_descendants}->{categories}->{'media element'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{audio}->{disallowed_descendants}->{categories}->{'media element'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{caption}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{caption}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{table} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{tbody}->{complex_content_model} =
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{thead}->{complex_content_model} =
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{tfoot}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {tr => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{tr}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {th => 1, td => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{th}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{th}->{disallowed_descendants}->{categories}->{'sectioning content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{th}->{disallowed_descendants}->{categories}->{'heading content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{th}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{header} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{th}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{footer} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{form}->{content_model} = 'flow content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{form}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{form} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{label}->{content_model} = 'phrasing content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{label}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{label} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{button}->{content_model} = 'phrasing content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{button}->{disallowed_descendants}->{categories}->{'interactive content'} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{select}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {option => 1, optgroup => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{optgroup}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {option => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{option}->{content_model} = 'text';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{progress}->{content_model} = 'phrasing content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{progress}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{progress} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{meter}->{content_model} = 'phrasing content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{meter}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{meter} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{fieldset}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {legend => 1}},
   min => 1, max => 1},
  {categories => {'flow content' => 1}},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{details}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {summary => 1}},
   min => 1, max => 1},
  {categories => {'flow content' => 1}},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{summary}->{complex_content_model} = [
  {categories => {'flow content' => 1, 'heading content' => 1}},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{canvas}->{content_model} = 'transparent';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{has_additional_content_constraints} = 1
    for qw(head title style dl figure ruby iframe video audio table
           colgroup th label datalist option menu script noscript template
           canvas summary
           frameset noframes noembed);

for (qw(acronym bgsound dir noframes isindex listing nextid
        noembed plaintext rb strike xmp basefont big blink
        center font multicol nobr spacer tt)) {
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{spec} = 'HTML';
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{id} = $_;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{status} = $statuses->{'non-conforming-features'};
}

for my $ns (keys %{$Data->{elements} or {}}) {
  for my $ln (keys %{$Data->{elements}->{$ns} or {}}) {
    for my $cat_name (keys %{$Data->{elements}->{$ns}->{$ln}->{categories} or {}}) {
      $Data->{categories}->{$cat_name}->{elements}->{$ns}->{$ln} = 1;
    }
    for my $state (keys %{$Data->{elements}->{$ns}->{$ln}->{states} or {}}) {
      for my $cat_name (keys %{$Data->{elements}->{$ns}->{$ln}->{states}->{$state}->{categories} or {}}) {
        if ($ln eq '*') {
          $Data->{categories}->{$cat_name}->{has_additional_rules} = 1;
        } else {
          $Data->{categories}->{$cat_name}->{elements_with_exceptions}->{$ns}->{$ln} = 1;
        }
      }
    }
  }
}
for my $state (keys %{$Data->{input}->{states} or {}}) {
  for my $cat_name (keys %{$Data->{input}->{states}->{$state}->{categories} or {}}) {
    $Data->{categories}->{$cat_name}->{elements_with_exceptions}->{(HTML_NS)}->{input} = 1;
  }
}

for (
  ['feed'],
  ['title'],
  ['link'],
  ['author'],
  ['contributor'],
  ['tagline' => 'subtitle'],
  ['id'],
  ['generator'],
  ['copyright' => 'license'],
  ['modified' => 'updated'],
  ['entry'],
  ['issued' => 'created'],
  ['created'],
  ['summary'],
  ['content'],
  ['name'],
  ['url' => 'uri'],
  ['email'],
) {
  $Data->{elements}->{(ATOM03_NS)}->{$_->[0]}->{preferred}
      ||= {type => 'atom_element', name => $_->[1] // $_->[0]};
}
$Data->{elements}->{(ATOM03_NS)}->{feed}->{attrs}->{''}->{version}
    ->{preferred} = {type => 'none'};
$Data->{elements}->{(ATOM03_NS)}->{generator}->{attrs}->{''}->{url}
    ->{preferred} = {type => 'atom_attr', name => 'uri',
                     element => 'generator'};
$Data->{elements}->{(ATOM03_NS)}->{generator}->{attrs}->{''}->{version}
    ->{preferred} = {type => 'atom_attr', name => 'version',
                     element => 'generator'};
$Data->{elements}->{(ATOM03_NS)}->{info}->{preferred} = {type => 'none'};
$Data->{elements}->{(ATOM03_NS)}->{link}->{attrs}->{''}->{rel}
    ->{preferred} = {type => 'atom_attr', name => 'rel', element => 'link'};
$Data->{elements}->{(ATOM03_NS)}->{link}->{attrs}->{''}->{type}
    ->{preferred} = {type => 'atom_attr', name => 'type', element => 'link'};
$Data->{elements}->{(ATOM03_NS)}->{link}->{attrs}->{''}->{href}
    ->{preferred} = {type => 'atom_attr', name => 'href', element => 'link'};
$Data->{elements}->{(ATOM03_NS)}->{link}->{attrs}->{''}->{title}
    ->{preferred} = {type => 'atom_attr', name => 'title', element => 'link'};

for my $ce ($Data->{elements}->{+ATOM_NS}->{feed}->{child_elements} ||= {}) {
  $ce->{+ATOM_NS}->{$_}->{min} = 0
      for qw(author category contributor link entry);
  $ce->{+APP_NS}->{collection}->{min} = 0;
  $ce->{+ATOMDELETED_NS}->{'deleted-entry'}->{min} = 0;
  $ce->{+ATOM_NS}->{$_}->{min} = 0,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(generator icon logo rights subtitle);
  $ce->{+ATOM_NS}->{$_}->{min} = 1,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(id title updated);
  $ce->{+ATOM_NS}->{$_}->{has_additional_rules} = 1
      for qw(author link entry);
  $ce->{+FH_NS}->{$_}->{min} = 0,
  $ce->{+FH_NS}->{$_}->{max} = 1
      for qw(archive complete);
  #$ce->{+DSIG_NS}->{Signature}->{min} = 0;
  #$ce->{+DSIG_NS}->{Signature}->{max} = 1;
}
for my $ce ($Data->{elements}->{+ATOM_NS}->{entry}->{child_elements} ||= {}) {
  $ce->{+ATOM_NS}->{$_}->{min} = 0
      for qw(author category contributor link);
  $ce->{+ATOM_NS}->{$_}->{min} = 0,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(content rights source summary);
  $ce->{+APP_NS}->{$_}->{min} = 0,
  $ce->{+APP_NS}->{$_}->{max} = 1
      for qw(control edited);
  $ce->{+ATOM_NS}->{$_}->{min} = 1,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(id title updated);
  $ce->{+ATOM_NS}->{$_}->{has_additional_rules} = 1
      for qw(author link summary);
  $ce->{+APP_NS}->{$_}->{has_additional_rules} = 1
      for qw(edited);
  $ce->{+THR_NS}->{'in-reply-to'}->{min} = 0;
  $ce->{+THR_NS}->{total}->{min} = 0;
  $ce->{+THR_NS}->{total}->{max} = 1;
  #$ce->{+DSIG_NS}->{Signature}->{min} = 0;
  #$ce->{+DSIG_NS}->{Signature}->{max} = 1;
}
for my $ce ($Data->{elements}->{+ATOM_NS}->{source}->{child_elements} ||= {}) {
  $ce->{+ATOM_NS}->{$_}->{min} = 0
      for qw(author category contributor link);
  $ce->{+ATOM_NS}->{$_}->{min} = 0,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(generator icon id logo rights subtitle title updated);
}
for my $ce ($Data->{elements}->{+ATOM03_NS}->{feed}->{child_elements} ||= {}) {
  $ce->{+ATOM03_NS}->{$_}->{min} = 0,
  $ce->{+ATOM03_NS}->{$_}->{max} = 1
      for qw(author copyright generator id info tagline);
  $ce->{+ATOM03_NS}->{$_}->{min} = 1,
  $ce->{+ATOM03_NS}->{$_}->{max} = 1
      for qw(modified title);
  $ce->{+ATOM03_NS}->{$_}->{min} = 0
      for qw(contributor entry);
  $ce->{+ATOM03_NS}->{$_}->{min} = 1
      for qw(link);
}
for my $ce ($Data->{elements}->{+ATOM03_NS}->{entry}->{child_elements} ||= {}) {
  $ce->{+ATOM03_NS}->{$_}->{min} = 0,
  $ce->{+ATOM03_NS}->{$_}->{max} = 1
      for qw(author created id summary);
  $ce->{+ATOM03_NS}->{$_}->{min} = 1,
  $ce->{+ATOM03_NS}->{$_}->{max} = 1
      for qw(issued modified title);
  $ce->{+ATOM03_NS}->{$_}->{min} = 0
      for qw(contributor content);
  $ce->{+ATOM03_NS}->{$_}->{min} = 1
      for qw(link);
}
for my $ce ($Data->{elements}->{+APP_NS}->{categories}->{child_elements} ||= {}) {
  $ce->{+ATOM_NS}->{$_}->{min} = 0
      for qw(category);
}
for my $ce ($Data->{elements}->{+APP_NS}->{service}->{child_elements} ||= {}) {
  $ce->{+APP_NS}->{$_}->{min} = 1
      for qw(workspace);
}
for my $ce ($Data->{elements}->{+APP_NS}->{workspace}->{child_elements} ||= {}) {
  $ce->{+APP_NS}->{$_}->{min} = 0
      for qw(collection);
  $ce->{+ATOM_NS}->{$_}->{min} = 1,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(title);
}
for my $ce ($Data->{elements}->{+APP_NS}->{collection}->{child_elements} ||= {}) {
  $ce->{+APP_NS}->{$_}->{min} = 0
      for qw(accept categories);
  $ce->{+ATOM_NS}->{$_}->{min} = 1,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(title);
}
for my $ce ($Data->{elements}->{+APP_NS}->{control}->{child_elements} ||= {}) {
  $ce->{+APP_NS}->{$_}->{min} = 0,
  $ce->{+APP_NS}->{$_}->{max} = 1
      for qw(draft);
}
for my $ce ($Data->{elements}->{+ATOMDELETED_NS}->{'deleted-entry'}->{child_elements} ||= {}) {
  $ce->{+ATOM_NS}->{$_}->{min} = 0
      for qw(link);
  $ce->{+ATOM_NS}->{$_}->{min} = 0,
  $ce->{+ATOM_NS}->{$_}->{max} = 1
      for qw(source);
  $ce->{+ATOMDELETED_NS}->{$_}->{min} = 0,
  $ce->{+ATOMDELETED_NS}->{$_}->{max} = 1
      for qw(by comment);
  #$ce->{+DSIG_NS}->{Signature}->{min} = 0;
  #$ce->{+DSIG_NS}->{Signature}->{max} = 1;
}
for my $ns (keys %{$Data->{elements}}) {
  for my $ln (keys %{$Data->{elements}->{$ns}}) {
    if (($Data->{elements}->{$ns}->{$ln}->{content_model} || '') eq 'atomPersonConstruct') {
      for my $ce ($Data->{elements}->{$ns}->{$ln}->{child_elements} ||= {}) {
        $ce->{+ATOM_NS}->{$_}->{min} = 0,
        $ce->{+ATOM_NS}->{$_}->{max} = 1
            for qw(email uri);
        $ce->{+ATOM_NS}->{$_}->{min} = 1,
        $ce->{+ATOM_NS}->{$_}->{max} = 1
            for qw(name);
      }
      $Data->{elements}->{$ns}->{$ln}->{atom_extensible} = 1;
    } elsif (($Data->{elements}->{$ns}->{$ln}->{content_model} || '') eq 'atom03PersonConstruct') {
      for my $ce ($Data->{elements}->{$ns}->{$ln}->{child_elements} ||= {}) {
        $ce->{+ATOM03_NS}->{$_}->{min} = 0,
        $ce->{+ATOM03_NS}->{$_}->{max} = 1
            for qw(email url);
        $ce->{+ATOM03_NS}->{$_}->{min} = 1,
        $ce->{+ATOM03_NS}->{$_}->{max} = 1
            for qw(name);
      }
    } elsif (($Data->{elements}->{$ns}->{$ln}->{content_model} || '') eq 'atomTextConstruct') {
      $Data->{elements}->{$ns}->{$ln}->{lang_sensitive} = 1;
      $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{type}->{conforming} = 1;
      $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{type}->{status} = 'LC'; # Atom 1.0
    } elsif (($Data->{elements}->{$ns}->{$ln}->{content_model} || '') eq 'atom03ContentConstruct') {
      if ($Data->{elements}->{$ns}->{$ln}->{preferred}->{type} eq 'atom_element') {
        $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{type}->{preferred} =
        $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{mode}->{preferred}
            = {type => 'atom_attr', name => 'type',
               element => $Data->{elements}->{$ns}->{$ln}->{preferred}->{name}};
      } elsif ($Data->{elements}->{$ns}->{$ln}->{preferred}->{type} eq 'none') {
        $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{type}->{preferred} =
        $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{mode}->{preferred}
            = {type => 'none'};
      }
      $Data->{elements}->{$ns}->{$ln}->{attrs}->{''}->{type}->{value_type} ||= 'MIME type';
    }
  }
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
  source media attr-source-media
);
while (@obs_attr) {
  my $el_name = shift @obs_attr;
  my $attr_name = shift @obs_attr;
  my $attr_id = shift @obs_attr;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{spec} = 'HTML';
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{id} = $attr_id;
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs}->{''}->{$attr_name}->{status} = $statuses->{'non-conforming-features'};
}

for my $ln (keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}}) {
  if (($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{content_model} // '') eq 'empty') {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{auto_br} ||= 'disallow';
  }
}

## <http://www.whatwg.org/specs/web-apps/current-work/#all-named-elements>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{all_named} = 1
    for split /\s*,\s*/, q(a, applet, button, embed, form, frame, frameset, iframe, img, input, map, meta, object, select, textarea);
    ## |keygen| is commented out in spec

## <http://www.whatwg.org/specs/web-apps/current-work/#the-stack-of-open-elements>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_category}
    = 'special' for grep { length } split /\s*,\s*|\s+/, q{
  address, applet, area, article, aside, base, basefont, bgsound, blockquote, body, br, button, caption, center, col, colgroup, dd, details, dir, div, dl, dt, embed, fieldset, figcaption, figure, footer, form, frame, frameset, h1, h2, h3, h4, h5, h6, head, header, hgroup, hr, html, iframe, img, input, isindex, li, link, listing, main, marquee, menu, menuitem, meta, nav, noembed, noframes, noscript, object, ol, p, param, plaintext, pre, script, section, select, source, style, summary, table, tbody, td, template, textarea, tfoot, th, thead, title, tr, track, ul, wbr, xmp
};
$Data->{elements}->{'http://www.w3.org/1998/Math/MathML'}->{$_}->{parser_category}
    = 'special' for grep { length } split /\s*,\s*|\s+/, q{
  mi, mo, mn, ms, mtext, annotation-xml
};
$Data->{elements}->{'http://www.w3.org/2000/svg'}->{$_}->{parser_category}
    = 'special' for grep { length } split /\s*,\s*|\s+/, q{
foreignObject, desc, title
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_category}
    = 'formatting' for grep { length } split /\s*,\s*|\s+/, q{
a, b, big, code, em, font, i, nobr, s, small, strike, strong, tt, u
};

## <http://www.whatwg.org/specs/web-apps/current-work/#syntax-elements>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    = 'void' for grep { length } split /\s*,\s*|\s+/, q{
area, base, br, col, embed, hr, img, input, keygen, link, menuitem, meta, param, source, track, wbr
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    = 'raw text' for grep { length } split /\s*,\s*|\s+/, q{
script, style
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    = 'escapable raw text' for grep { length } split /\s*,\s*|\s+/, q{
textarea, title
};

## <http://www.whatwg.org/specs/web-apps/current-work/#serializing-html-fragments>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'obsolete void' for grep { length } split /\s*,\s*|\s+/, q{
area, base, basefont, bgsound, br, col, embed, frame, hr, img, input, keygen, link, menuitem, meta, param, source, track, wbr
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'obsolete void macro' for grep { length } split /\s*,\s*|\s+/, q{
image, isindex
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'obsolete raw text' for grep { length } split /\s*,\s*|\s+/, q{
style, script, xmp, noembed, noframes
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'special' for grep { length } split /\s*,\s*|\s+/, q{
iframe, noscript, plaintext
};

## <http://www.whatwg.org/specs/web-apps/current-work/#serializing-html-fragments>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{first_newline_ignored} = 1
    for qw(pre textarea listing);

## <http://www.whatwg.org/specs/web-apps/current-work/#has-an-element-in-scope>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_li_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_button_scoping} = 1
    for qw(applet caption html table td th marquee object template);
$Data->{elements}->{'http://www.w3.org/1998/Math/MathML'}->{$_}->{parser_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/1998/Math/MathML'}->{$_}->{parser_li_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/1998/Math/MathML'}->{$_}->{parser_button_scoping} = 1
    for qw(mi mo mn ms mtext annotation-xml);
$Data->{elements}->{'http://www.w3.org/2000/svg'}->{$_}->{parser_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/2000/svg'}->{$_}->{parser_li_scoping} = 1,
$Data->{elements}->{'http://www.w3.org/2000/svg'}->{$_}->{parser_button_scoping} = 1
    for qw(foreignObject desc title);

## <http://www.whatwg.org/specs/web-apps/current-work/#has-an-element-in-list-item-scope>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_li_scoping} = 1
    for qw(ol ul);

## <http://www.whatwg.org/specs/web-apps/current-work/#has-an-element-in-button-scope>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_button_scoping} = 1
    for qw(button);

## <http://www.whatwg.org/specs/web-apps/current-work/#has-an-element-in-table-scope>,
## <http://www.whatwg.org/specs/web-apps/current-work/#clear-the-stack-back-to-a-table-context>.
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_table_scoping} = 1
    for qw(html table template);

## <http://www.whatwg.org/specs/web-apps/current-work/#clear-the-stack-back-to-a-table-body-context>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_table_body_scoping} = 1
    for qw(html tbody tfoot thead template);

## <http://www.whatwg.org/specs/web-apps/current-work/#clear-the-stack-back-to-a-table-row-context>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_table_row_scoping} = 1
    for qw(html tr template);

## <http://www.whatwg.org/specs/web-apps/current-work/#has-an-element-in-select-scope>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_select_non_scoping} = 1
    for qw(optgroup option);

## <http://www.whatwg.org/specs/web-apps/current-work/#generate-implied-end-tags>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_implied_end_tag} = 1
    for qw(dd dt li option optgroup p rp rt);

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_implied_end_tag_at_eof} = 1
    for qw(dd dt li p tbody td tfoot th thead tr body html);

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{parser_implied_end_tag_at_body} = 1
    for qw(dd dt li optgroup option p rp rt tbody td tfoot th thead tr body html);

{
  my $f = file (__FILE__)->dir->parent->file ('data', 'aria.json');
  my $json = file2perl $f;

  for my $attr (keys %{$json->{attrs}}) {
    my $adef =
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr} =
    $Data->{elements}->{'http://www.w3.org/2000/svg'}->{'*'}->{attrs}->{''}->{$attr} = {};
    for (qw(value_type item_type id_type preferred)) {
      $adef->{$_} = $json->{attrs}->{$attr}->{$_}
          if defined $json->{attrs}->{$attr}->{$_};
    }
    $adef->{conforming} = 1;
    $adef->{spec} = 'ARIA';
    $adef->{status} = 'CR';
    if ($json->{attrs}->{$attr}->{tokens}) {
      if ($adef->{value_type} eq 'enumerated') {
        for (keys %{$json->{attrs}->{$attr}->{tokens}}) {
          $adef->{enumerated}->{$_}->{spec} = 'ARIA';
          $adef->{enumerated}->{$_}->{conforming} = 1;
        }
      } else {
        for (keys %{$json->{attrs}->{$attr}->{tokens}}) {
          $adef->{keywords}->{$_}->{spec} = 'ARIA';
          $adef->{keywords}->{$_}->{conforming} = 1;
        }
      }
    }
  }

  for my $role (keys %{$json->{roles}}) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role} =
    $Data->{elements}->{'http://www.w3.org/2000/svg'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role} =
        {spec => 'ARIA'};
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role}->{conforming} = 1
        unless $json->{roles}->{$role}->{abstract};
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'element-aria.json');
  my $json = file2perl $f;
  for my $el_name (keys %{$json->{html_elements}}) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{aria} = $json->{html_elements}->{$el_name};
  }
  $Data->{input}->{aria} = $json->{input};

  ## :disabled
  for my $el_name (keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}}) {
    if (((($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{attrs} or {})->{''}->{disabled} or {})->{id} || '') eq 'attr-fe-disabled') {
      $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{aria}->{''}->{attrs}->{'attr-disabled'} = {value_type => 'true/missing', state => ':disabled', strong => 1};
    }
  }
  delete $json->{common}->{''}->{disabled};

  ## :invalid
  for my $el_name (keys %{$Data->{categories}->{'category-submit'}->{elements}->{'http://www.w3.org/1999/xhtml'}}) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{aria}->{''}->{attrs}->{'attr-invalid'} = {value_type => 'true/missing', state => ':invalid', strong => 1};
  }
  delete $json->{common}->{''}->{invalid};

  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{aria} = $json->{common}->{''};
}

## <http://www.whatwg.org/specs/web-apps/current-work/#the-embed-element>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{embed}->{attrs}->{''}->{$_}->{non_conforming} = 1
    for qw(align hspace vspace name);

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{embed}->{attrs}->{''}->{$_}->{browser} = 1
    for qw(align hspace vspace name
           border units pluginpage pluginspage pluginurl palette);

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'html-obsolete.txt');
  my $alts = {};
  my $target;
  for (($f->slurp)) {
    if (/^<(\S+)>$/) {
      die "$f: No alternative is specified for @$target" if $target;
      $target = [$1];
    } elsif (/^<(\S+) (\S+)>$/) {
      die "$f: No alternative is specified for @$target" if $target;
      $target = [$1, $2];
    } elsif (defined $target and /^  (.+)$/) {
      my $alt = $1;
      if ($alt =~ /^<(\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_element', name => $1};
      } elsif ($alt =~ /^<\* (\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_attr', name => $1};
      } elsif ($alt =~ /^<(input) (type)=(\S+)>$/) {
        $alts->{"@$target"} = {type => 'input', name => $3};
      } elsif ($alt =~ /^<(\S+) (\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_attr', name => $2, element => $1};
      } elsif ($alt =~ /^-$/) {
        $alts->{"@$target"} = {type => 'omit'};
      } elsif ($alt =~ /^([a-z-]+): (\S+)$/) {
        $alts->{"@$target"} = {type => 'css_prop', name => $1, value => $2};
      } elsif ($alt =~ /^([a-z-]+)$/) {
        $alts->{"@$target"} = {type => 'css_prop', name => $1};
      } elsif ($alt =~ /^#(script|progressive|comment|vcard|vevent|math|css|counter|text)$/) {
        $alts->{"@$target"} = {type => $1};
      } elsif ($alt =~ m{^N/A$}) {
        $alts->{"@$target"} = {type => 'none'};
      } else {
        die "$f: broken line: |  $alt|";
      }
      undef $target;
    } elsif (/\S/) {
      die "$f: broken line: |$_|";
    }
  }

  for (keys %$alts) {
    my ($el, $attr) = split / /, $_;
    my $v = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el} ||= {};
    $v = $v->{attrs}->{''}->{$attr} ||= {} if defined $attr;
    $v->{preferred} = $alts->{$_};
  }
}

for my $ln (keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}}) {
  for my $attr_name (keys %{($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs} or {})->{''} or {}}) {
    next if defined $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs}->{''}->{$attr_name}->{id};
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs}->{''}->{$attr_name}->{value_type}
        ||= ($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr_name} or {})->{value_type}
        if defined (((($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs} or {})->{''} or {})->{$attr_name} or {})->{value_type});
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
