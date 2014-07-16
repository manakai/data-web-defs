use strict;
use warnings;
use JSON::PS;

my $Data = do {
  local $/ = undef;
  my $data = json_bytes2perl scalar <>;
  $data;
};
delete $Data->{tokenizer};
delete $Data->{$_} for grep { /^adjusted_/ } keys %$Data;

sub for_actions (&$);
sub for_actions (&$) {
  my ($code, $acts) = @_;
  for my $act (@$acts) {
    for (qw(actions false_actions between_actions)) {
      $act->{$_} = &for_actions ($code, $act->{$_}) if defined $act->{$_};
    }
  }
  return $code->($acts);
} # for_actions

sub apply_except ($$) {
  my ($act, $except) = @_;
  if ($act->{while_not} or $act->{until}) {
    $act = {%$act};
    if (2 == keys %$except and 2 == keys %{$act->{while_not}} and
        defined $except->{ns} and
        defined $act->{while_not}->{ns} and
        defined $except->{name} and
        defined $act->{while_not}->{name} and
        $except->{ns} eq $act->{while_not}->{ns}) {
      my @name = ref $act->{while_not}->{name}
          ? @{$act->{while_not}->{name}} : ($act->{while_not}->{name});
      my %except = map { $_ => 1 } ref $except->{name}
          ? @{$except->{name}} : ($except->{name});
      @name = grep { not $except{$_} } @name;
      $act->{while_not} = {%{$act->{while_not}}, name => \@name};
    } else {
      $act->{except} = $except;
    }
    return $act;
  } else {
    return $act;
  }
} # apply_except

for my $step_name (keys %{$Data->{tree_steps}}) {
  $Data->{tree_steps}->{$step_name}->{actions} = for_actions {
    my $acts = shift;
    my $new_acts = [];

    for my $act (@$acts) {
      if (1 == keys %$act and $Data->{tree_steps}->{$act->{type}}) {
        push @$new_acts, @{$Data->{tree_steps}->{$act->{type}}->{actions}};
      } elsif (2 == keys %$act and
               $Data->{tree_steps}->{$act->{type}} and
               defined $act->{except}) {
        push @$new_acts, map {
          apply_except $_, $act->{except}
        } @{$Data->{tree_steps}->{$act->{type}}->{actions}};
      } else {
        push @$new_acts, $act;
      }
    }

    return $new_acts;
  } $Data->{tree_steps}->{$step_name}->{actions};
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
    if ($cond =~ /^(START|END):(.+)$/) {
      $Data->{tag_name_groups}->{$2} = 1;
    } elsif ($cond =~ /^(?:COMMENT|EOF|DOCTYPE|CHAR:0000|CHAR:WS|CHAR-ELSE|START-ELSE|END-ELSE|ELSE)$/) {
      #
    } else {
      die "Unknown cond |$cond|";
    }

    my $def = $Data->{ims}->{$im}->{conds}->{$cond};
    $def->{actions} = for_actions {
      my $acts = shift;
      my $new_acts = [];

      for my $act (@$acts) {
        if (1 == keys %$act and $Data->{tree_steps}->{$act->{type}}) {
          push @$new_acts, @{$Data->{tree_steps}->{$act->{type}}->{actions}};
        } elsif (2 == keys %$act and
                 $Data->{tree_steps}->{$act->{type}} and
                 defined $act->{except}) {
          push @$new_acts, map {
            apply_except $_, $act->{except}
          } @{$Data->{tree_steps}->{$act->{type}}->{actions}};
        } else {
          push @$new_acts, $act;
        }
      }

      return $new_acts;
    } $def->{actions};
  }
}

{
  my $i = 0;
  my $tags = {};
  for (keys %{$Data->{tag_name_groups}}) {
    for (split / /, $_) {
      push @{$tags->{$_}}, $i;
    }
    $i++;
  }
  my $groups = {};
  for (keys %$tags) {
    $groups->{join ' ', @{$tags->{$_}}}->{$_} = 1;
  }
  $Data->{tag_name_groups} = [sort { $a cmp $b } map { join ' ', sort { $a cmp $b } keys %$_ } values %$groups];
  my $tag_name_to_group = {};
  for my $gname (@{$Data->{tag_name_groups}}) {
    for (split / /, $gname) {
      $tag_name_to_group->{$_} = $gname;
    }
  }

  my $changed = 0;
  my $unchanged = 0;
  for my $im (keys %{$Data->{ims}}) {
    my @cond = keys %{$Data->{ims}->{$im}->{conds}};
    for my $cond (@cond) {
      if ($cond =~ /^(START|END):(.+)$/) {
        my $type = $1;
        my %gname;
        $gname{$tag_name_to_group->{$_}} = 1 for split / /, $2;
        my $new_cond = $type . ':' . join ',', sort { $a cmp $b } keys %gname;
        if ($cond eq $new_cond) {
          $unchanged++;
        } else {
          $changed++;
          $Data->{ims}->{$im}->{conds}->{$new_cond}
              = delete $Data->{ims}->{$im}->{conds}->{$cond};
        }
      }
    }

    $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}
        ||= {%{$Data->{ims}->{$im}->{conds}->{ELSE}}};
  }
  #warn "$changed changed, $unchanged unchanged";
}

