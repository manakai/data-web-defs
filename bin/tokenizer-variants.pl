use strict;
use warnings;
use JSON::PS;
use Path::Tiny;

local $/ = undef;
my $Data = {tokenizer => (json_bytes2perl <>)->{tokenizer}};

my $Capturing = {
  'set' => 1,
  'set-to-attr' => 1,
  'set-to-temp' => 1,
  'append' => 1,
  'emit-char' => 1,
  'append-to-attr' => 1,
  'append-to-temp' => 1,
};

## Expanding character classes

sub cond_to_charclass ($) {
  my $cond = shift;
  my %c = map { $_ => 1 } split / /, $cond;
  my $r;
  if ($c{ELSE}) {
    my @c;
    for (keys %{$Data->{tokenizer}->{char_classes}}) {
      next if $_ eq 'EOF';
      push @c, $_ unless $c{$_};
    }
    $r = '[^' . (quotemeta join '', sort { $a cmp $b } map { chr hex $_ } map { split /,/, $_ } @c) . ']';
  } else {
    my $c = join '', sort { $a cmp $b } map { chr hex $_ } map { split /,/, $_ } keys %c;
    return quotemeta $c if 1 == length $c;
    $r = '[' . (quotemeta $c) . ']';
  }
  $r =~ s/ABCDEFGHIJKLMNOPQRSTUVWXYZ/A-Z/g;
  $r =~ s/abcdefghijklmnopqrstuvwxyz/a-z/g;
  $r =~ s/0123456789/0-9/;
  return $r;
} # cond_to_charclass

{
  my $chars = {};
  my $char_to_cond_in_state = {};
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
      if ($_ eq 'ELSE') {
        #
      } elsif ($_ eq 'EOF') {
        $char_to_cond_in_state->{$state, -1} = $_;
        $chars->{-1} = 1;
      } elsif ($_ =~ /^CHAR:([0-9A-F]+)/) {
        $char_to_cond_in_state->{$state, hex $1} = $_;
        $chars->{hex $1} = 1;
      } else {
        for my $c (keys %{$Data->{tokenizer}->{char_sets}->{$_}}) {
          $char_to_cond_in_state->{$state, $c} = $_;
          $chars->{$c} = 1;
        }
      }
    }
  }

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for my $c (keys %$chars) {
      $chars->{$c} .= $; . ($char_to_cond_in_state->{$state, $c} || 'ELSE');
    }
  }
  $chars->{0x000A} .= $; . 'dummy';

  my %map;
  for my $c (keys %$chars) {
    $map{$chars->{$c}}->{$c} = 1;
  }

  my $char_to_class = {};
  for (values %map) {
    my $name = join ',', map { $_ == -1 ? 'EOF' : sprintf '%04X', $_ } sort { $a <=> $b } keys %$_;
    $Data->{tokenizer}->{char_classes}->{$name} = $_;
    $char_to_class->{$_} = $name for keys %$_;
  }

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for my $c (keys %$chars) {
      $Data->{tokenizer}->{states}->{$state}->{char_class_to_cond}->{$char_to_class->{$c}} = $char_to_cond_in_state->{$state, $c} || 'ELSE';
    }
  }

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
      my $key = join ' ', sort { $a cmp $b } grep { $Data->{tokenizer}->{states}->{$state}->{char_class_to_cond}->{$_} eq $cond } keys %{$Data->{tokenizer}->{states}->{$state}->{char_class_to_cond}};
      $key .= ' ELSE' if $cond eq 'ELSE';
      $key =~ s/^ //;
      $Data->{tokenizer}->{states}->{$state}->{conds_by_class}->{$key} = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond};
    }
    $Data->{tokenizer}->{states}->{$state}->{conds}
        = delete $Data->{tokenizer}->{states}->{$state}->{conds_by_class};
    delete $Data->{tokenizer}->{states}->{$state}->{char_class_to_cond};
  }
}

## U+000D CR characters

