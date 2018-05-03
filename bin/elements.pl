use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib')->stringify;
use JSON::PS;
use Web::Encoding;

sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub XMLNS_NS () { q<http://www.w3.org/2000/xmlns/> }
sub HTML_NS () { 'http://www.w3.org/1999/xhtml' }
sub MATH_NS () { 'http://www.w3.org/1998/Math/MathML' }
sub SVG_NS () { 'http://www.w3.org/2000/svg' }
sub ATOM_NS () { 'http://www.w3.org/2005/Atom' }
sub THR_NS () { 'http://purl.org/syndication/thread/1.0' }
sub APP_NS () { 'http://www.w3.org/2007/app' }
sub FH_NS () { 'http://purl.org/syndication/history/1.0' }
sub ATOMDELETED_NS () { 'http://purl.org/atompub/tombstones/1.0' }
sub ATOM03_NS () { 'http://purl.org/atom/ns#' }
sub DSIG_NS () { 'http://www.w3.org/2000/09/xmldsig#' }
sub RDF_NS () { q<http://www.w3.org/1999/02/22-rdf-syntax-ns#> }
sub RSS_NS () { q<http://purl.org/rss/1.0/> }
sub DC_NS () { q<http://purl.org/dc/elements/1.1/> }
sub RSS_CONTENT_NS () { q<http://purl.org/rss/1.0/modules/content/> }
sub HATENA_NS () { q<http://www.hatena.ne.jp/info/xmlns#> }
sub MRSS1_NS () { q<http://search.yahoo.com/mrss/> }
sub MRSS2_NS () { q<http://search.yahoo.com/mrss> }
sub GDATA_NS () { q<http://schemas.google.com/g/2005> }
sub SLASH_NS () { q<http://purl.org/rss/1.0/modules/slash/> }
sub ITUNES1_NS () { q<http://www.itunes.com/dtds/podcast-1.0.dtd> }
sub ITUNES2_NS () { q<http://www.itunes.com/DTDs/Podcast-1.0.dtd> }

my $NSMAP = {
  XML => XML_NS,
  XMLNS => XMLNS_NS,
  HTML => HTML_NS,
  MATH => MATH_NS,
  SVG => SVG_NS,
  ATOM => ATOM_NS,
  THR => THR_NS,
  APP => APP_NS,
  FH => FH_NS,
  ATOMDELETED => ATOMDELETED_NS,
  ATOM03 => ATOM03_NS,
  DSIG => DSIG_NS,
  RDF => RDF_NS,
  RSS => RSS_NS,
  DC => DC_NS,
  RSS_CONTENT => RSS_CONTENT_NS,
  HATENA => HATENA_NS,
  GDATA => GDATA_NS,
  SLASH => SLASH_NS,
};
my $NSPATTERN = join '|', keys %$NSMAP;

my $RootPath = path (__FILE__)->parent->parent;
my $Data = {};

my $input_data;
{
  my $path = $RootPath->child ('local/html-extracted.json');
  my $json = json_bytes2perl $path->slurp;
  for my $el_name0 (sort { $a cmp $b } keys %{$json->{elements}}) {
    next if $el_name0 eq 'svg' or $el_name0 eq 'math';
    my $in = $json->{elements}->{$el_name0};
    for my $el_name ($el_name0, @{$in->{additional_local_names} || []}) {
      my $prop = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} ||= {};
      $prop->{conforming} = 1;
      for (qw(desc start_tag end_tag id)) {
        next unless defined $in->{$_};
        if ($el_name0 eq $el_name) {
          $prop->{$_} = $in->{$_};
        } else {
          $prop->{$_} //= $in->{$_};
        }
      }
      $prop->{spec} = 'HTML' if defined $prop->{id};
      if ($in->{content_model}) {
        if (not $in->{content_model}->{_complex} and
            1 == keys %{$in->{content_model}}) {
          $prop->{content_model} = each %{$in->{content_model}};
          if ($prop->{content_model} eq 'text content') {
            $prop->{content_model} = 'text';
          }
        }
      }
      for (sort { $a cmp $b } keys %{$in->{categories} or {}}) {
        next if $_ eq '_complex';
        $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name}->{categories}->{$_} = 1;
        $Data->{categories}->{$_}->{spec} ||= 'HTML';
        $Data->{categories}->{$_}->{id} ||= $json->{category_label_to_id}->{$_} || $_;
      }
      for my $attr_name (sort { $a cmp $b } keys %{$in->{attrs} or {}}) {
        my $i = $in->{attrs}->{$attr_name};
        my $p = $prop->{attrs}->{''}->{$attr_name} ||= {};
        $p->{conforming} = 1;
        $p->{desc} = $i->{desc} if defined $i->{desc};
        if (defined $i->{id}) {
          $p->{id} = $i->{id};
          $p->{spec} = 'HTML';
        }
      } # $attr_name
      for my $state (sort { $a cmp $b } keys %{$in->{states} or {}}) {
        for my $cat (sort { $a cmp $b } keys %{$in->{states}->{$state}->{categories} or {}}) {
          $prop->{states}->{$state}->{categories}->{$cat} = 1;
        }
      } # $state
    }
  } # $el_name
  for my $attr_name (sort { $a cmp $b } keys %{$json->{global_attrs} or {}}) {
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

  $input_data = $json->{elements}->{input};
}

for my $attr_name (sort { $a cmp $b } keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}}) {
  next unless $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{id} =~ /^handler-/;
  for (qw(id spec desc)) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{frameset}->{attrs}->{''}->{$attr_name}->{$_} = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{body}->{attrs}->{''}->{$attr_name}->{$_};
  }
}

{
  my $path = $RootPath->child ('src/element-interfaces.txt');
  my $ns = '';
  my $ln = '*';
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^\@ns (\S+)$/) {
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
  my $path = $RootPath->child ('src/elements.txt');
  for (split /\x0D?\x0A/, $path->slurp) {
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
  my $path = $RootPath->child ('src/attr-types.txt');
  my $ns;
  my $last_attr;
  for (split /\x0D?\x0A/, decode_web_utf8 $path->slurp) {
    if (/^\s*##/) {
      #
    } elsif (/^\@ns (\S+)$/) {
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
      $keyword =~ s/\x{2423}/ /g;
      my $invalid = $label =~ s/\s+X\s*$// || $keyword =~ /^#/;
      if ($id ne '-') {
        if ($id =~ /#/) {
          $last_attr->{enumerated}->{$keyword}->{url} = $id;
        } else {
          $last_attr->{enumerated}->{$keyword}->{id} = $id;
          $last_attr->{enumerated}->{$keyword}->{spec} = 'HTML';
        }
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
  my $path = $RootPath->child ('data/fetch.json');
  my $json = json_bytes2perl $path->slurp;

  for (
    ['link', 'as', 'destination', 'potential_destination'],
    ['a', 'referrerpolicy', 'referrer_policy', 'enumerated_attr_state'],
    ['area', 'referrerpolicy', 'referrer_policy', 'enumerated_attr_state'],
    ['link', 'referrerpolicy', 'referrer_policy', 'enumerated_attr_state'],
    ['iframe', 'referrerpolicy', 'referrer_policy', 'enumerated_attr_state'],
    ['img', 'referrerpolicy', 'referrer_policy', 'enumerated_attr_state'],
  ) {
    my ($ename, $aname, $set, $check) = @$_;
    my $a_def = $Data->{elements}->{(HTML_NS)}->{$ename}->{attrs}->{''}->{$aname} ||= {};
    my $s_def = $json->{$set};
    for my $value (sort { $a cmp $b } keys %{$s_def->{values}}) {
      my $v_def = $s_def->{values}->{$value};
      next unless $v_def->{$check};
      $a_def->{value_type} = 'enumerated';
      $a_def->{enumerated}->{$value}->{url} = $v_def->{url} || $s_def->{url};
      $a_def->{enumerated}->{$value}->{conforming} = 1;
      $a_def->{enumerated}->{$value}->{label} = $v_def->{enumerated_attr_state};
    }
    if (defined $s_def->{invalid_value_default}) {
      if ($a_def->{enumerated}->{$s_def->{invalid_value_default}}) {
        $a_def->{enumerated}->{'#invalid'}->{label} = $a_def->{enumerated}->{$s_def->{invalid_value_default}}->{label};
      } else {
        $a_def->{enumerated}->{'#invalid'}->{label} = $s_def->{invalid_value_default};
      }
    }
    if (defined $s_def->{missing_value_default}) {
      if ($a_def->{enumerated}->{$s_def->{missing_value_default}}) {
        $a_def->{enumerated}->{'#missing'}->{label} = $a_def->{enumerated}->{$s_def->{missing_value_default}}->{label};
      } else {
        $a_def->{enumerated}->{'#missing'}->{label} = $s_def->{missing_value_default};
      }
    }
  }
}

## <input>
{
  my $input_states = [grep {
    $Data->{elements}->{(HTML_NS)}->{input}->{attrs}->{''}->{type}->{enumerated}->{$_}->{conforming} and not /^#/;
  } sort { $a cmp $b } keys %{$Data->{elements}->{(HTML_NS)}->{input}->{attrs}->{''}->{type}->{enumerated}}];
  for my $type (grep { $_ ne 'hidden' } @$input_states) {
    for my $category (sort { $a cmp $b } keys %{$input_data->{categories_unless_hidden}}) {
      $Data->{input}->{states}->{$type}->{categories}->{$category} = 1;
    }
  }
  for my $category (sort { $a cmp $b } keys %{$input_data->{categories_if_hidden}}) {
    $Data->{input}->{states}->{hidden}->{categories}->{$category} = 1;
  }
  for my $type (@$input_states) {
    if ($Data->{input}->{states}->{$type}->{categories}->{'palpable content'}) {
      $Data->{input}->{states}->{$type}->{categories}->{'feed significant content'} = 1;
    }
  }
}

$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{categories}->{'interactive content'} = 1;

$Data->{elements}->{(HTML_NS)}->{dl}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{menu}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{ul}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;
$Data->{elements}->{(HTML_NS)}->{ol}->{states}->{'has-item'}
    ->{categories}->{'palpable content'} = 1;

## Allowed in theory but we don't support RDF/XML anymore.
#$Data->{elements}->{'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}->{RDF}
#    ->{categories}->{'metadata content'} = 1;
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

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{a}
    ->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{a} = 1;

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
$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{canvas_fallback} = 1;
$Data->{elements}->{(HTML_NS)}->{'*'}->{states}->{'interactive-by-tabindex'}
    ->{supported_canvas_fallback} = 1;
$Data->{input}->{states}->{$_}->{canvas_fallback} = 1
    for qw(checkbox radio submit reset button image);
$Data->{input}->{states}->{$_}->{supported_canvas_fallback} = 1
    for qw(checkbox radio submit reset button);

$Data->{categories}->{'feed significant content'}->{url} = 'https://wiki.suikawiki.org/n/Feed%20Parsing';
$Data->{categories}->{'feed significant content'}->{label} = 'feed significant content';
$Data->{categories}->{'feed significant content'}->{text} = 1;
for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
  for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
    my $data = $Data->{elements}->{$ns}->{$ln};
    if (($data->{categories} || {})->{'palpable content'} and
        ($data->{categories} || {})->{'embedded content'}) {
      $data->{categories}->{'feed significant content'} = 1;
    }
    for my $state (sort { $a cmp $b } keys %{$data->{states} or {}}) {
      my $d = $data->{states}->{$state};
      if ((($data->{categories} || {})->{'embedded content'} or
           ($d->{categories} || {})->{'embedded content'}) and
          ($d->{categories} || {})->{'palpable content'}) {
        $d->{categories}->{'feed significant content'} = 1;
      }
    }
  }
}

my $has_category_prop = {};
my $tree_pattern_name_map = {};
my $tree_pattern_not_name_map = {};
{
  my $path = $RootPath->child ('src/element-categories.txt');
  my $name;
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^\*\s*([A-Za-z0-9_ -]+)$/) {
      $name = $1;
    } elsif (defined $name and /^spec\s+(\S+)$/) {
      my $url = $1;
      if ($url =~ m{^https?://html.spec.whatwg.org/#(.+)$}) {
        $Data->{categories}->{$name}->{spec} = 'HTML';
        $Data->{categories}->{$name}->{id} = $1;
      } elsif ($url =~ m{^https?://www.whatwg.org/specs/web-apps/current-work/#(.+)$}) {
        $Data->{categories}->{$name}->{spec} = 'HTML';
        $Data->{categories}->{$name}->{id} = $1;
      } else {
        $Data->{categories}->{$name}->{url} = $url;
      }
    } elsif (defined $name and /^label\s+(\S.*)$/) {
      $Data->{categories}->{$name}->{label} = $1;
    } elsif (defined $name and /^text$/) {
      $Data->{categories}->{$name}->{text} = 1;
    } elsif (defined $name and /^text non-space$/) {
      $Data->{categories}->{$name}->{text_non_space} = 1;
    } elsif (defined $name and /^<($NSPATTERN)>\s+(.+)$/o) {
      my $lns = [grep { length $_ } split /[\s,]+/, $2];
      my $ns = $NSMAP->{$1};
      for my $ln (@$lns) {
        $Data->{elements}->{$ns}->{$ln}->{categories}->{$name} = 1;
      }
    } elsif (defined $name and /^autonomous custom elements$/) {
      $Data->{elements}->{(HTML_NS)}->{'*-*'}->{categories}->{$name} = 1;
    } elsif (defined $name and /^prop$/) {
      $has_category_prop->{$name} = 1;
    } elsif (defined $name and /^pattern not (.+)$/) {
      $tree_pattern_not_name_map->{$1} = $name;
    } elsif (defined $name and /^pattern (.+)$/) {
      $tree_pattern_name_map->{$1} = $name;
    } elsif (/\S/) {
      die "$path: Broken line |$_|";
    }
  }
}

{
  my $path = $RootPath->child ('local/html-tree.json');
  my $json = json_bytes2perl $path->slurp;
  for my $key (sort { $a cmp $b } keys %{$json->{patterns}}) {
    my $def = $json->{patterns}->{$key};
    unless (defined $def and ref $def eq 'ARRAY' and $def->[0] eq 'or') {
      die "$path: Unknown pattern value for |$key|";
    }
    shift @$def;
    my $name = $tree_pattern_name_map->{$key} || $key;
    for (@$def) {
      my $ns = {HTML => HTML_NS, SVG => SVG_NS, MathML => MATH_NS}->{$_->{ns}};
      for my $ln (ref $_->{name} ? @{$_->{name}} : $_->{name}) {
        if (defined $_->{attrs} and @{$_->{attrs}} == 1) {
          if ($_->{attrs}->[0]->{name} eq 'encoding' and
              defined $_->{attrs}->[0]->{lc_value} and
              ($_->{attrs}->[0]->{lc_value} eq 'text/html' or
               $_->{attrs}->[0]->{lc_value} eq 'application/xhtml+xml')) {
            $Data->{elements}->{$ns}->{$ln}->{states}->{'encoding-html'}->{categories}->{$name} = 1;
          } else {
            push @{$Data->{_errors} ||= []},
                "Bad |attr| value for $ns/$ln";
          }
        } else {
          $Data->{elements}->{$ns}->{$ln}->{categories}->{$name} = 1;
        }
      }
    }
  }
  for my $key (sort { $a cmp $b } keys %{$json->{patterns_not}}) {
    my $def = $json->{patterns_not}->{$key};
    unless (defined $def and ref $def eq 'ARRAY' and $def->[0] eq 'or') {
      die "$path: Unknown pattern value for |$key|";
    }
    shift @$def;
    my $name = $tree_pattern_not_name_map->{$key} || $key;
    for (@$def) {
      my $ns = {HTML => HTML_NS, SVG => SVG_NS, MathML => MATH_NS}->{$_->{ns}};
      for my $ln (ref $_->{name} ? @{$_->{name}} : $_->{name}) {
        if (defined $_->{attrs}) {
          push @{$Data->{_errors} ||= []},
              "Bad |attr| value for $ns/$ln";
        } else {
          $Data->{elements}->{$ns}->{$ln}->{categories}->{$name} = 1;
        }
      }
    }
  }
  for my $key (sort { $a cmp $b } keys %{$json->{steps}}) {
    my $name = $tree_pattern_name_map->{$key};
    my $wk = 'while';
    unless (defined $name) {
      $name = $tree_pattern_not_name_map->{$key} || next;
      $wk = 'while_not';
    }
    my $acts = $json->{steps}->{$key}->{actions};
    for (@$acts) {
      if ($_->{type} eq 'pop-oe' and defined $_->{$wk}) {
        my $ns = {HTML => HTML_NS, SVG => SVG_NS, MathML => MATH_NS}->{$_->{$wk}->{ns}};
        for my $ln (@{$_->{$wk}->{name}}) {
          $Data->{elements}->{$ns}->{$ln}->{categories}->{$name} = 1;
        }
        last;
      }
    }
  }
  for (
    [parser_implied_end_tag_at_body => $json->{ims}->{'in body'}->{conds}->{'END:html'}->{actions}],
    [parser_implied_end_tag_at_eof => $json->{ims}->{'in body'}->{conds}->{'EOF'}->{actions}],
  ) {
    my $name = $_->[0];
    my @act = @{$_->[1]};
    while (@act) {
      my $act = shift @act;
      if ($act->{type} eq 'if' and
          $act->{cond}->[0] eq 'oe' and
          $act->{cond}->[1] eq 'in scope not' and
          $act->{cond}->[2] eq 'all') {
        for my $ln (@{$act->{cond}->[3]->{name}}) {
          $Data->{elements}->{(HTML_NS)}->{$ln}->{categories}->{$name} = 1;
        }
        last;
      } else {
        unshift @act, @{$act->{actions} or []}, @{$act->{false_actions} or []};
      }
    }
  }
}

{
  my $path = $RootPath->child ('data/headers.json');
  my $data = json_bytes2perl $path->slurp;
  for my $data (values %{$data->{headers}}) {
    if ($data->{http_equiv}->{conforming} or
        defined $data->{http_equiv}->{enumerated_attr_state_name}) {
      my $a_def = $Data->{elements}->{(HTML_NS)}->{meta}->{attrs}->{''}->{'http-equiv'} ||= {};
      my $value = $data->{http_equiv}->{name};
      $value =~ tr/A-Z/a-z/;
      for (qw(url id spec)) {
        $a_def->{enumerated}->{$value}->{$_} = $data->{http_equiv}->{$_}
            if defined $data->{http_equiv}->{$_};
      }
      if ($data->{http_equiv}->{conforming}) {
        $a_def->{enumerated}->{$value}->{conforming} = 1;
      } else {
        $a_def->{enumerated}->{$value}->{non_conforming} = 1;
      }
      $a_def->{enumerated}->{$value}->{label} = $data->{http_equiv}->{enumerated_attr_state_name}
          if defined $data->{http_equiv}->{enumerated_attr_state_name};
    }
  } # $data
}

## For backward compatibility
{
  for my $ns (sort { $a cmp $b } keys %{$Data->{elements} or {}}) {
    for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
      my $cats = $Data->{elements}->{$ns}->{$ln}->{categories} || {};
      for my $name (sort { $a cmp $b } keys %$has_category_prop) {
        if ($cats->{$name}) {
          $Data->{elements}->{$ns}->{$ln}->{$name} = 1;
        }
      }
      $Data->{elements}->{$ns}->{$ln}->{parser_category} = 'special'
          if $cats->{'special category'};
      $Data->{elements}->{$ns}->{$ln}->{parser_category} = 'formatting'
          if $cats->{'formatting category'};
    }
  }
}

for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
  for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
    my $v = $Data->{elements}->{$ns}->{$ln};
    for my $ans (sort { $a cmp $b } keys %{$v->{attrs} || {}}) {
      for my $aln (sort { $a cmp $b } keys %{$v->{attrs}->{$ans}}) {
        my $w = $v->{attrs}->{$ans}->{$aln};
        if ($w->{id} and $w->{id} =~ /^handler-/ and $w->{spec} eq 'HTML') {
          $w->{value_type} ||= 'event handler';
        }
      }
    }
  }
}

{
  use Web::DOM::Document;
  my $path = $RootPath->child ('local/obsvocab.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($path->slurp_utf8);
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
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{menu}->{complex_content_model} =
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
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn}->{content_model} = 'phrasing content';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn}->{disallowed_descendants}->{elements}->{'http://www.w3.org/1999/xhtml'}->{dfn} = 1;
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{object}->{complex_content_model} =
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
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{picture}->{complex_content_model} = [
  {elements => {'http://www.w3.org/1999/xhtml' => {source => 1}},
   categories => {'script-supporting elements' => 1},
   min => 0},
  {elements => {'http://www.w3.org/1999/xhtml' => {img => 1}},
   min => 1, max => 1},
  {categories => {'script-supporting elements' => 1},
   min => 0},
];
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{canvas}->{content_model} = 'transparent';
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{has_additional_content_constraints} = 1
    for qw(head title style dl figure ruby iframe video audio table
           colgroup label datalist option script noscript template
           canvas summary picture
           frameset noframes noembed);

for (qw(acronym bgsound dir noframes isindex listing nextid
        noembed plaintext rb rtc strike xmp basefont big blink
        center font multicol nobr spacer tt)) {
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{spec} = 'HTML';
  $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{id} = $_;
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
for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
  for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
    if (($Data->{elements}->{$ns}->{$ln}->{content_model} || '') eq 'atomPersonConstruct') {
      for my $ce ($Data->{elements}->{$ns}->{$ln}->{child_elements} ||= {}) {
        $ce->{+ATOM_NS}->{$_}->{min} = 0,
        $ce->{+ATOM_NS}->{$_}->{max} = 1
            for qw(email uri);
        $ce->{+ATOM_NS}->{$_}->{min} = 1,
        $ce->{+ATOM_NS}->{$_}->{max} = 1
            for qw(name);
        $ce->{+GDATA_NS}->{$_}->{min} = 0,
        $ce->{+GDATA_NS}->{$_}->{max} = 1
            for qw(image);
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



{
  my $path = $RootPath->child ('src/element-contents.txt');
  my $ens;
  my $eln;
  my @edef;
  my $spec;
  my @defined;
  my $defined = sub {
    for my $def (@defined) {
      $def->{url} = $spec if defined $spec;
    }
    @defined = ();
  };
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^\*\s*<($NSPATTERN)>([\w-]+)\s*$/o) {
      $ens = $NSMAP->{$1};
      $eln = $2;
      $defined->();
      @edef = ($Data->{elements}->{$ens}->{$eln} ||= {});
      @defined = @edef;
    } elsif (/^\*\s*<(RSS2)>([\w-]+)\s*$/o) {
      $ens = '';
      $eln = $2;
      $defined->();
      @edef = ($Data->{rss2_elements}->{$eln} ||= {});
      @defined = @edef;
    } elsif (/^\*\s*<(MEDIA)>([\w-]+)\s*$/o) {
      $ens = '';
      $eln = $2;
      $defined->();
      @edef = ($Data->{elements}->{(MRSS1_NS)}->{$eln} ||= {},
               $Data->{elements}->{(MRSS2_NS)}->{$eln} ||= {});
      @defined = @edef;
    } elsif (/^\*\s*<(ITUNES)>([\w-]+)\s*$/o) {
      $ens = '';
      $eln = $2;
      $defined->();
      @edef = ($Data->{elements}->{(ITUNES1_NS)}->{$eln} ||= {},
               $Data->{elements}->{(ITUNES2_NS)}->{$eln} ||= {});
      @defined = @edef;
    } elsif (/^([0-9]+)-([0-9]+|\*)\s+<($NSPATTERN)>([\w-]+)(\^\*|)\s*$/o) {
      my $ans = $NSMAP->{$3};
      for my $edef (@edef) {
        $edef->{child_elements}->{$ans}->{$4}->{min} = 0+$1;
        $edef->{child_elements}->{$ans}->{$4}->{max} = 0+$2 unless $2 eq '*';
        $edef->{child_elements}->{$ans}->{$4}->{has_additional_rules} = 1 if $5;
      }
    } elsif (/^([0-9]+)-([0-9]+|\*)\s+<(MEDIA)>([\w-]+)(\^\*|)\s*$/o) {
      for my $edef (@edef) {
        for my $ans (MRSS1_NS, MRSS2_NS) {
          $edef->{child_elements}->{$ans}->{$4}->{min} = 0+$1;
          $edef->{child_elements}->{$ans}->{$4}->{max} = 0+$2 unless $2 eq '*';
          $edef->{child_elements}->{$ans}->{$4}->{has_additional_rules} = 1 if $5;
        }
      }
    } elsif (/^([0-9]+)-([0-9]+|\*)\s+<(ITUNES)>([\w-]+)(\^\*|)\s*$/o) {
      for my $edef (@edef) {
        for my $ans (ITUNES1_NS, ITUNES2_NS) {
          $edef->{child_elements}->{$ans}->{$4}->{min} = 0+$1;
          $edef->{child_elements}->{$ans}->{$4}->{max} = 0+$2 unless $2 eq '*';
          $edef->{child_elements}->{$ans}->{$4}->{has_additional_rules} = 1 if $5;
        }
      }
    } elsif ($ens eq '' and
             /^([0-9]+)-([0-9]+|\*)\s+<(RSS2)>([\w-]+)(\^\*|)\s*$/o) {
      my $ans = '';
      for my $edef (@edef) {
        $edef->{child_elements}->{$ans}->{$4}->{min} = 0+$1;
        $edef->{child_elements}->{$ans}->{$4}->{max} = 0+$2 unless $2 eq '*';
        $edef->{child_elements}->{$ans}->{$4}->{has_additional_rules} = 1 if $5;
      }
    } elsif (/^(required\s+|)attr\s+(<(?:$NSPATTERN)>|)([\w-]+)\s+(text|any|URL|absolute URL|language tag|W3C-DTF|RSS 2\.0 person|RSS 2\.0 date|non-negative integer|MIME type|NPT|floating-point number|currency|e-mail address|itunes:duration|\.\.\.)$/o) {
      my $ans = $NSMAP->{substr $2 || '__', 1, -2 + length $2} || '';
      for my $edef (@edef) {
        my $w = $edef->{attrs}->{$ans}->{$3} ||= {};
        push @defined, $w;
        $w->{conforming} = 1;
        $w->{value_type} = $4 unless $4 eq '...';
        $w->{required} = 1 if $1;
      }
    } elsif (/^content\s+(text|any|URL|absolute URL|language tag|W3C-DTF|RSS 2\.0 person|RSS 2\.0 date|non-negative integer|MIME type|NPT|floating-point number|currency|e-mail address|itunes:duration)\s*$/) {
      for my $edef (@edef) {
        $edef->{content_model} = 'text';
        $edef->{text_type} = $1;
      }
    } elsif (/^(required\s+|)attr\s+(<(?:$NSPATTERN)>|)([\w-]+)\s+enum\s+\(([^()]+)\)$/o) {
      my $ans = $NSMAP->{substr $2 || '__', 1, -2 + length $2} || '';
      my @value = split /\|/, $4;
      for my $edef (@edef) {
        my $w = $edef->{attrs}->{$ans}->{$3} ||= {};
        push @defined, $w;
        $w->{conforming} = 1;
        $w->{value_type} = 'case-sensitive enumerated';
        $w->{required} = 1 if $1;
        for (@value) {
          my $v = $_;
          my $bad = $v =~ s/^\*//;
          my $ww = $w->{enumerated}->{$v} ||= {};
          push @defined, $ww;
          $ww->{conforming} = 1 unless $bad;
        }
      }
    } elsif (/^content\s+enum\s+\(([^()]+)\)\s*$/) {
      my @value = split /\|/, $1;
      for my $edef (@edef) {
        $edef->{content_model} = 'text';
        $edef->{text_type} = 'case-sensitive enumerated';
        for (@value) {
          my $v = $_;
          my $bad = $v =~ s/^\*//;
          my $w = $edef->{enumerated}->{$v} ||= {};
          push @defined, $w;
          $w->{conforming} = 1 unless $bad;
        }
      }
    } elsif (/^content\s+(empty)\s*$/) {
      for my $edef (@edef) {
        $edef->{content_model} = $1;
      }
    } elsif (/^suggested\s+max\s+([0-9]+)\s*$/) {
      #
    } elsif (/^spec\s+(\S+)\s*$/) {
      $spec = $1;
    } elsif (/^conforming$/) {
      $edef[0]->{conforming} = 1;
    } elsif (/^(deprecated|obsolete|root)$/) {
      for my $edef (@edef) {
        $edef->{$1} = 1;
      }
    } elsif (/^preferred\s+/) {
      # XXX
    } elsif (/^atom\s+extensible$/) {
      for my $edef (@edef) {
        $edef->{atom_extensible} = 1;
      }
    } elsif (/^unknown\s+children$/) {
      for my $edef (@edef) {
        $edef->{unknown_children} = 1;
      }
    } elsif (/^unknown\s+children\s+-\s+RDF$/) {
      for my $edef (@edef) {
        $edef->{unknown_children} = 'nordf';
      }
    } elsif (/^and\s+more$/) {
      for my $edef (@edef) {
        $edef->{has_additional_content_constraints} = 1;
      }
    } elsif (/\S/) {
      die "Bad line |$_|";
    }
  } # split
  $defined->();
}

for my $keyword (qw(
  allow-forms allow-modals allow-orientation-lock allow-pointer-lock
  allow-popups allow-popups-to-escape-sandbox allow-presentation
  allow-same-origin allow-scripts allow-top-navigation
  allow-top-navigation-by-user-activation
)) {
  my $d = $Data->{elements}->{(HTML_NS)}->{iframe}->{attrs}->{''}->{sandbox}->{keywords}->{$keyword} ||= {};
  $d->{conforming} = 1;
  $d->{spec} = 'HTML';
  $d->{id} = 'iframe-sandbox-' . $keyword;
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
}

## <https://www.whatwg.org/specs/web-apps/current-work/#syntax-elements>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    = 'void' for grep { length } split /\s*,\s*|\s+/, q{
area, base, br, col, embed, hr, img, input, link, meta, param, source, track, wbr
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
area, base, basefont, bgsound, br, col, embed, frame, hr, img, input, keygen, link, meta, param, source, track, wbr
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'obsolete void macro' for grep { length } split /\s*,\s*|\s+/, q{
image
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'obsolete raw text' for grep { length } split /\s*,\s*|\s+/, q{
style, script, xmp, noembed, noframes
};
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_}->{syntax_category}
    ||= 'special' for grep { length } split /\s*,\s*|\s+/, q{
iframe, noscript, plaintext
};

$Data->{elements}->{'*'}->{'*'}->{auto_br} = 'disallow';
$Data->{elements}->{(HTML_NS)}->{'*'}->{auto_br} = 'allow';
for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
  my $ns_default = ($Data->{elements}->{$ns}->{'*'} || {})->{auto_br}
                || $Data->{elements}->{'*'}->{'*'}->{auto_br};
  for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
    my $el_def = $Data->{elements}->{$ns}->{$ln};
    my $syntax = $el_def->{syntax_category} // '';
    my $cm = $el_def->{content_model} // '';
    if ($cm eq 'empty' or $cm eq 'text' or
        $syntax eq 'void' or $syntax eq 'obsolete void' or
        $syntax eq 'raw text' or $syntax eq 'obsolete raw text' or
        $syntax eq 'escapable raw text' or
        $syntax eq 'obsolete void macro') {
      unless ($ns_default eq 'disallow') {
        $el_def->{auto_br} = 'disallow';
      }
    } elsif ($cm eq 'flow content' or $cm eq 'phrasing content' or
             $cm eq 'transparent') {
      unless ($ns_default eq 'allow') {
        $el_def->{auto_br} = 'allow';
      }
    } elsif (defined $el_def->{child_elements} or
             defined $el_def->{complex_content_model} or
             $el_def->{has_additional_content_constraints}) {
      unless ($ns_default eq 'disallow') {
        $el_def->{auto_br} = 'disallow';
      }
    }
  }
}
delete $Data->{elements}->{(HTML_NS)}->{$_}->{auto_br} #= 'allow'
    for qw(figure fieldset details template);
$Data->{elements}->{(MATH_NS)}->{$_}->{auto_br} = 'allow'
    for qw(mi mo mn ms mtext);
$Data->{elements}->{(SVG_NS)}->{$_}->{auto_br} = 'allow'
    for qw(title desc foreignObject);

{
  my $path = $RootPath->child ('data/aria.json');
  my $json = json_bytes2perl $path->slurp;

  for my $attr (sort { $a cmp $b } keys %{$json->{attrs}}) {
    my $adef =
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr} =
    $Data->{elements}->{'http://www.w3.org/2000/svg'}->{'*'}->{attrs}->{''}->{$attr} = {};
    for (qw(preferred)) {
      $adef->{$_} = $json->{attrs}->{$attr}->{$_}
          if defined $json->{attrs}->{$attr}->{$_};
    }
    next if $json->{attrs}->{$attr}->{obsolete};
    for (qw(value_type item_type id_type url)) {
      $adef->{$_} = $json->{attrs}->{$attr}->{$_}
          if defined $json->{attrs}->{$attr}->{$_};
    }
    $adef->{conforming} = 1;
    if ($json->{attrs}->{$attr}->{tokens}) {
      ## In ARIA in HTML spec tokens are case-sensitive, but HTML
      ## enumerated attributes are ASCII case-insensitive in general.
      ## We willfully ignore the inconsistent rule here.
      if ($adef->{value_type} eq 'enumerated') {
        for (sort { $a cmp $b } keys %{$json->{attrs}->{$attr}->{tokens}}) {
          $adef->{enumerated}->{$_}->{url} = $adef->{url};
          $adef->{enumerated}->{$_}->{conforming} = 1;
        }
      } else {
        for (sort { $a cmp $b } keys %{$json->{attrs}->{$attr}->{tokens}}) {
          $adef->{keywords}->{$_}->{url} = $adef->{url};
          $adef->{keywords}->{$_}->{conforming} = 1;
        }
      }
    }
  }

  for my $role (sort { $a cmp $b } keys %{$json->{roles}}) {
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role}->{url} =
    $Data->{elements}->{'http://www.w3.org/2000/svg'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role}->{url}
        = $json->{roles}->{$role}->{url};
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{role}->{keywords}->{$role}->{conforming} = 1
        unless $json->{roles}->{$role}->{abstract};

    for my $category (sort { $a cmp $b } keys %{$json->{roles}->{$role}->{categories} or {}}) {
      $Data->{categories}->{$category}->{roles}->{$role} = 1;
    }
  }
} # data/aria.json

{
  my $path = $RootPath->child ('local/element-aria.json');
  my $data = json_bytes2perl $path->slurp;
  for my $ns (sort { $a cmp $b } keys %{$data->{elements}}) {
    for my $ln (sort { $a cmp $b } keys %{$data->{elements}->{$ns}}) {
      $Data->{elements}->{$ns}->{$ln}->{aria} = $data->{elements}->{$ns}->{$ln}->{conds};
    }
  }

  for my $type (sort { $a cmp $b } keys %{$data->{input}->{'http://www.w3.org/1999/xhtml'}}) {
    $Data->{input}->{aria}->{$type} = $data->{input}->{'http://www.w3.org/1999/xhtml'}->{$type}->{conds};
  }

  my $merge = sub {
    my ($v1, $v2) = @_;
    return $v1 if not defined $v2;
    return $v2 if not defined $v1;

    return $v1 if $v1->{value_type} eq 'true' or $v1->{value_type} eq 'false';
    return $v2 if $v2->{value_type} eq 'true' or $v2->{value_type} eq 'false';

    if ($v1->{value_type} eq 'missing/true' and
        $v1->{attr} eq 'open' and
        $v2->{value_type} eq 'true/missing' and
        $v2->{attr} eq 'hidden' and
        $v1->{strong} and $v2->{strong}) {
      return {value_type => 'open-hidden', strong => 1};
    }

    if ($v1->{value_type} eq 'false/missing' and
        $v1->{attr} eq 'contenteditable' and
        $v2->{value_type} eq 'true/missing' and
        $v2->{attr} eq 'readonly' and
        $v1->{strong} and $v2->{strong}) {
      ## Note that <input readonly contenteditable> implies
      ## aria-readonly=true aria-readonly=false, which is really
      ## broken and should be detected by another steps of conformance
      ## checkers.
      return $v2;
    }

    return {value_type => 'XX'.'X cannot merge values',
            v1 => $v1, v2 => $v2};
  }; # $merge

  for my $rule (@{$data->{attr_rules}}) {
    for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
      for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns}}) {
        my $edef = $Data->{elements}->{$ns}->{$ln};
        for my $ans (sort { $a cmp $b } keys %{$edef->{attrs} or {}}) {
          for my $aln (sort { $a cmp $b } keys %{$edef->{attrs}->{$ans}}) {
            my $adef = $edef->{attrs}->{$ans}->{$aln};
            if (defined $adef->{spec} and
                $adef->{spec} eq 'HTML' and $adef->{id} eq $rule->[0]) {
              $edef->{aria}->{''} = {} unless keys %{$edef->{aria} or {}};
              my @aria = ($edef->{aria});
              if ($ln eq '*') {
                push @aria,
                    grep { defined $_ }
                    map { $Data->{elements}->{$ns}->{$_}->{aria} }
                    grep { $_ ne $ln }
                    keys %{$Data->{elements}->{$ns}};
              }
              for my $aria (@aria) {
                for my $cond (sort { $a cmp $b } keys %$aria) {
                  if ($aln eq 'disabled') { # per HTML Standard (not ARIA in HTML)
                    $aria->{$cond}->{attrs}->{$rule->[1]}
                        = $merge->($aria->{$cond}->{attrs}->{$rule->[1]},
                                   {value_type => $rule->[2],
                                    state => ':disabled', strong => 1});
                  } else {
                    $aria->{$cond}->{attrs}->{$rule->[1]}
                        = $merge->($aria->{$cond}->{attrs}->{$rule->[1]},
                                   {value_type => $rule->[2],
                                    attr => $aln, strong => 1});
                  }
                }
              } # $aria
              if ($ns eq 'http://www.w3.org/1999/xhtml' and $ln eq 'input') {
                for my $type (sort { $a cmp $b } keys %{$Data->{input}->{attrs}->{$aln} or {}}) {
                  for my $cond (sort { $a cmp $b } keys %{$Data->{input}->{aria}->{$type}}) {
                    $Data->{input}->{aria}->{$type}->{$cond}->{attrs}->{$rule->[1]}
                        = {value_type => $rule->[2], attr => $aln, strong => 1};
                  }
                }
              } # input
            }
          }
        }
        if ($data->{elements}->{$ns}->{$ln}->{aria_disallowed}) {
          $edef->{aria_disallowed} = 1;
        }
        if ($data->{elements}->{$ns}->{$ln}->{aria_hidden_only}) {
          $edef->{aria_hidden_only} = 1;
        }
      } # $ln
    }
  }
}

