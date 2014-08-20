use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use Regexp::Assemble;

my $Data = {};

{
  my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ('local/html-tokenizer.json')->slurp;
  $Data->{tokenizer} = $tokenizer;

  for ('local/html-tokenizer-charrefs-jump.json') {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (keys %{$tokenizer->{states}}) {
      $Data->{tokenizer}->{states}->{$_} = $tokenizer->{states}->{$_};
    }
  }

  my $tokenizer_charrefs = json_bytes2perl path (__FILE__)->parent->parent->child ('local/html-tokenizer-charrefs.json')->slurp;
  for (
    ['data state', undef],
    ['RCDATA state', undef],
    ['attribute value (double-quoted) state', '"'],
    ['attribute value (single-quoted) state', "'"],
    ['attribute value (unquoted) state', '<'],
  ) {
    my ($orig_state, $additional) = @$_;
    for my $state (keys %{$tokenizer_charrefs->{states}}) {
      for my $cond (keys %{$tokenizer_charrefs->{states}->{$state}->{conds}}) {
        my $def = $tokenizer_charrefs->{states}->{$state}->{conds}->{$cond};
        my $acts = [map {
          if ($_->{type} eq 'SWITCH-BACK') {
            +{%$_, type => 'switch', state => $orig_state};
          } elsif ($_->{type} eq 'switch') {
            +{%$_, state => "$orig_state - $_->{state}"};
          } elsif ($_->{type} =~ /^process-temp-as-/) {
            if ($orig_state =~ /attribute/) {
              +{%$_, in_attr => 1};
            } else {
              +{%$_};
            }
          } elsif ($_->{type} eq 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR') {
            if ($orig_state =~ /attribute/) {
              +{type => 'append-temp-to-attr', field => $_->{field}};
            } else {
              +{type => 'emit-temp'};
            }
          } else {
            $_;
          }
        } @{$def->{actions}}];
        if ($cond eq 'ALLOWED_CHAR') {
          if (defined $additional) {
            $cond = sprintf 'CHAR:%04X', ord $additional;
          } else {
            next;
          }
        }
        $Data->{tokenizer}->{states}->{"$orig_state - $state"}->{conds}->{$cond} = {%$def, actions => $acts};
      }
    }
  }
}
delete $Data->{tokenizer}->{states}->{'character reference in attribute value state'};

{
  my $changed = 0;
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    my $state_def = $Data->{tokenizer}->{states}->{$state};
    for my $cond (keys %{$state_def->{conds}}) {
      my $types = {%{$state_def->{initial_token_types} or {}}};
      my $last_state = $state;
      for my $act (@{$state_def->{conds}->{$cond}->{actions}}) {
        if ($act->{type} eq 'create') {
          $types = {};
          $types->{$act->{token}} = 1;
        } elsif ($act->{type} eq 'emit') {
          $types = {};
        } elsif ($act->{type} eq 'switch') {
          if (defined $act->{if}) {
            for (keys %$types) {
              $Data->{tokenizer}->{states}->{$act->{state}}->{initial_token_types}->{$_} ||= do { $changed = 1; $types->{$_} };
            }
          } else {
            $last_state = $act->{state};
          }
        } elsif ($act->{type} eq 'switch-and-emit') {
          #
        }
      }
      for (keys %$types) {
        my $value = ($last_state eq 'data state' and $cond eq 'EOF') ? -1 : $types->{$_};
        $Data->{tokenizer}->{states}->{$last_state}->{initial_token_types}->{$_} ||= do { $changed = 1; $value };
      }
    }
  }
  redo if $changed;
}