{
  my $need_000D_variant = {};
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    my $state_def = $Data->{tokenizer}->{states}->{$state};
    my $lf_rule = [grep { /\b000A\b/ } keys %{$state_def->{conds}}]->[0]
        or die "|$state| has no rule for U+000A";
    my $acts = $state_def->{conds}->{$lf_rule}->{actions};
    my $next_state;
    my $ignored = 1;
    for (@$acts) {
      if ($_->{type} eq 'switch') {
        $next_state = $_->{state};
        $ignored = 0;
      } else {
        $ignored = 0;
      }
    }
    my $add_000D = 0;
    if ($ignored) {
      $add_000D = 1;
    } elsif (defined $next_state) {
      my $next_state_def = $Data->{tokenizer}->{states}->{$next_state};
      my $next_lf_rule = [grep { /\b000A\b/ } keys %{$next_state_def->{conds}}]->[0]
          or die "|$next_state| has no rule for U+000A";
      my $next_acts = $next_state_def->{conds}->{$next_lf_rule}->{actions};
      my $next_ignored = 1;
      for (@$next_acts) {
        $next_ignored = 0;
      }
      if ($next_ignored) {
        $add_000D = 1;
      }
    }
    if ($add_000D) {
      my $new_cond = join ' ', sort { $a cmp $b } (split / /, $lf_rule), '000D';
      $Data->{tokenizer}->{states}->{$state}->{conds}->{$new_cond}
          = delete $Data->{tokenizer}->{states}->{$state}->{conds}->{$lf_rule};
    } else {
      $next_state //= $state;
      $need_000D_variant->{$next_state} = 1;
      $Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions} = [
        (map {
          if ($_->{break}) {
            if (defined $_->{state}) {
              my $n_state_def = $Data->{tokenizer}->{states}->{$_->{state}};
              my $n_lf_rule = [grep { /\b000A\b/ } keys %{$n_state_def->{conds}}]->[0]
                  or die "|$_->{state}| has no rule for U+000A";
              my $n_acts = $n_state_def->{conds}->{$n_lf_rule}->{actions};
              my $n_ignored = 1;
              for (@$n_acts) {
                $n_ignored = 0;
              }
              if ($n_ignored) {
                $_;
              } else {
                $need_000D_variant->{$_->{state}} = 1;
                +{%$_, state => "$_->{state} after 000D"};
              }
            } else {
              die "|$state| |$lf_rule| has |break| but no |state|";
            }
          } elsif ($_->{type} eq 'switch') {
            ();
          } elsif ($Capturing->{$_->{type}}) {
            +{value => "\x0A", index_offset => 0, %$_}; # e.g. type=emit-char
          } else {
            +{%$_};
          }
        } @{$Data->{tokenizer}->{states}->{$state}->{conds}->{$lf_rule}->{actions}}),
        {type => 'switch', state => "$next_state after 000D"},
      ];
      if (@{$Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}} >= 2 and
          $Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-1]->{type} eq 'switch' and
          $Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-2]->{type} eq 'reconsume') {
        ($Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-2], $Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-1]) = ($Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-1], $Data->{tokenizer}->{states}->{$state}->{conds}->{'000D'}->{actions}->[-2]);
      }
    }
  }
  my $else_key = join ' ', sort { $a cmp $b } grep { $_ ne '000A' } keys %{$Data->{tokenizer}->{char_classes}}, 'ELSE';
  $Data->{tokenizer}->{char_classes}->{'000D'}->{0x000D} = 1;
  for my $state (keys %$need_000D_variant) {
    $Data->{tokenizer}->{states}->{"$state after 000D"}->{conds}->{$else_key}->{actions} = [{type => 'switch', state => $state}, {type => 'reconsume'}];
    $Data->{tokenizer}->{states}->{"$state after 000D"}->{conds}->{'000D'}->{actions} = [{type => 'switch', state => $state}, {type => 'reconsume'}];
    $Data->{tokenizer}->{states}->{"$state after 000D"}->{conds}->{'000A'}->{actions} = [{type => 'switch', state => $state}];
  }
}

## Expanding |reconsume|s