## <http://www.whatwg.org/specs/web-apps/current-work/#the-embed-element>
$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{embed}->{attrs}->{''}->{$_}->{non_conforming} = 1
    for qw(align hspace vspace name);

$Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{embed}->{attrs}->{''}->{$_}->{browser} = 1
    for qw(align hspace vspace name
           border units pluginpage pluginspage pluginurl palette);

{
  my $data = json_bytes2perl $RootPath->child ('local/altmap-html-obsolete.json')->slurp;
  for my $ns (sort { $a cmp $b } keys %{$data->{elements}}) {
    for my $ln (sort { $a cmp $b } keys %{$data->{elements}->{$ns}}) {
      my $preferred = $data->{elements}->{$ns}->{$ln}->{preferred};
      $Data->{elements}->{$ns}->{$ln}->{preferred} = $preferred
          if defined $preferred;
      for my $ans (sort { $a cmp $b } keys %{$data->{elements}->{$ns}->{$ln}->{attrs} or {}}) {
        for my $aln (sort { $a cmp $b } keys %{$data->{elements}->{$ns}->{$ln}->{attrs}->{$ans}}) {
          my $preferred = $data->{elements}->{$ns}->{$ln}->{attrs}->{$ans}->{$aln}->{preferred};
          $Data->{elements}->{$ns}->{$ln}->{attrs}->{$ans}->{$aln}->{preferred} = $preferred
              if defined $preferred;
        }
      }
    }
  }
}

