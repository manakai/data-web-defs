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
    for (qw(actions false_actions between_actions ws_actions null_actions
            char_actions ws_char_actions ws_seq_actions
            null_char_actions null_seq_actions)) {
      $act->{$_} = &for_actions ($code, $act->{$_}) if defined $act->{$_};
    }
  }
  return $code->($acts);
} # for_actions

sub apply_except ($$) {
  my ($act, $except) = @_;
  if ($act->{while} or $act->{while_not} or $act->{until}) {
    $act = {%$act};
    my $while = $act->{while} ? 'while' : 'while_not';
    if (2 == keys %$except and 2 == keys %{$act->{$while}} and
        defined $except->{ns} and
        defined $act->{$while}->{ns} and
        defined $except->{name} and
        defined $act->{$while}->{name} and
        $except->{ns} eq $act->{$while}->{ns}) {
      my @name = ref $act->{$while}->{name}
          ? @{$act->{$while}->{name}} : ($act->{$while}->{name});
      my %except = map { $_ => 1 } ref $except->{name}
          ? @{$except->{name}} : ($except->{name});
      @name = grep { not $except{$_} } @name;
      $act->{$while} = {%{$act->{$while}}, name => \@name};
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
    my $found = {START => {}, END => {}};
    for my $cond (@cond) {
      if ($cond =~ /^(START|END):(.+)$/) {
        my $type = $1;
        my %gname;
        $gname{$tag_name_to_group->{$_}} = 1 for split / /, $2;
        my $new_cond = $type . ':' . join ',', sort { $a cmp $b } keys %gname;
        $found->{$type}->{$_} = 1 for keys %gname;
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
  my $ims = {};
  IM: for my $im (keys %{$Data->{ims}}) {
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
    $ims->{$im} = {conds => {%{$Data->{ims}->{$im}->{conds}}}};

    MERGE: {
      WS_PREFIX_ELSE_SWITCH: {
        if (defined $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'} and
            defined $Data->{ims}->{$im}->{conds}->{'CHAR:WS'} and
            not defined $Data->{ims}->{$im}->{conds}->{'CHAR:0000'}) {
          for (@{$Data->{ims}->{$im}->{conds}->{'CHAR:WS'}->{actions}}) {
            unless ({
              'reconstruct the active formatting elements' => 1,
              'insert a character' => 1,
              'ignore the token' => 1,
            }->{$_->{type}}) {
              last WS_PREFIX_ELSE_SWITCH;
            }
          }
          my $next_im;
          for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}}) {
            if ({
              'parse error' => 1,
              'create an HTML element' => 1,
              'insert an HTML element' => 1,
              'set-head-element-pointer' => 1,
              'append-to-document' => 1,
              'push-oe' => 1,
              'pop-oe' => 1,
              'appcache-processing' => 1,
            }->{$_->{type}}) {
              #
            } elsif ($_->{type} eq 'switch the insertion mode' and
                     not ref $_->{im}) {
              $next_im = $_->{im};
            } elsif ($_->{type} eq 'if') {
              for (@{$_->{actions}}, @{$_->{false_actions} or []}) {
                if ({
                  'parse error' => 1,
                  'set-compat-mode' => 1,
                }->{$_->{type}}) {
                  #
                } else {
                  last WS_PREFIX_ELSE_SWITCH;
                }
              }
            } elsif ($_->{type} eq 'reprocess the token' and 1 == keys %$_) {
              #
            } else {
              last WS_PREFIX_ELSE_SWITCH;
            }
          }
          last WS_PREFIX_ELSE_SWITCH
              if not defined $next_im or
                 not $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[-1]->{type} eq 'reprocess the token';

          $ims->{$im}->{conds}->{TEXT}->{actions}
              = [{type => 'text-with-optional-ws-prefix',
                  ws_actions => [map { (1 == keys %$_ and $_->{type} eq 'insert a character') ? {type => 'insert-chars'} : $_ } @{$Data->{ims}->{$im}->{conds}->{'CHAR:WS'}->{actions}}],
                  actions => [@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}}]}];
          $ims->{$im}->{conds}->{TEXT}->{actions}->[-1]->{actions}->[-1]
              = {type => 'USING-THE-RULES-FOR', im => $next_im};
          delete $ims->{$im}->{conds}->{'CHAR:WS'};
          delete $ims->{$im}->{conds}->{'CHAR-ELSE'};
          last MERGE;
        }
      } # WS_PREFIX_ELSE_SWITCH

      NO_SWITCH: {
        my $for_each_char = {};
        my $entire = {};
        for my $key ('CHAR:WS', 'CHAR:0000', 'CHAR-ELSE') {
          for (@{($Data->{ims}->{$im}->{conds}->{$key} or {})->{actions} or []}) {
            if ({
              'parse error' => 1,
            }->{$_->{type}}) {
              push @{$for_each_char->{$key} ||= []}, $_;
            } elsif ({
              'reconstruct the active formatting elements' => 1,
              'set-false' => 1,
              'append-to-pending-table-character-tokens-list' => 1,
            }->{$_->{type}}) {
              push @{$entire->{$key} ||= []}, $_;
            } elsif ($_->{type} eq 'insert a character') {
              push @{$entire->{$key} ||= []}, {type => 'insert-chars'};
            } elsif ($_->{type} eq 'ignore the token') {
              #
            } else {
              last NO_SWITCH;
            }
          }
        }

        my $act = {type => 'process-chars'};
        $ims->{$im}->{conds}->{TEXT}->{actions} = [$act];

        $act->{ws_char_actions} = $for_each_char->{'CHAR:WS'}
            if @{$for_each_char->{'CHAR:WS'} or []};
        $act->{ws_seq_actions} = $entire->{'CHAR:WS'}
            if @{$entire->{'CHAR:WS'} or []};

        $act->{null_char_actions} = $for_each_char->{'CHAR:0000'}
            if @{$for_each_char->{'CHAR:0000'} or []};
        $act->{null_seq_actions} = $entire->{'CHAR:0000'}
            if @{$entire->{'CHAR:0000'} or []};

        $act->{char_actions} = $for_each_char->{'CHAR-ELSE'}
            if @{$for_each_char->{'CHAR-ELSE'} or []};
        $act->{actions} = $entire->{'CHAR-ELSE'} || [];
        
        delete $ims->{$im}->{conds}->{'CHAR:WS'};
        delete $ims->{$im}->{conds}->{'CHAR:0000'};
        delete $ims->{$im}->{conds}->{'CHAR-ELSE'};
        last MERGE;
      } # NO_SWITCH

      COLGROUP: {
        last COLGROUP if defined $Data->{ims}->{$im}->{conds}->{'CHAR:0000'};
        last COLGROUP if not defined $Data->{ims}->{$im}->{conds}->{'CHAR:WS'};
        last COLGROUP unless
            @{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}} == 1 and
            $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{type} eq 'if' and
            $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{cond}->[0] =~ /^oe/;
        my $for_each_ws = [];
        my $entire_ws = [];
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR:WS'}->{actions} or []}) {
          if ({
            'insert a character' => 1,
          }->{$_->{type}}) {
            push @$entire_ws, {type => 'insert-chars'};
          } else {
            last COLGROUP;
          }
        }
        my $for_each_else = [];
        my $entire_else = [];
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{actions} or []}) {
          if ({
            'parse error' => 1,
          }->{$_->{type}}) {
            push @$for_each_else, $_;
          } elsif ($_->{type} eq 'ignore the token') {
            #
          } else {
            last COLGROUP;
          }
        }
        my $next_im;
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{false_actions} or []}) {
          if ({
            'parse error' => 1,
            'pop-oe' => 1,
          }->{$_->{type}}) {
            #
          } elsif ($_->{type} eq 'switch the insertion mode' and
                   not ref $_->{im}) {
            $next_im = $_->{im};
          } elsif ($_->{type} eq 'reprocess the token' and 1 == keys %$_) {
            #
          } else {
            last COLGROUP;
          }
        }
        last COLGROUP unless defined $next_im;

        my $false_act = {type => 'text-with-optional-ws-prefix',
                         ws_actions => [map { (1 == keys %$_ and $_->{type} eq 'insert a character') ? {type => 'insert-chars'} : $_ } @{$Data->{ims}->{$im}->{conds}->{'CHAR:WS'}->{actions}}],
                         actions => [@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{false_actions}}]};
        $false_act->{actions}->[-1]
            = {type => 'USING-THE-RULES-FOR', im => $next_im};
        my $true_act = {type => 'process-chars'};
        $true_act->{actions} = $entire_else || [];
        $true_act->{char_actions} = $for_each_else if @$for_each_else;
        $true_act->{ws_seq_actions} = $entire_ws if @$entire_ws;
        $true_act->{ws_char_actions} = $for_each_ws if @$for_each_ws;
        $ims->{$im}->{conds}->{TEXT}->{actions}
            = [{%{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]},
                actions => [$true_act], false_actions => [$false_act]}];
        delete $ims->{$im}->{conds}->{'CHAR:WS'};
        delete $ims->{$im}->{conds}->{'CHAR-ELSE'};
        last MERGE;
      } # COLGROUP

      TABLE: {
        last TABLE if defined $Data->{ims}->{$im}->{conds}->{'CHAR:0000'};
        last TABLE if defined $Data->{ims}->{$im}->{conds}->{'CHAR:WS'};
        last TABLE unless
            @{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}} == 1 and
            $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{type} eq 'if' and
            $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{cond}->[0] =~ /^oe/;
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{actions}}) {
          unless ({
            'set-current-im' => 1,
            'set-empty' => 1,
            'switch the insertion mode' => 1,
            'reprocess the token' => 1,
          }->{$_->{type}}) {
            last TABLE;
          }
        }
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[0]->{false_actions} or []}) {
          unless ({
            'parse error' => 1,
            'USING-THE-RULES-FOR' => 1,
          }->{$_->{type}}) {
            last TABLE;
          }
        }

        $ims->{$im}->{conds}->{TEXT} = delete $ims->{$im}->{conds}->{'CHAR-ELSE'};
        last MERGE;
      } # TABLE
    } # MERGE
  }

  {
    my $changed = 0;
    for my $im (keys %$ims) {
      next unless defined $ims->{$im}->{conds}->{TEXT};
      $ims->{$im}->{conds}->{TEXT}->{actions}->[0]->{actions} = for_actions {
        my $acts = shift;
        my $new_acts = [];
        for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              not $act->{foster_parenting} and
              not ref $act->{im}) {
            if ({
              'in body' => 1, 'in table' => 1,
              'text' => 1, 'in table text' => 1,
            }->{$act->{im}}) {
              push @$new_acts, {type => 'reprocess the token'};
            } else {
              my @act = @{$ims->{$act->{im}}->{conds}->{TEXT}->{actions}};
              if (@act == 1 and $act[0]->{type} eq 'text-with-optional-ws-prefix') {
                push @$new_acts, @{$act[0]->{actions}};
              } else {
                push @$new_acts, @act;
              }
            }
            $changed = 1;
          } else {
            push @$new_acts, $act;
          }
        }
        return $new_acts;
      } $ims->{$im}->{conds}->{TEXT}->{actions}->[0]->{actions}
          if @{$ims->{$im}->{conds}->{TEXT}->{actions}} and
             $ims->{$im}->{conds}->{TEXT}->{actions}->[0]->{type} eq 'text-with-optional-ws-prefix';
    }
    redo if $changed;
  }

  for my $im (keys %$ims) {
    next unless defined $ims->{$im}->{conds}->{TEXT};
    $ims->{$im}->{conds}->{TEXT}->{actions} = for_actions {
      my $acts = shift;
      my $next_im;
      for my $act (@$acts) {
        if ($act->{type} eq 'USING-THE-RULES-FOR' and
            not $act->{foster_parenting} and
            not ref $act->{im} and
            $act->{im} eq $next_im) {
          $act->{type} = 'reprocess the token';
          delete $act->{im};
        } elsif ($act->{type} eq 'switch the insertion mode') {
          $next_im = $act->{im};
        }
      }
      return $acts;
    } $ims->{$im}->{conds}->{TEXT}->{actions};
  }

  $Data->{ims} = $ims;
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