for my $state (keys %{$Data->{tokenizer}->{states}}) {
  for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $next_state;
    my $reconsume;
    for (@{$Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions}}) {
      if ($_->{type} eq 'switch' and not $_->{break}) {
        $next_state = $_->{state};
      } elsif ($_->{type} eq 'reconsume') {
        $reconsume = $_;
      }
    }
    if ($reconsume) {
      if (not defined $next_state) {
        die "Next state not defined for $state $cond";
      }
      $reconsume->{_state} = $next_state;
      $reconsume->{_classes} = [split / /, $cond];
      for my $class (@{$reconsume->{_classes}}) {
        for (keys %{$Data->{tokenizer}->{states}->{$next_state}->{conds}}) {
          if (" $_ " =~ / \Q$class\E /) {
            $reconsume->{_conds}->{$_}->{$class} = 1;
          }
        }
      }
    }
  }
}

{
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    $Data->{tokenizer}->{states}->{$state}->{orig_conds} = $Data->{tokenizer}->{states}->{$state}->{conds};
  }

  my $changed = 0;
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    $Data->{tokenizer}->{states}->{$state}->{new_conds} = {%{$Data->{tokenizer}->{states}->{$state}->{conds}}};
    for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
      my $acts = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions} || [];
      if (@$acts and
          $acts->[-1]->{type} eq 'reconsume' and
          $acts->[-1]->{_conds}) {
        delete $Data->{tokenizer}->{states}->{$state}->{new_conds}->{$cond};
        for my $sub_cond (keys %{$acts->[-1]->{_conds}}) {
          my $sub_acts = $Data->{tokenizer}->{states}->{$acts->[-1]->{_state}}->{orig_conds}->{$sub_cond}->{actions} || [];
          $Data->{tokenizer}->{states}->{$state}->{new_conds}->{join ' ', sort { $a cmp $b } keys %{$acts->[-1]->{_conds}->{$sub_cond}} }->{actions} = [@$acts[0..($#$acts-1)], @$sub_acts];
        }
        $changed = 1;
      }
    }
  }
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    $Data->{tokenizer}->{states}->{$state}->{conds} = delete $Data->{tokenizer}->{states}->{$state}->{new_conds};
  }
  redo if $changed;

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    delete $Data->{tokenizer}->{states}->{$state}->{orig_conds};
  }
}

sub actions_with_capture_index ($$) {
  my ($acts, $index) = @_;
  return [map { $Capturing->{$_->{type}} ? {%$_, capture_index => $index} : $_ } @$acts]
} # actions_with_capture_index

## Setting |repeat| flags

for my $state (keys %{$Data->{tokenizer}->{states}}) {
  COND: for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $acts = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
    my $repeatable = 1;
    my $error = 0;
    my $next_state;
    my $emit = 0;
    my $branched;
    my $capture = 0;
    for (@$acts) {
      if ($_->{type} =~ /^emit/) {
        $emit = 1;
      }
      if ($_->{break} or defined $_->{if}) {
        $branched = 1;
        $repeatable = 0;
      }
      if ($Capturing->{$_->{type}}) {
        $capture = 1 if not defined $_->{value};
      }
      if ({
        'emit-char' => 1,
        'append' => 1,
        'append-to-attr' => 1,
        'append-to-temp' => 1,
      }->{$_->{type}}) {
        $repeatable = 0 if defined $_->{offset};
      } elsif ($_->{type} eq 'parse error') {
        $repeatable = 0;
        $error = 1;
      } elsif ($_->{type} eq 'switch') {
        $repeatable = 0;
        $next_state = $_->{state};
      } else {
        $repeatable = 0;
      }
      $repeatable = 0 if defined $_->{value};
    }
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{repeat} = 1
        if $repeatable;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{capture} = 1
        if $capture;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{error} = 1
        if $error;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{next_state} = $next_state
        if defined $next_state and not $branched;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{emit} = 1
        if $emit and not $branched;
  }
}

## Creating |compound_conds|

