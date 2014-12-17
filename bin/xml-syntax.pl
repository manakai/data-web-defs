use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $Data = {};

## Public identifiers for XHTML named character references DTD
## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-documents>
for (
  '-//W3C//DTD XHTML 1.0 Transitional//EN',
  '-//W3C//DTD XHTML 1.1//EN',
  '-//W3C//DTD XHTML 1.0 Strict//EN',
  '-//W3C//DTD XHTML 1.0 Frameset//EN',
  '-//W3C//DTD XHTML Basic 1.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN',
  '-//W3C//DTD MathML 2.0//EN',
  '-//WAPFORUM//DTD XHTML Mobile 1.0//EN',
) {
  $Data->{charrefs_pubids}->{$_} = 1;
}

{
  for ('local/html-tokenizer.json',
       'local/html-tokenizer-charrefs-jump.json',
       'local/xml-tokenizer-only.json',
       'local/xml-tokenizer-only2.json',
       'local/xml-tokenizer-replace.json') {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (keys %{$tokenizer->{char_sets} or {}}) {
      $Data->{tokenizer}->{char_sets}->{$_} = $tokenizer->{char_sets}->{$_};
    }
    for (keys %{$tokenizer->{states}}) {
      $Data->{tokenizer}->{states}->{$_} = $tokenizer->{states}->{$_};
    }
  }

  {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child
        ('local/xml-tokenizer-delta.json')->slurp;
    for my $state (keys %{$tokenizer->{states}}) {
      for my $cond (keys %{$tokenizer->{states}->{$state}->{conds}}) {
        $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}
            = $tokenizer->{states}->{$state}->{conds}->{$cond};
      }
    }
  }

  my $tokenizer_charrefs = json_bytes2perl path (__FILE__)->parent->parent->child ('local/html-tokenizer-charrefs.json')->slurp;
  for (
    ['data state', undef],
    ['attribute value (double-quoted) state', '"'],
    ['attribute value (single-quoted) state', "'"],
    ['attribute value (unquoted) state', '<'],
    ['default attribute value (double-quoted) state', '"'],
    ['default attribute value (single-quoted) state', "'"],
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
  delete $Data->{tokenizer}->{states}->{'character reference in attribute value state'};

  ## GCing
  {
    my $referenced = {};
    my @action_list;
    my $visit_state = sub {
      my $s = shift;
      unless ($referenced->{$s}) {
        for (values %{$Data->{tokenizer}->{states}}) {
          for (values %{$Data->{tokenizer}->{states}->{$s}->{conds}}) {
            push @action_list, $_->{actions};
            push @action_list, $_->{false_actions} if defined $_->{false_actions};
          }
        }
      }
      $referenced->{$s} = 1;
    };
    $visit_state->('data state');
    while (@action_list) {
      my $acts = shift @action_list;
      for (@{$acts or []}) {
        $visit_state->($_->{state}) if defined $_->{state};
        push @action_list, $_->{actions} if defined $_->{actions};
        push @action_list, $_->{false_actions} if defined $_->{false_actions};
      }
    }
    my @state = sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}};
    for (@state) {
      unless ($referenced->{$_}) {
        warn "GC: $_ is not referenced\n";
        delete $Data->{tokenizer}->{states}->{$_};
      }
    }
  } ## GCing
}

my @ActionKey = qw(actions false_actions between_actions ws_actions
                   null_actions char_actions ws_char_actions ws_seq_actions
                   null_char_actions null_seq_actions);
sub for_actions (&$);
sub for_actions (&$) {
  my ($code, $acts) = @_;
  my $new_acts = [];
  for (@$acts) {
    my $act = {%$_};
    for (@ActionKey) {
      $act->{$_} = &for_actions ($code, $act->{$_}) if defined $act->{$_};
    }
    push @$new_acts, $act;
  }
  return $code->($new_acts);
} # for_actions

{
  my @state = ('PI state', 'comment state', 'bogus comment state');
  my %state_done;
  while (@state) {
    my $state = shift @state;
    next if $state_done{$state}++;
    for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
      $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if (2 == keys %$act and
              $act->{type} eq 'switch' and defined $act->{state}) {
            if ($act->{state} eq 'data state') {
              $act->{dtd_state} = 'DTD state';
            } else {
              push @state, $act->{state};
            }
          }
        }
        return $acts;
      } $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
    }
  }
}

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
          } elsif (defined $act->{dtd_state}) {
            for (keys %$types) {
              $Data->{tokenizer}->{states}->{$act->{dtd_state}}->{initial_token_types}->{$_} ||= do { $changed = 1; $types->{$_} };
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
        if (defined $act->{field} and not $act->{type} =~ /-to-/) {
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
    [PI => 'processing instruction token'],
    [EOD => 'end-of-DOCTYPE token'],
    [ENTITY => 'ENTITY token'],
    [ATTLIST => 'ATTLIST token'],
    [ELEMENT => 'ELEMENT token'],
    [NOTATION => 'NOTATION token'],
  ) {
    $Data->{tokenizer}->{tokens}->{$_->[1]}->{short_name} = $_->[0];
  }
}

{
  my $tree = json_bytes2perl path (__FILE__)->parent->parent->child ('local/xml-tree.json')->slurp;
  $Data->{ims} = $tree->{ims};
}

$Data->{tree_patterns}->{'HTML element'} ||= {ns => 'HTML'};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