for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{'http://www.w3.org/1999/xhtml'}}) {
  for my $attr_name (sort { $a cmp $b } keys %{($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs} or {})->{''} or {}}) {
    next if defined $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs}->{''}->{$attr_name}->{id};
    $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$ln}->{attrs}->{''}->{$attr_name}->{value_type}
        ||= ($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr_name} or {})->{value_type}
        if defined (((($Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs} or {})->{''} or {})->{$attr_name} or {})->{value_type});
  }
}

for my $ns (sort { $a cmp $b } keys %{$Data->{elements} or {}}) {
  for my $ln (sort { $a cmp $b } keys %{$Data->{elements}->{$ns} or {}}) {
    my $edef = $Data->{elements}->{$ns}->{$ln};
    for my $cat_name (sort { $a cmp $b } keys %{$edef->{categories} or {}}) {
      $Data->{categories}->{$cat_name}->{elements}->{$ns}->{$ln} = 1;
    }
    for my $state (sort { $a cmp $b } keys %{$edef->{states} or {}}) {
      for my $cat_name (sort { $a cmp $b } keys %{$edef->{states}->{$state}->{categories} or {}}) {
        if ($ln eq '*') {
          $Data->{categories}->{$cat_name}->{has_additional_rules} = 1;
        } else {
          $Data->{categories}->{$cat_name}->{elements_with_exceptions}->{$ns}->{$ln} = 1;
        }
      }
    }
    $edef->{unknown_children} = 1 if $edef->{atom_extensible};
  } # $ln
} # $ns
for my $state (sort { $a cmp $b } keys %{$Data->{input}->{states} or {}}) {
  for my $cat_name (sort { $a cmp $b } keys %{$Data->{input}->{states}->{$state}->{categories} or {}}) {
    $Data->{categories}->{$cat_name}->{elements_with_exceptions}->{(HTML_NS)}->{input} = 1;
  }
}