#my @path = (map { [{$_ => 1}, $_] } keys %{$Data->{tokenizer}->{states}});
my @path = (map { [{$_ => 1}, $_] } 'tag open state', 'before attribute name state');
my @found;
while (@path) {
  my $path = shift @path;
  my $state = $path->[-1];
#warn "@$path" if @$path;
  for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $c = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond};
    next if $c->{error};
    if ($c->{emit}) {
      push @found, [@$path, $cond, $c->{next_state} // $state];
      next;
    }
    if (defined $c->{next_state}) {
      if ($c->{next_state} eq 'data state' or
          $c->{next_state} eq 'before attribute name state') {
        push @found, [@$path, $cond, $c->{next_state}];
      } elsif ($c->{next_state} eq 'DOCTYPE state' or
               $c->{next_state} =~ /character reference/ or
               $c->{next_state} =~ /000D/) {
        #
      } elsif ($path->[0]->{$c->{next_state}}) {
        push @found, [@$path, $cond, $c->{next_state}];
      } else {
        unshift @path, [@$path, $cond, $c->{next_state}];
        $path[0]->[0] = {%{$path->[0]}, $state => 1};
      }
    }
  }
}
{
  @found = grep { @$_ > 2 } @found;
  FOUND: for (@found) {
    my (undef, $orig_state, @o) = @$_;
    my @pattern;
    my $prev_state = $orig_state;
    my $capture_index = 0;
    while (@o) {
      my ($cond, $state) = (shift @o, shift @o);
      next FOUND if $cond =~ /EOF/;
      my $p = cond_to_charclass $cond;
      my $cond_def = $Data->{tokenizer}->{states}->{$prev_state}->{conds}->{$cond};
      if ($cond_def->{capture}) {
        $p = "($p)";
        push @pattern, [$p, $cond_def->{actions}, ++$capture_index];
      } else {
        push @pattern, [$p, $cond_def->{actions}];
      }

      unless ($state eq 'data state') {
        for my $c (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
          if ($Data->{tokenizer}->{states}->{$state}->{conds}->{$c}->{repeat}) {
            my $p = cond_to_charclass $c;
            $p .= '*';
            my $cond_def = $Data->{tokenizer}->{states}->{$state}->{conds}->{$c};
            if ($cond_def->{capture}) {
              $p = "($p)";
              push @pattern, [$p, $cond_def->{actions}, ++$capture_index];
            } else {
              push @pattern, [$p, $cond_def->{actions}];
            }
          }
        }
      }
      $prev_state = $state;
    }
    $Data->{tokenizer}->{states}->{$orig_state}->{compound_conds}->{join '', map { $_->[0] } @pattern}->{actions} = [map { @$_ } map { actions_with_capture_index $_->[1], $_->[2] } @pattern];
  }
}

for my $state (keys %{$Data->{tokenizer}->{states}}) {
  for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $new_acts = [];
    my $has_switch;
    for (reverse @{$Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions}}) {
      if ($_->{type} eq 'switch' and
          not defined $_->{if} and not $_->{break}) {
        if ($has_switch) {
          #
        } else {
          $has_switch = 1;
          unshift @$new_acts, $_;
        }
      } else {
        unshift @$new_acts, $_;
      }
    }
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions} = $new_acts;
  }
}

$Data->{tokenizer}->{tokens}->{'text token'} = delete $Data->{tokenizer}->{tokens}->{'character token'};
$Data->{tokenizer}->{tokens}->{'text token'}->{short_name} = 'TEXT';

## Merge error type data
{
  my $json = json_bytes2perl path (__FILE__)->parent->parent->child
      ('intermediate/errors/parser-errors.json')->slurp;
  
  my @value = ($Data);
  while (@value) {
    my $value = shift @value;
    next unless defined $value;
    if (ref $value eq 'HASH') {
      if (defined $value->{type} and $value->{type} eq 'parse error') {
        if (defined $value->{name}) {
          my $type = $json->{parser_error_name_to_error_type}->{$value->{name}};
          if (defined $type) {
            $value->{error_type} = $type;
            my $def = $json->{errors}->{$type};
            $value->{error_text} = $def->{text} if defined $def->{text};
            $value->{error_value} = $def->{value} if defined $def->{value};
          } else {
            push @{$Data->{_errors} ||= []},
                sprintf 'Error type for parse error "%s" not defined',
                    $value->{name};
          }
        }
      } else {
        unshift @value, values %$value;
      }
    } elsif (ref $value eq 'ARRAY') {
      unshift @value, @$value;
    }
  }
}

## Cleanup
for my $state (keys %{$Data->{tokenizer}->{states}}) {
  for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    delete $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{$_}
        for qw(capture emit next_state error); # don't remove |repeat|
  }
}
$Data->{tokenizer}->{char_sets} = delete $Data->{tokenizer}->{char_classes};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
