use strict;
use warnings;
use JSON::PS;

local $/ = undef;
my $Data = {tokenizer => (json_bytes2perl <>)->{tokenizer}};

# XXX ALLOWED_CHAR support is missing!

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

for my $state (keys %{$Data->{tokenizer}->{states}}) {
  for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $next_state;
    my $reconsume;
    my $sb;
    for (@{$Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions}}) {
      if ($_->{type} eq 'switch' and not $_->{break}) {
        $next_state = $_->{state};
      } elsif ($_->{type} eq 'switch-back') {
        $sb = 1;
      } elsif ($_->{type} eq 'reconsume') {
        $reconsume = $_;
      }
    }
    if ($reconsume and not defined $sb) {
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
      my $acts = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
      if (@$acts and
          $acts->[-1]->{type} eq 'reconsume' and
          $acts->[-1]->{_conds}) {
        delete $Data->{tokenizer}->{states}->{$state}->{new_conds}->{$cond};
        for my $sub_cond (keys %{$acts->[-1]->{_conds}}) {
          my $sub_acts = $Data->{tokenizer}->{states}->{$acts->[-1]->{_state}}->{orig_conds}->{$sub_cond}->{actions};
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

for my $state (keys %{$Data->{tokenizer}->{states}}) {
  COND: for my $cond (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
    my $acts = $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{actions};
    my $repeatable = 1;
    my $error = 0;
    my $next_state;
    my $emit = 0;
    for (@$acts) {
      if ($_->{type} =~ /^emit/) {
        $emit = 1;
      }
      if ({
        'emit-char' => 1,
        'append' => 1,
        'append-to-attr' => 1,
        'append-to-temp' => 1,
      }->{$_->{type}}) {
        $repeatable = 0 if defined $_->{offset};
      } elsif ($_->{type} eq 'error') {
        $repeatable = 0;
        $error = 1;
      } elsif ($_->{type} eq 'switch') {
        $repeatable = 0;
        $next_state = $_->{state};
      } else {
        $repeatable = 0;
      }
    }
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{repeat} = 1
        if $repeatable;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{error} = 1
        if $error;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{next_state} = $next_state
        if defined $next_state;
    $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}->{emit} = 1
        if $emit;
  }
}

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
               $c->{next_state} =~ /^character reference/) {
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
  my @path;
  FOUND: for (@found) {
    my (undef, $prev_state, @o) = @$_;
    my $pattern = '';
    my @pattern;
    while (@o) {
      my ($cond, $state) = (shift @o, shift @o);
      next FOUND if $cond =~ /EOF/;
      my $p = cond_to_charclass $cond;
      $pattern .= $p;
      push @pattern, [$p, $prev_state, $cond];

      unless ($state eq 'data state') {
        for my $c (sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
          if ($Data->{tokenizer}->{states}->{$state}->{conds}->{$c}->{repeat}) {
            my $p = cond_to_charclass $c;
            $p .= '*';
            $pattern .= $p;
            push @pattern, [$p, $state, $c];
          }
        }
      }
      $prev_state = $state;
    }
    push @path, [$pattern, \@pattern];
  }
  $Data->{_path} = \@path;
}

$Data->{tokenizer}->{char_sets} = delete $Data->{tokenizer}->{char_classes};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
