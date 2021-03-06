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

## Also in |extract-html-tokenizer.pl|.
sub error_name ($$) {
  my $name = my $name_orig = shift;
  my $cond = shift;
  $name =~ s/^.+ state - ((?:before |)text declaration in markup declaration state)/$1/;
  $name =~ s/ state$//;
  $name .= '-' . $cond;
  $name =~ s/CHAR://;
  $name =~ s/WS:[A-Z]+/WS/;
  $name = lc $name;
  $name =~ s/([^a-z0-9]+)/-/g;
  $name = 'EOF' if $name =~ /-eof$/ and not $name_orig =~ /before ATTLIST attribute default state/;
  $name = 'NULL' if $name =~ /-0000$/;
  return $name;
} # error_name

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
  for ('local/html-tokenizer.json',
       'local/html-tokenizer-charrefs-jump.json',
       'local/xml-tokenizer-only.json',
       'local/xml-tokenizer-only2.json',
       'local/tokenizer-pi.json',
       'local/xml-tokenizer-replace.json') {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (sort { $a cmp $b } keys %{$tokenizer->{char_sets} or {}}) {
      $Data->{tokenizer}->{char_sets}->{$_} = $tokenizer->{char_sets}->{$_};
    }
    for (sort { $a cmp $b } keys %{$tokenizer->{states}}) {
      $Data->{tokenizer}->{states}->{$_} = $tokenizer->{states}->{$_};
    }
  }
  for ('local/html-old-tokenizer.json') {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (sort { $a cmp $b } keys %{$tokenizer->{char_sets} or {}}) {
      $Data->{tokenizer}->{char_sets}->{$_} = $tokenizer->{char_sets}->{$_};
    }
    for (sort { $a cmp $b } grep { /^(?:bogus |)comment/ } keys %{$tokenizer->{states}}) {
      $Data->{tokenizer}->{states}->{$_} = $tokenizer->{states}->{$_};
    }
  }

  ## Ignore states introduced by
  ## <https://github.com/whatwg/html/commit/6c629ac9e5736cdb824293999673de6a0f5ea06d>
  ## and
  ## <https://github.com/whatwg/html/commit/7d3201282d31c30cdba2583445d3727a94390286>.
  for (
    'character reference state',
    'numeric character reference state',
    'hexadecimal character reference start state',
    'hexademical character reference start state',
    'decimal character reference start state',
    'hexadecimal character reference state',
    'hexademical character reference state',
    'decimal character reference state',
    'numeric character reference end state',
    'character reference end state',
    'named character reference state',
  ) {
    delete $Data->{tokenizer}->{states}->{$_};
  }

  {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child
        ('local/xml-tokenizer-delta.json')->slurp;
    for my $state (sort { $a cmp $b } keys %{$tokenizer->{states}}) {
      for my $cond (sort { $a cmp $b } keys %{$tokenizer->{states}->{$state}->{conds}}) {
        $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}
            = $tokenizer->{states}->{$state}->{conds}->{$cond};
      }
    }
  }

  for (
    #['attribute name state', 'CHAR:002F'], # /
    #['attribute name state', 'CHAR:003E'], # >
    ['after attribute name state', 'CHAR:002F'], # /
    ['after attribute name state', 'CHAR:003E'], # >
    ['after attribute name state', 'ELSE'],
    #['before attribute value state', 'CHAR:0026'], # &
    ['before attribute value state', 'ELSE'],
  ) {
    my ($state, $cond) = @$_;
    my $acts = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
    unless (defined $acts) {
      die "$state / $cond is not defined";
    }
    unless (@$acts and $acts->[0]->{type} eq 'parse error') {
      unshift @$acts, {type => 'parse error',
                       name => error_name $state, $cond};
    }
  }

  my $tokenizer_charrefs = do {
    my $json1 = json_bytes2perl path (__FILE__)->parent->parent->child ('local/html-tokenizer-charrefs.json')->slurp;
    my $json2 = json_bytes2perl path (__FILE__)->parent->parent->child ('local/xml-tokenizer-charrefs-replace.json')->slurp;
    for (sort { $a cmp $b } keys %{$json2->{states}}) {
      $json1->{states}->{$_} = $json2->{states}->{$_};
    }

    for (
      ['character reference number state', 'CHAR:0058'], # X
    ) {
      my ($state, $cond) = @$_;
      my $acts = $json1->{states}->{$state}->{conds}->{$cond}->{actions};
      unless (@$acts and $acts->[0]->{type} eq 'parse error') {
        unshift @$acts, {type => 'parse error',
                         name => error_name $state, $cond};
      }
    }

    $json1;
  };
  for (
    ['data state', undef],
    ['attribute value (double-quoted) state', '"'],
    ['attribute value (single-quoted) state', "'"],
    ['attribute value (unquoted) state', '<'],
    ['attribute value in entity state', undef],
    ['default attribute value (double-quoted) state', '"'],
    ['default attribute value (single-quoted) state', "'"],
    ['default attribute value in entity state', undef],
    ['ENTITY value (double-quoted) state', '"'],
    ['ENTITY value (single-quoted) state', "'"],
    ['ENTITY value in entity state', undef],
  ) {
    my ($orig_state, $additional) = @$_;
    for my $state (sort { $a cmp $b } keys %{$tokenizer_charrefs->{states}}) {
      if ($Data->{tokenizer}->{states}->{"$orig_state - $state"}) {
        for my $cond (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}->{"$orig_state - $state"}->{conds}}) {
          my $acts = $Data->{tokenizer}->{states}->{"$orig_state - $state"}->{conds}->{$cond}->{actions};
          for my $act (@$acts) {
            if ($act->{type} eq 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR') {
              if ($orig_state =~ /ENTITY value/) {
                $act = {type => 'append-temp', field => 'value'};
              } elsif ($orig_state =~ /attribute/) {
                $act = {type => 'append-temp-to-attr', field => $act->{field}};
              } else {
                $act = {type => 'emit-temp'};
              }
            }
          }
        }
      } else {
        for my $cond (sort { $a cmp $b } keys %{$tokenizer_charrefs->{states}->{$state}->{conds}}) {
          my $def = $tokenizer_charrefs->{states}->{$state}->{conds}->{$cond};
          my $acts = [map {
            if ($_->{type} eq 'SWITCH-BACK') {
              +{%$_, type => 'switch', state => $orig_state};
            } elsif ($_->{type} eq 'switch') {
              +{%$_, state => "$orig_state - $_->{state}"};
            } elsif ($_->{type} =~ /^process-temp-as-/) {
              if ($orig_state =~ /ENTITY value/) {
                if ($orig_state =~ /default attribute/) {
                  +{%$_, in_entity_value => 1, in_attr => 1, in_default_attr => 1};
                } elsif ($orig_state =~ /attribute/) {
                  +{%$_, in_entity_value => 1, in_attr => 1};
                } else {
                  +{%$_, in_entity_value => 1};
                }
              } elsif ($orig_state =~ /default attribute/) {
                +{%$_, in_attr => 1, in_default_attr => 1};
              } elsif ($orig_state =~ /attribute/) {
                +{%$_, in_attr => 1};
              } else {
                +{%$_};
              }
            } elsif ($_->{type} eq 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR') {
              if ($orig_state =~ /ENTITY value/) {
                +{type => 'append-temp', field => 'value'};
              } elsif ($orig_state =~ /attribute/) {
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
    } # $state
  }
  delete $Data->{tokenizer}->{states}->{'character reference in attribute value state'};

  {
    my @state = ('PI state', 'comment start state', 'bogus comment state');
    my %state_done;
    while (@state) {
      my $state = shift @state;
      next if $state_done{$state}++;
      my $new_state = "DOCTYPE $state";
      for my $cond (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
        $Data->{tokenizer}->{states}->{$new_state}->{conds}->{$cond}->{actions} = for_actions {
          my $acts = shift;
          my $new_acts = [];
          for (@$acts) {
            my $act = {%$_};
            if (2 == keys %$act and
                $act->{type} eq 'switch' and defined $act->{state}) {
              if ($act->{state} eq 'data state') {
                $act->{state} = 'DTD state';
              } else {
                push @state, $act->{state};
                $act->{state} = "DOCTYPE $act->{state}";
              }
            } elsif ($cond eq 'EOF' and $act->{type} eq 'parse error' and
                     2 == keys %$act) {
              next;
            }
            push @$new_acts, $act;
          }
          return $new_acts;
        } $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
      }
    }
  }

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
    $visit_state->('attribute value in entity state');
    $visit_state->('default attribute value in entity state');
    $visit_state->('ENTITY value in entity state');
    $visit_state->('before ENTITY value in entity state');
    for (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}}) {
      if (/before text declaration in markup declaration state/) {
        $visit_state->($_);
      }
    }
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

{
  my $changed = 0;
  for my $state (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}}) {
    my $state_def = $Data->{tokenizer}->{states}->{$state};
    for my $cond (sort { $a cmp $b } keys %{$state_def->{conds}}) {
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
            for (sort { $a cmp $b } keys %$types) {
              $Data->{tokenizer}->{states}->{$act->{state}}->{initial_token_types}->{$_} ||= do { $changed = 1; $types->{$_} };
            }
          } elsif (defined $act->{dtd_state}) {
            for (sort { $a cmp $b } keys %$types) {
              $Data->{tokenizer}->{states}->{$act->{dtd_state}}->{initial_token_types}->{$_} ||= do { $changed = 1; $types->{$_} };
            }
          } else {
            $last_state = $act->{state};
          }
        } elsif ($act->{type} eq 'switch-and-emit') {
          #
        }
      }
      for (sort { $a cmp $b } keys %$types) {
        my $value = ($last_state eq 'data state' and $cond eq 'EOF') ? -1 : $types->{$_};
        $Data->{tokenizer}->{states}->{$last_state}->{initial_token_types}->{$_} ||= do { $changed = 1; $value };
      }
    }
  }
  redo if $changed;
}

{
  for my $state (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}}) {
    my $state_def = $Data->{tokenizer}->{states}->{$state};
    for my $cond (sort { $a cmp $b } keys %{$state_def->{conds}}) {
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
          $Data->{tokenizer}->{tokens}->{$_}->{fields}->{$act->{field}} = 1 for sort { $a cmp $b } keys %$types;
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