{
  for my $im (keys %{$Data->{ims}}) {
    my @cond = keys %{$Data->{ims}->{$im}->{conds}};
    for my $cond (@cond) {
      next unless $cond =~ /^CHAR/;
      my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      if ($acts->[-1]->{type} eq 'USING-THE-RULES-FOR' and
          not ref $acts->[-1]->{im} and
          not $acts->[-1]->{foster_parenting}) {
        $Data->{ims}->{$im}->{conds}->{$cond}->{actions}
            = [@$acts[0..($#$acts-1)],
               @{($Data->{ims}->{$acts->[-1]->{im}}->{conds}->{$cond} ||
                  $Data->{ims}->{$acts->[-1]->{im}}->{conds}->{'CHAR-ELSE'})->{actions}}];
        if ($cond eq 'CHAR-ELSE') {
          for my $c (keys %{$Data->{ims}->{$acts->[-1]->{im}}->{conds}}) {
            next unless $c =~ /^CHAR:/;
            $Data->{ims}->{$im}->{conds}->{$c}->{actions}
                ||= [@$acts[0..($#$acts-1)],
                     @{$Data->{ims}->{$acts->[-1]->{im}}->{conds}->{$c}->{actions}}];
          }
        }
      }
    }

    CONDS: {
      my $changed = 0;
      my $check_acts = sub {
        my $acts = shift;
        my $next_im;
        for (@$acts[0..($#$acts-1)]) {
          if ($_->{type} eq 'switch the insertion mode' and not ref $_->{im}) {
            $next_im = $_->{im};
          } elsif ($_->{type} eq 'if') {
            for (@{$_->{actions} or []}, @{$_->{false_actions} or []}) {
              if (not {
                'create an HTML element' => 1,
                'append-to-document' => 1,
                'push-oe' => 1,
                'pop-oe' => 1,
                'appcache-processing' => 1,
                'insert an HTML element' => 1,
                'set-head-element-pointer' => 1,
                'parse error' => 1,
                'set-compat-mode' => 1,
                'set-empty' => 1,
                'set-current-im' => 1,
              }->{$_->{type}}) {
                warn "Unsupported type |$_->{type}|";
                return undef;
              }
            }
          } elsif (not {
            'create an HTML element' => 1,
            'append-to-document' => 1,
            'push-oe' => 1,
            'pop-oe' => 1,
            'appcache-processing' => 1,
            'insert an HTML element' => 1,
            'set-head-element-pointer' => 1,
            'parse error' => 1,
            'set-empty' => 1,
            'set-current-im' => 1,
          }->{$_->{type}}) {
            warn "Unsupported type |$_->{type}|";
            return undef;
          }
        }
        return $next_im;
      }; # $check_acts
      @cond = keys %{$Data->{ims}->{$im}->{conds}};
      COND: for my $cond (@cond) {
        next COND unless $cond =~ /^CHAR/;
        my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
        if ($acts->[-1]->{type} eq 'reprocess the token' and
            1 == keys %{$acts->[-1]}) {
          my $next_im = $check_acts->($acts);
          next COND unless defined $next_im;
          $Data->{ims}->{$im}->{conds}->{$cond}->{actions}
              = [@$acts[0..($#$acts-1)],
                 @{($Data->{ims}->{$next_im}->{conds}->{$cond} ||
                    $Data->{ims}->{$next_im}->{conds}->{'CHAR-ELSE'})->{actions}}];
          if ($cond eq 'CHAR-ELSE') {
            for my $c (keys %{$Data->{ims}->{$next_im}->{conds}}) {
              next unless $c =~ /^CHAR:/;
              $Data->{ims}->{$im}->{conds}->{$c}->{actions}
                  ||= [@$acts[0..($#$acts-1)],
                       @{$Data->{ims}->{$next_im}->{conds}->{$c}->{actions}}];
            }
          }
          $changed = 1;
        } elsif ($acts->[-1]->{type} eq 'if' and
                 @{$acts->[-1]->{actions}} and
                 $acts->[-1]->{actions}->[-1]->{type} eq 'reprocess the token' and
                 1 == keys %{$acts->[-1]->{actions}->[-1]}) {
          my $next_im = $check_acts->($acts->[-1]->{actions});
          next COND unless defined $next_im;
          $acts->[-1]->{actions}
              = [@{$acts->[-1]->{actions}}[0..($#{$acts->[-1]->{actions}}-1)],
                 @{($Data->{ims}->{$next_im}->{conds}->{$cond} ||
                    $Data->{ims}->{$next_im}->{conds}->{'CHAR-ELSE'})->{actions}}];
          if ($cond eq 'CHAR-ELSE') {
            for my $c (keys %{$Data->{ims}->{$next_im}->{conds}}) {
              next unless $c =~ /^CHAR:/;
              next if $Data->{ims}->{$im}->{conds}->{$c}->{actions};
              $Data->{ims}->{$im}->{conds}->{$c}->{actions}
                  = [@{$Data->{ims}->{$im}->{conds}->{$cond}->{actions}}];
              $Data->{ims}->{$im}->{conds}->{$c}->{actions}->[-1]
                  = {%{$Data->{ims}->{$im}->{conds}->{$c}->{actions}->[-1]},
                     actions => [@{$acts->[-1]->{actions}}[0..($#{$acts->[-1]->{actions}}-1)],
                                 @{$Data->{ims}->{$next_im}->{conds}->{$c}->{actions}}]};
            }
          }
          $changed = 1;
        }
      } # COND
      redo CONDS if $changed;
    } # CONDS
  }
}

{
  my $ims = perl2json_chars $Data->{ims};
  my @step_name = keys %{$Data->{tree_steps}};
  for my $step_name (@step_name) {
    unless ($ims =~ /\Q$step_name\E/) {
      delete $Data->{tree_steps}->{$step_name};
    }
  }
  delete $Data->{tree_steps} if not keys %{$Data->{tree_steps}};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

