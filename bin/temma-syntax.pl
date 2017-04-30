use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $Data = {};

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
       'local/temma-tokenizer-replace.json',
       #'local/tokenizer-pi.json',
      ) {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (keys %{$tokenizer->{char_sets} or {}}) {
      $Data->{tokenizer}->{char_sets}->{$_} = $tokenizer->{char_sets}->{$_};
    }
    for (keys %{$tokenizer->{states}}) {
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
        ('local/temma-tokenizer-delta.json')->slurp;
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
    ['RCDATA state', undef],
    ['attribute value (double-quoted) state', '"'],
    ['attribute value (single-quoted) state', "'"],
    ['attribute value (unquoted) state', '<'],
  ) {
    my ($orig_state, $additional) = @$_;
    for my $state (keys %{$tokenizer_charrefs->{states}}) {
      if ($Data->{tokenizer}->{states}->{"$orig_state - $state"}) {
        for my $cond (keys %{$Data->{tokenizer}->{states}->{"$orig_state - $state"}->{conds}}) {
          my $acts = $Data->{tokenizer}->{states}->{"$orig_state - $state"}->{conds}->{$cond}->{actions};
          for my $act (@$acts) {
            if ($act->{type} eq 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR') {
              if ($orig_state =~ /attribute/) {
                $act = {type => 'append-temp-to-attr', field => $act->{field}};
              } else {
                $act = {type => 'emit-temp'};
              }
            }
          }
        }
      } else {
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
    } # $state
  }
  delete $Data->{tokenizer}->{states}->{'character reference in attribute value state'};
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
  ) {
    $Data->{tokenizer}->{tokens}->{$_->[1]}->{short_name} = $_->[0];
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