{
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    my $state_def = $Data->{tokenizer}->{states}->{$state};
    for my $cond (keys %{$state_def->{conds}}) {
      my $types = {%{$state_def->{initial_token_types} or {}}};
      for my $act (@{$state_def->{conds}->{$cond}->{actions}}) {
        if ($act->{type} eq 'create') {
          $types = {$act->{token} => 1};
          $Data->{tokenizer}->{tokens}->{$act->{token}} ||= {};
        } elsif ($act->{type} eq 'emit' or
                 $act->{type} eq 'switch-and-emit') {
          $act->{possible_token_types} = $types;
          $act->{check_end_tag_token} = 1 if $types->{'end tag token'};
        }
        if (defined $act->{field}) {
          $Data->{tokenizer}->{tokens}->{$_}->{fields}->{$act->{field}} = 1 for keys %$types;
        }
      }
    }
  }
  $Data->{tokenizer}->{tokens}->{'character token'}->{fields} ||= {};
  $Data->{tokenizer}->{tokens}->{'end-of-file token'}->{fields} ||= {};
  $Data->{tokenizer}->{tokens}->{'start tag token'}->{fields}->{attributes} = 1;
  $Data->{tokenizer}->{tokens}->{'end tag token'}->{fields}->{attributes} = 1;
  $Data->{tokenizer}->{tokens}->{'character token'}->{fields}->{value} = 1;
  for (
    [CHAR => 'character token'],
    [START => 'start tag token'],
    [END => 'end tag token'],
    [COMMENT => 'comment token'],
    [DOCTYPE => 'DOCTYPE token'],
    [EOF => 'end-of-file token'],
  ) {
    $Data->{tokenizer}->{tokens}->{$_->[1]}->{short_name} = $_->[0];
  }
}

{
  my $tree = json_bytes2perl path (__FILE__)->parent->parent->child ('local/html-tree.json')->slurp;
  $Data->{ims} = $tree->{ims};
  $Data->{tree_steps} = $tree->{steps};
  $Data->{tree_patterns} = $tree->{patterns};
  $Data->{tree_patterns_not} = $tree->{patterns_not};
  $Data->{adjusted_mathml_attr_names} = $tree->{tables}->{'adjust MathML attributes'};
  $Data->{adjusted_svg_attr_names} = $tree->{tables}->{'adjust SVG attributes'};
  $Data->{adjusted_svg_element_names} = $tree->{tables}->{svg_tag_name_mapping};
  $Data->{dispatcher_html} = $tree->{dispatcher_html};
  unshift @{$Data->{dispatcher_html}}, 'or';

  for (keys %{$tree->{tables}->{'adjust foreign attributes'}}) {
    my $def = $tree->{tables}->{'adjust foreign attributes'}->{$_};
    my $ns;
    $ns = q<http://www.w3.org/1999/xlink> if $def->[2] eq 'XLink';
    $ns = q<http://www.w3.org/XML/1998/namespace> if $def->[2] eq 'XML';
    $ns = q<http://www.w3.org/2000/xmlns/> if $def->[2] eq 'XMLNS';
    $Data->{adjusted_ns_attr_names}->{$_} = [$ns, [$def->[0], $def->[1]]];
  }

  $Data->{doctype_switch} = $tree->{doctype_switch};
  $Data->{doctype_switch}->{legacy} = [[undef, 'about:legacy-compat']];
  $Data->{reset_im_by_html_element} = $tree->{reset_im_by_html_element};

  ## <http://www.whatwg.org/specs/web-apps/current-work/#html-fragment-parsing-algorithm>
  for (
    [title => 'RCDATA state'],
    [textarea => 'RCDATA state'],
    [style => 'RAWTEXT state'],
    [xmp => 'RAWTEXT state'],
    [iframe => 'RAWTEXT state'],
    [noembed => 'RAWTEXT state'],
    [noframes => 'RAWTEXT state'],
    [script => 'script data state'],
    [plaintext => 'PLAINTEXT state'],
  ) {
    $Data->{tokenizer}->{initial_state_by_html_element}->{always}->{$_->[0]} = $_->[1];
  }
  $Data->{tokenizer}->{initial_state_by_html_element}->{scripting_flag_is_enabled}->{noscript} = 'RAWTEXT state';

  sub qm ($) {
    my $s = shift;
    $s =~ s/([\\\[\]\{\}\(\)\+\*\?\^\$\@.|])/\\$1/g;
    return $s;
  } # qm
  for (
    $Data->{doctype_switch}->{quirks},
    $Data->{doctype_switch}->{limited_quirks},
  ) {
    for my $key (keys %{$_->{values}}) {
      my $ra = Regexp::Assemble->new;
      $ra->add (qm $_) for keys %{$_->{values}->{$key}};
      $_->{regexp}->{$key} = $ra->re;
      $_->{regexp}->{$key} =~ s/^\(\?\^u:/(?:/g;
      $_->{regexp}->{$key} =~ s/^\(\?-xism:/(?:/g;
      $_->{regexp}->{$key} =~ s{\\/}{/}g;
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