## <https://html.spec.whatwg.org/#valid-custom-element-name>
for (qw(
  annotation-xml color-profile font-face font-face-src font-face-uri
  font-face-format font-face-name missing-glyph
)) {
  $Data->{not_custom_element_names}->{$_} = 1;
}

{
  my $path = $RootPath->child ('src/namespaces.txt');
  my $ns;
  my $def;
  for (split /\x0D?\x0A/, $path->slurp) {
    if (/^\s*#/) {
      #
    } elsif (/^\*\s*(\S+)\s*$/) {
      $ns = $1;
      $def = $Data->{namespaces}->{$ns} ||= {};
    } elsif (/^label\s+(.+)$/) {
      $def->{label} = $1;
    } elsif (/^([\w]+):$/) {
      $def->{prefix} = $1;
    } elsif (/^atom\s+family$/) {
      $def->{atom_family} = 1;
    } elsif (/^spec\s+(\S+)\s*$/) {
      $def->{url} = $1;
    } elsif (/^fully\s+supported$/) {
      $def->{supported} = 1;
    } elsif (/^partially\s+supported$/) {
      #
    } elsif (/^(obsolete)$/) {
      $def->{$1} = 1;
    } elsif (/\S/) {
      die "Bad line |$_|";
    }
  }
}
for my $ns (sort { $a cmp $b } keys %{$Data->{elements}}) {
  next if $ns eq '' or $ns eq '*';
  $Data->{namespaces}->{$ns} ||= {};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
