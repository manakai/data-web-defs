use strict;
use warnings;
no warnings 'utf8';
use warnings FATAL => 'recursion';
use JSON::PS;
use Path::Tiny;

my $LANG = $ENV{PARSER_LANG} || 'HTML';

my $Data = do {
  local $/ = undef;
  my $data = json_bytes2perl scalar <>;
  $data;
};
delete $Data->{tokenizer};
delete $Data->{$_} for grep { /^adjusted_/ } keys %$Data;
my $NoIsindex = $ENV{NO_ISINDEX};

my $ELDefs = json_bytes2perl path (__FILE__)->parent->parent->child ('data/elements.json')->slurp;

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

sub foster_parenting_actions ($) {
  return for_actions {
    my $acts = shift;
    my $new_acts = [];
    for my $act (@$acts) {
      if ({
        'insert-chars' => 1,
        'insert an HTML element' => 1,
        'insert a foreign element' => 1,
        'reconstruct the active formatting elements' => 1,
        'adoption agency algorithm' => 1,
        'USING-THE-RULES-FOR' => 1,
      }->{$act->{type}}) {
        push @$new_acts, {%$act, foster_parenting => 1};
      } else {
        push @$new_acts, $act;
      }
    }
    return $new_acts;
  } shift;
} # foster_parenting_actions

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

# XXX HTML only
## For invoking the steps to reset the form owner
for my $cat ('form-associated element', 'category-form-attr') {
  my @el;
  for my $namespace (keys %{$ELDefs->{categories}->{$cat}->{elements}}) {
    die unless $namespace eq 'http://www.w3.org/1999/xhtml';
    my $names = [keys %{$ELDefs->{categories}->{$cat}->{elements}->{$namespace}}];
    $Data->{tree_patterns}->{$cat} = {ns => 'HTML', name => $names};
    $Data->{tag_name_groups}->{join ' ', @$names} = 1
        if $cat eq 'form-associated element';
  }
}

## For popping elements off the stack of open elements
{
  my $names = [];
  for my $ns (keys %{$ELDefs->{elements}}) {
    for my $ln (keys %{$ELDefs->{elements}->{$ns}}) {
      if ($ELDefs->{elements}->{$ns}->{$ln}->{has_popped_action}) {
        die unless $ns eq 'http://www.w3.org/1999/xhtml';
        push @$names, $ln;
      }
    }
  }
  $Data->{tree_patterns}->{has_popped_action} = {ns => 'HTML', name => $names};
  #$Data->{tag_name_groups}->{join ' ', @$names} = 1;
}

if ($NoIsindex) {
  for my $im (keys %{$Data->{ims}}) {
    delete $Data->{ims}->{$im}->{conds}->{'START:isindex'};
    for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
      if ($cond =~ /isindex/) {
        die $cond;
      }
    }
  }
  @{$Data->{tree_patterns}->{'special category'}->[1]->{name}} = grep { $_ ne 'isindex' } @{$Data->{tree_patterns}->{'special category'}->[1]->{name}};
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
    if ($cond =~ /^(START|END):(.+)$/) {
      $Data->{tag_name_groups}->{$2} = 1;
    } elsif ($cond =~ /^(?:COMMENT|EOF|DOCTYPE|CHAR:0000|CHAR:WS|CHAR-ELSE|START-ELSE|END-ELSE|PI|PI:xml|ELEMENT|ATTLIST|ENTITY|NOTATION|EOD|ELSE)$/) {
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
        } elsif ($act->{type} eq 'reprocess the token' and
                 @$new_acts and
                 $new_acts->[-1]->{type} eq "change the token's tag name") {
          my $tag_name = $new_acts->[-1]->{tag_name};
          pop @$new_acts;
          push @$new_acts, map {
            if ($_->{type} eq 'insert an HTML element') {
              +{%$_, tag_name => $tag_name};
            } else {
              $_;
            }
          } @{$Data->{ims}->{$im}->{conds}->{[grep { /^START:.*\b\Q$tag_name\E\b/ } keys %{$Data->{ims}->{$im}->{conds}}]->[0]}->{actions}};
        } else {
          push @$new_acts, $act;
        }
      }

      return $new_acts;
    } $def->{actions};
  }
}

my $tag_name_to_group = {};
{
  my @cond;
  push @cond, $Data->{dispatcher_html} if defined $Data->{dispatcher_html};
  while (@cond) {
    my $cond = shift @cond;
    if ($cond->[0] eq 'token tag_name') {
      if (ref $cond->[2]) {
        $Data->{tag_name_groups}->{join ' ', sort { $a cmp $b } @{$cond->[2]}} = 1;
      } else {
        $Data->{tag_name_groups}->{$cond->[2]} = 1;
      }
    } elsif ($cond->[0] eq 'or' or $cond->[0] eq 'and') {
      unshift @cond, @$cond[1..$#$cond];
    }
  }

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

    #for my $key ('START', 'END') {
    #  my $else_groups = [grep { not $found->{$key}->{$_} } @{$Data->{tag_name_groups}}];
    #}

    for ('CHAR-ELSE', 'START-ELSE', 'END-ELSE',
         'DOCTYPE', 'COMMENT', 'EOF',
         ($LANG eq 'XML' ? ('PI', 'ELEMENT', 'ATTLIST', 'ENTITY', 'NOTATION', 'EOD') : ())) {
      $Data->{ims}->{$im}->{conds}->{$_}
          ||= {%{$Data->{ims}->{$im}->{conds}->{ELSE} or {}}};
    }
    delete $Data->{ims}->{$im}->{conds}->{ELSE};
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
              'ignore the token' => 1,
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
              warn "Can't merge |CHAR| rules because of |$_->{type}|.\n";
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
            } elsif ($_->{type} eq 'insert a character' and
                     1 == keys %$_) {
              push @{$entire->{$key} ||= []}, {type => 'insert-chars'};
            } elsif ($_->{type} eq 'insert a character' and
                     defined $_->{value} and
                     2 == keys %$_) {
              push @{$for_each_char->{$key} ||= []}, $_;
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

      ELSEONLY: {
        last ELSEONLY if defined $Data->{ims}->{$im}->{conds}->{'CHAR:0000'};
        last ELSEONLY if defined $Data->{ims}->{$im}->{conds}->{'CHAR:WS'};
        last ELSEONLY unless
            @{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}} and
            $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}->[-1]->{type} eq 'reprocess the token';
        for (@{$Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}}) {
          unless ({
            'the XML declaration is missing' => 1,
            'switch the insertion mode' => 1,
            'reprocess the token' => 1,
          }->{$_->{type}}) {
            last ELSEONLY;
          }
        }

        $ims->{$im}->{conds}->{TEXT} = delete $ims->{$im}->{conds}->{'CHAR-ELSE'};
        last MERGE;
      } # ELSEONLY
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
              ## $new_acts[-1]->{type} is 'switch the insertion mode'.
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
  } # $changed

  for my $im (keys %$ims) {
    next unless defined $ims->{$im}->{conds}->{TEXT};
    $ims->{$im}->{conds}->{TEXT}->{actions} = for_actions {
      my $acts = shift;
      my $new_acts = [];
      my $next_im;
      for my $act (@$acts) {
        if ($act->{type} eq 'USING-THE-RULES-FOR' and
            not $act->{foster_parenting} and
            not ref $act->{im} and
            defined $next_im and
            $act->{im} eq $next_im) {
          push @$new_acts, {type => 'reprocess the token'};
        } elsif ($act->{type} eq 'USING-THE-RULES-FOR' and
                 $act->{foster_parenting}) {
          push @$new_acts, @{foster_parenting_actions $ims->{$act->{im}}->{conds}->{TEXT}->{actions}};
        } elsif ($act->{type} eq 'switch the insertion mode') {
          $next_im = $act->{im};
          push @$new_acts, $act;
        } elsif ($act->{type} eq 'ignore the token') {
          #
        } else {
          push @$new_acts, $act;
        }
      }
      return $new_acts;
    } $ims->{$im}->{conds}->{TEXT}->{actions};
  }

  $Data->{ims} = $ims;
}

for my $token_type (qw(COMMENT DOCTYPE EOF),
                    ($LANG eq 'XML' ? ('PI', 'ELEMENT', 'ATTLIST', 'ENTITY', 'NOTATION', 'EOD') : ())) {
  {
    my $changed = 0;
    for my $im (keys %{$Data->{ims}}) {
      next unless defined $Data->{ims}->{$im}->{conds}->{$token_type};

      if (defined $Data->{ims}->{$im}->{conds}->{$token_type}->{actions} and
          @{$Data->{ims}->{$im}->{conds}->{$token_type}->{actions}} == 1 and
          $Data->{ims}->{$im}->{conds}->{$token_type}->{actions}->[0]->{type} eq 'USING-THE-RULES-FOR' and
          2 == keys %{$Data->{ims}->{$im}->{conds}->{$token_type}->{actions}->[0]} and
          defined $Data->{ims}->{$im}->{conds}->{$token_type}->{actions}->[0]->{im} and
          not ref $Data->{ims}->{$im}->{conds}->{$token_type}->{actions}->[0]->{im}) {
        $Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}
            = $Data->{ims}->{$im}->{conds}->{$token_type}->{actions}->[0]->{im};
        delete $Data->{ims}->{$im}->{conds}->{$token_type}->{actions};
        $changed = 1;
        next;
      }

      if (defined $Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}) {
        if (defined $Data->{ims}->{$Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}}->{conds}->{$token_type}->{using_the_rules_for}) {
          $Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}
              = $Data->{ims}->{$Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}}->{conds}->{$token_type}->{using_the_rules_for};
          $changed = 1;
        }
        next;
      }

      $Data->{ims}->{$im}->{conds}->{$token_type}->{actions} = for_actions {
        my $acts = shift;
        my $new_acts = [];
        for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              not $act->{foster_parenting} and
              not ref $act->{im}) {
            push @$new_acts,
                @{$Data->{ims}->{$act->{im}}->{conds}->{$token_type}->{actions}};
            $changed = 1;
          } else {
            push @$new_acts, $act;
          }
        }
        return $new_acts;
      } $Data->{ims}->{$im}->{conds}->{$token_type}->{actions};
    }
    redo if $changed;
  } # $changed

  #for my $im (keys %{$Data->{ims}}) {
  #  if (defined $Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}) {
  #    $Data->{ims}->{$Data->{ims}->{$im}->{conds}->{$token_type}->{using_the_rules_for}}->{conds}->{$token_type}->{also_used_by}->{$im} = 1;
  #  }
  #}
} # $token_type

for my $im (keys %{$Data->{ims}}) {
  my @cond = keys %{$Data->{ims}->{$im}->{conds}};
  my %start_found;
  my %end_found;
  for (@cond) {
    if (/^START:(.+)$/) {
      $start_found{$_} = 1 for split /,/, $1;
    } elsif (/^END:(.+)$/) {
      $end_found{$_} = 1 for split /,/, $1;
    }
  }

  for my $cond (@cond) {
    if ($cond =~ /^START:\S+$/) {
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        my $new_acts = [];
        ACT: for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              $act->{foster_parenting}) {
            for (keys %{$Data->{ims}->{$act->{im}}->{conds}}) {
              next unless /^START:(.+)$/;
              next unless {map { ("START:$_" => 1) } split /,/, $1}->{$cond};
              push @$new_acts, @{foster_parenting_actions $Data->{ims}->{$act->{im}}->{conds}->{$_}->{actions}};
              next ACT;
            }
            push @$new_acts, @{foster_parenting_actions $Data->{ims}->{$act->{im}}->{conds}->{'START-ELSE'}->{actions}};
          } else {
            push @$new_acts, $act;
          }
        }
        return $new_acts;
      } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
    } elsif ($cond eq 'START-ELSE') {
      my %cond;
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              $act->{foster_parenting}) {
            for (keys %{$Data->{ims}->{$act->{im}}->{conds}}) {
              if (/^START:(.+)$/) {
                $cond{'START:' . join ',', grep { not $start_found{$_} } split /,/, $1} = $_;
              }
            }
            delete $cond{'START:'};
            $cond{'START-ELSE'} = 'START-ELSE';
          }
        }
        return $acts;
      } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      my $actions = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      for my $c (keys %cond) {
        $Data->{ims}->{$im}->{conds}->{$c}->{actions} = for_actions {
          my $acts = shift;
          my $new_acts = [];
          for my $act (@$acts) {
            if ($act->{type} eq 'USING-THE-RULES-FOR' and
                $act->{foster_parenting}) {
              push @$new_acts, @{foster_parenting_actions $Data->{ims}->{$act->{im}}->{conds}->{$cond{$c}}->{actions}};
            } else {
              push @$new_acts, $act;
            }
          }
          return $new_acts;
        } $actions;
      }
    } elsif ($cond eq 'END-ELSE') {
      my %cond;
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              $act->{foster_parenting}) {
            for (keys %{$Data->{ims}->{$act->{im}}->{conds}}) {
              if (/^END:(.+)$/) {
                $cond{'END:' . join ',', grep { not $end_found{$_} } split /,/, $1} = $_;
              }
            }
            delete $cond{'END:'};
            #$cond{'END-ELSE'} = 'END-ELSE';
          }
        }
        return $acts;
      } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      my $actions = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      for my $c (keys %cond) {
        my $changed = 0;
        $Data->{ims}->{$im}->{conds}->{$c}->{actions} = for_actions {
          my $acts = shift;
          my $new_acts = [];
          for my $act (@$acts) {
            if ($act->{type} eq 'USING-THE-RULES-FOR' and
                $act->{foster_parenting}) {
              my $copied = foster_parenting_actions $Data->{ims}->{$act->{im}}->{conds}->{$cond{$c}}->{actions};
              if ((perl2json_chars $copied) =~ /foster_parenting/) {
                $changed = 1;
              }
              push @$new_acts, @$copied;
            } else {
              push @$new_acts, $act;
            }
          }
          return $new_acts;
        } $actions;
        delete $Data->{ims}->{$im}->{conds}->{$c} unless $changed;
      }
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        my $new_acts = [];
        for my $act (@$acts) {
          if ($act->{type} eq 'USING-THE-RULES-FOR' and
              $act->{foster_parenting}) {
            push @$new_acts, {type => 'USING-THE-RULES-FOR', im => $act->{im}};
          } else {
            push @$new_acts, $act;
          }
        }
        return $new_acts;
      } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
    }
  } # $cond

  @cond = keys %{$Data->{ims}->{$im}->{conds}};
  for my $cond (@cond) {
    if ($cond =~ /^(START|END)/) {
      my $cond_token_type = $1;
      unless (@{$Data->{ims}->{$im}->{conds}->{$cond}->{actions}} == 1 and
              $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{type} eq 'USING-THE-RULES-FOR' and
              not $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{foster_parenting}) {
        my %cond;
        $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
          my $acts = shift;
          my $new_acts = [];
          for my $act (@$acts) {
            if ($act->{type} eq 'USING-THE-RULES-FOR') {
              if (ref $act->{im}) {
                if ($act->{im}->[0] eq 'current') {
                  push @$new_acts, {type => 'process-using-current-im'};
                } else {
                  die "Unknown IM |$act->{im}->[0]|";
                }
              } else {
                if ($act->{im} eq 'in body') {
                  push @$new_acts, {type => 'process-using-in-body-im'};
                } else {
                  die unless $cond =~ /^\Q$cond_token_type\E:(.+)$/;
                  my @group = split /,/, $1;
                  my $group_to_cond = {};
                  for my $c (keys %{$Data->{ims}->{$act->{im}}->{conds}}) {
                    if ($c =~ /^\Q$cond_token_type\E:(.+)$/) {
                      $group_to_cond->{$_} = $c for split /,/, $1;
                    }
                  }
                  my $cond_rev = {};
                  push @{$cond_rev->{$group_to_cond->{$_}} ||= []}, $_
                      for @group;
                  for (keys %$cond_rev) {
                    $cond_rev->{$_} = $cond_token_type . ':' . join ',', @{$cond_rev->{$_}};
                  }
                  %cond = reverse %$cond_rev;
                  push @$new_acts, $act;
                }
              }
            } else {
              push @$new_acts, $act;
            }
          }
          return $new_acts;
        } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
        my $actions = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
        for my $c (keys %cond) {
          my $changed = 0;
          $Data->{ims}->{$im}->{conds}->{$c}->{actions} = for_actions {
            my $acts = shift;
            my $new_acts = [];
            for my $act (@$acts) {
              if ($act->{type} eq 'USING-THE-RULES-FOR') {
                my $copied = $Data->{ims}->{$act->{im}}->{conds}->{$cond{$c}}->{actions}
                    or die "No actions for |$act->{im}| |$cond{$c}| (-> |$c|)";
                if ($act->{foster_parenting}) {
                  $copied = foster_parenting_actions $copied;
                }
                $changed = 1;
                push @$new_acts, @$copied;
              } else {
                push @$new_acts, $act;
              }
            }
            return $new_acts;
          } $actions;
          delete $Data->{ims}->{$im}->{conds}->{$c} unless $changed;
        } # $c
        delete $Data->{ims}->{$im}->{conds}->{$cond} if keys %cond;
      }
    }
  } # $cond
} # $im


for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
    $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
      my $acts = [@{+shift}];
      my $new_acts = [];
      while (@$acts) {
        my $act = shift @$acts;
        if ($act->{type} eq 'reprocess pending table character tokens list' and
            $act->{FIELD} eq 'anything else') {
          ## HARDCODED EXPANSION!!
          ## "in table text", anything else -> "in table", anything else ->
          push @$new_acts, @{foster_parenting_actions $Data->{ims}->{'in body'}->{conds}->{TEXT}->{actions}};
          $new_acts->[-1]->{pending_table_character_tokens} = 1;
        } elsif ($act->{type} eq 'set-appropriate-place' and
                 $act->{target} eq 'adjusted insertion location' and
                 @$acts and
                 $acts->[0]->{type} eq 'create an HTML element' and
                 $acts->[0]->{intended_parent} eq 'adjusted insertion location parent') {
          shift @$acts;
          while (@$acts) {
            if ($acts->[0]->{type} eq 'set-node-flag' or
                $acts->[0]->{type} eq 'unset-node-flag' or
                ($acts->[0]->{type} eq 'if' and
                 @{$acts->[0]->{actions}} == 1 and
                 $acts->[0]->{actions}->[0]->{type} eq 'set-node-flag')) {
              shift @$acts;
            } else {
              last;
            }
          }
          unless (@$acts and $acts->[0]->{type} eq 'append-to-adjusted-insertion-location') {
            die "Unsupported create sequence: |$acts->[0]->{type}|";
          }
          shift @$acts;
          unless (@$acts and $acts->[0]->{type} eq 'push-oe') {
            die "Unsupported create sequence: |$acts->[0]->{type}|";
          }
          shift @$acts;
          push @$new_acts, {type => 'insert an HTML element',
                            with_script_flags => 1};
        } else {
          push @$new_acts, $act;
        }
      } # $acts
      return $new_acts;
    } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
  }
}

for my $im (keys %{$Data->{ims}}) {
  my @cond = keys %{$Data->{ims}->{$im}->{conds}};
  my $get_whether_acked; $get_whether_acked = sub {
    my $acts = shift;
    my $acked = 0;
    for my $act (@$acts) {
      if ($act->{type} eq "acknowledge the token's self-closing flag") {
        $acked ||= 1;
      } elsif ($act->{type} eq 'reprocess the token') {
        $acked ||= 1;
      } elsif ($act->{type} eq 'abort these steps') {
        $acked = -2;
        last;
      } elsif ($act->{type} eq 'break-for-each') {
        $acked = -2;
        last;
      }
      my %result;
      $result{$acked}++;
      for (@ActionKey) {
        if (defined $act->{$_}) {
          $result{$get_whether_acked->($act->{$_}) || $acked}++;
        }
      }
      if (1 < keys %result) {
        $acked = -1;
        #last;
      }
    }
    return $acked;
  }; # $get_whether_acked
  my $insert_acked = sub {
    my $acts = [@{+shift}];
    my $acts2 = [];
    while (@$acts and {
      'reprocess the token' => 1,
      'switch the insertion mode' => 1,
      'switch the tokenizer' => 1,
      'set-current-im' => 1,
      'push-template-ims' => 1,
      'ignore the token' => 1,
      'set-false' => 1, # frameset-ok
    }->{$acts->[-1]->{type}}) {
      unshift @$acts2, pop @$acts;
    }
    return [
      @$acts,
      {type => 'if', cond => ['token', 'has', 'self-closing flag'],
       actions => [{type => 'parse error',
                    name => '-start-tag-self-closing-flag'}]},
      @$acts2,
    ];
  }; # $insert_acked
  for my $cond (@cond) {
    next if @{$Data->{ims}->{$im}->{conds}->{$cond}->{actions} or []} == 1 and
            $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{type} eq 'USING-THE-RULES-FOR';
    next unless $cond =~ /^(START)/;

    my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
    my $acked = $get_whether_acked->($acts);
    if ($acked == 1) {
      #
    } elsif ($acked == 0) {
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = $insert_acked->($acts);
    } elsif ($acked == -1) {
      my $changed = 0;
      my $nested; $nested = sub {
        my $acts = shift;
        my $acked = 0;
        for my $act (@$acts) {
          if ($act->{type} eq "acknowledge the token's self-closing flag" or
              $act->{type} eq 'reprocess the token') {
            $acked = 1;
          } elsif ($act->{type} eq 'abort these steps') {
            die "|$cond| |$im| has |abort these steps|";
          } elsif ($act->{type} eq 'if') {
            my $true_acked = $get_whether_acked->($act->{actions} || []);
            my $false_acked = $get_whether_acked->($act->{false_actions} || []);
            if ($true_acked == 0 and $false_acked == 0) {
              #
            } elsif ($true_acked == 1 and $false_acked == 1) {
              $acked = 1;
            } elsif ($true_acked == 1 and $false_acked == 0) {
              $act->{false_actions} = $insert_acked->($act->{false_actions} || [])
                  unless $act->{cond}->[0] eq 'token' and
                         $act->{cond}->[1] eq 'has' and
                         $act->{cond}->[2] eq 'self-closing flag';
              $changed++;
              $acked = 1;
            } elsif ($true_acked == 0 and $false_acked == 1) {
              $act->{actions} = $insert_acked->($act->{actions} || []);
              $changed++;
              $acked = 1;
            } elsif ($true_acked == -1 and $false_acked == 0) {
              my $ak;
              ($act->{actions}, $ak) = $nested->($act->{actions} || []);
              $act->{false_actions} = $insert_acked->($act->{false_actions} || [])
                  unless $act->{cond}->[0] eq 'token' and
                         $act->{cond}->[1] eq 'has' and
                         $act->{cond}->[2] eq 'self-closing flag';
              $acked = 1 if $ak;
            } elsif ($true_acked == -1 and $false_acked == 1) {
              my $ak;
              ($act->{actions}, $ak) = $nested->($act->{actions} || []);
              $acked = 1 if $ak;
            } elsif ($true_acked == 0 and $false_acked == -1) {
              my $ak;
              $act->{actions} = $insert_acked->($act->{actions} || []);
              ($act->{false_actions}, $ak) = $nested->($act->{false_actions} || []);
              $acked = 1 if $ak;
            } elsif ($true_acked == -1 and $false_acked == -1) {
              my $ak;
              my $ak2;
              ($act->{actions}, $ak) = $nested->($act->{actions} || []);
              ($act->{false_actions}, $ak2) = $nested->($act->{false_actions} || []);
              $acked = 1 if $ak and $ak2;
            } else {
              die "true = $true_acked, false = $false_acked";
            }
          } elsif ($act->{type} =~ /for-each/) {
            my $serialized = perl2json_chars $act;
            if ($serialized =~ /"acknowledge the token's self-closing flag"/ or
                $serialized =~ /"reprocess the token"/ or
                $serialized =~ /"abort these steps"/) {
              die "|$im| |$cond| has complex for-each";
            }
          } else {
            my %result;
            for (@ActionKey) {
              if (defined $act->{$_}) {
                $result{$get_whether_acked->($act->{$_})}++;
              }
            }
            if (1 < keys %result) {
              die "Unsupported ackedness for |$im| |$cond| |$act->{type}|";
            }
          }
        } # $act
        return ($acts, $acked);
      }; # $nested
      my $acked;
      ($acts, $acked) = $nested->($acts);
      unless ($acked) {
        $acts = $insert_acked->($acts);
      }
      if (not $changed == 1 and not $changed == 0) {
        die "Unsupported ackedness for |$im| |$cond| ($changed)";
      }
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = $acts;
    } else {
      die "$im/$cond - action's ack value is $acked";
    }
  }
} # $im

## Merge error type data
{
  my $json = json_bytes2perl path (__FILE__)->parent->parent->child
      ('intermediate/errors/parser-errors.json')->slurp;
  for my $im (keys %{$Data->{ims}}) {
    for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
      $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if ($act->{type} eq 'parse error') {
            unless (defined $act->{name}) {
              die "No parse error name in |$im| |$cond|";
            }

            my $type = $json->{parser_error_name_to_error_type}->{$act->{name}};
            if (defined $type) {
              $act->{error_type} = $type;
              my $def = $json->{errors}->{$type};
              $act->{error_text} = $def->{text} if defined $def->{text};
              $act->{error_value} = $def->{value} if defined $def->{value};
            } else {
              push @{$Data->{_errors} ||= []},
                  sprintf 'Error type for parse error "%s" not defined',
                      $act->{name};
            }
          }
        }
        return $acts;
      } $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
    }
  }
}

{
  my @same_tag_name;
  my $read_pattern; $read_pattern = sub {
    my ($cond, $pattern) = @_;
    if (ref $pattern eq 'ARRAY' and $pattern->[0] eq 'or') {
      my @pp;
      for my $p (@$pattern[1..$#$pattern]) {
        my $pp = $read_pattern->($cond, $p);
        return undef if not defined $pp;
        push @pp, @$pp;
      }
      return [sort {
        $a->[0] cmp $b->[0] ||
        (defined $a->[1] ? 1 : -0.1) <=> (defined $b->[1] ? 1 : -0.2) ||
        $a->[1] cmp $b->[1] ||
        (defined $a->[2] ? 1 : -0.1) <=> (defined $b->[2] ? 1 : -0.2) ||
        $a->[2] cmp $b->[2] ||
        (defined $a->[3] ? 1 : -0.1) <=> (defined $b->[3] ? 1 : -0.2) ||
        $a->[3] cmp $b->[3]
      } @pp];
    } else {
      if (1 == keys %$pattern and defined $pattern->{ns}) {
        return [[$pattern->{ns}, undef]];
      } elsif (2 == keys %$pattern and defined $pattern->{ns} and
               defined $pattern->{name}) {
        if (ref $pattern->{name}) {
          return [map { [$pattern->{ns}, $_] } sort { $a cmp $b } @{$pattern->{name}}];
        } else {
          return [[$pattern->{ns}, $pattern->{name}]];
        }
      } elsif (3 == keys %$pattern and
               defined $pattern->{ns} and
               defined $pattern->{name} and not ref $pattern->{name} and
               defined $pattern->{attrs} and 1 == @{$pattern->{attrs}} and
               2 == keys %{$pattern->{attrs}->[0]} and
               defined $pattern->{attrs}->[0]->{name} and
               defined $pattern->{attrs}->[0]->{lc_value}) {
        return [[$pattern->{ns}, $pattern->{name},
                 $pattern->{attrs}->[0]->{name},
                 $pattern->{attrs}->[0]->{lc_value}]];
      } elsif (1 == keys %$pattern and
               defined $pattern->{category} and
               $pattern->{category} eq 'special') {
        return $read_pattern->($cond, $Data->{tree_patterns}->{'special category'});
      } elsif (2 == keys %$pattern and
               defined $pattern->{category} and
               $pattern->{category} eq 'special' and
               defined $pattern->{except}) {
        my $except = {map { $_ => 1 } @{$pattern->{except}}};
        return [grep {
          not ($_->[0] eq 'HTML' and defined $_->[1] and $except->{$_->[1]});
        } @{$read_pattern->($cond, $Data->{tree_patterns}->{'special category'})}];
      } elsif (1 == keys %$pattern and $pattern->{'HTML integration point'}) {
        return $read_pattern->($cond, $Data->{tree_patterns}->{'HTML integration point'});
      } elsif (1 == keys %$pattern and $pattern->{'MathML text integration point'}) {
        return $read_pattern->($cond, $Data->{tree_patterns}->{'MathML text integration point'});
      } elsif (2 == keys %$pattern and
               defined $pattern->{ns} and $pattern->{ns} eq 'HTML' and
               $pattern->{same_tag_name_as_token} and
               defined $cond and $cond =~ /^END:(.+)$/) {
        push @same_tag_name, map { "HTML:$_" } split /[ ,]/, $1;
        $pattern->{_same_tag_name} = 1;
        return undef;
      } else {
        use Data::Dumper;
        warn Dumper $pattern;
        return undef;
      }
    }
  }; # $read_pattern

  my $serialize_pattern = sub {
    my $pp = shift;
    my @r;
    for my $p (@$pp) {
      if (@$p == 4) {
        push @r, $p->[0] . ':' . ($p->[1] // '*') . '@' . $p->[2] . '=' . $p->[3];
      } else {
        push @r, $p->[0] . ':' . ($p->[1] // '*');
      }
    }
    return join ' ', @r;
  }; # $serialize_pattern

  my @orig_pattern;
  for (values %{$Data->{tree_patterns}}) {
    my $pattern_structure = $read_pattern->(undef, $_);
    if (defined $pattern_structure) {
      my $serialized = $serialize_pattern->($pattern_structure);
      $Data->{patterns}->{$serialized} = $pattern_structure;
      push @orig_pattern, [$pattern_structure => \$_];
    }
  }
  for (values %{$Data->{tree_patterns_not}}) {
    my $pattern_structure = $read_pattern->(undef, $_);
    if (defined $pattern_structure) {
      my $serialized = $serialize_pattern->($pattern_structure);
      $Data->{patterns}->{$serialized} = $pattern_structure;
      push @orig_pattern, [$pattern_structure => \$_];
    }
  }

  ## For "reset the insertion mode appropriately"
  for (qw(select template table html head)) {
    my $v = {ns => 'HTML', name => $_};
    my $pattern_structure = $read_pattern->(undef, $v);
    my $serialized = $serialize_pattern->($pattern_structure);
    $Data->{patterns}->{$serialized} = $pattern_structure;
    push @orig_pattern, [$pattern_structure => \$v];
  }
  for my $key (keys %{$Data->{reset_im_by_html_element}}) {
    my $im_to_els = {};
    for my $el (keys %{$Data->{reset_im_by_html_element}->{$key}}) {
      push @{$im_to_els->{$Data->{reset_im_by_html_element}->{$key}->{$el}} ||= []}, $el;
    }
    for (values %$im_to_els) {
      my $v = {ns => 'HTML', name => $_};
      my $pattern_structure = $read_pattern->(undef, $v);
      my $serialized = $serialize_pattern->($pattern_structure);
      $Data->{patterns}->{$serialized} = $pattern_structure;
      push @orig_pattern, [$pattern_structure => \$v];
    }
  }

  my @cond;
  push @cond, [$Data->{dispatcher_html}, undef] if defined $Data->{dispatcher_html};
  for my $im (keys %{$Data->{ims}}) {
    for my $token_type (keys %{$Data->{ims}->{$im}->{conds}}) {
      $Data->{ims}->{$im}->{conds}->{$token_type}->{actions} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          push @cond, [$act->{cond}, $token_type] if defined $act->{cond};
          for my $key (qw(while while_not until)) {
            if (defined $act->{$key} and ref $act->{$key}) {
              my $pattern_structure = $read_pattern->($token_type, $act->{$key});
              if (defined $pattern_structure) {
                my $serialized = $serialize_pattern->($pattern_structure);
                $Data->{patterns}->{$serialized} = $pattern_structure;
                push @orig_pattern, [$pattern_structure => \($act->{$key})];
              } elsif (ref $act->{$key} eq 'HASH' and
                       $act->{$key}->{_same_tag_name}) {
                $act->{$key} = 'HTML-same-tag-name';
              }
            }
          }
        }
        return $acts;
      } $Data->{ims}->{$im}->{conds}->{$token_type}->{actions}
          if defined $Data->{ims}->{$im}->{conds}->{$token_type}->{actions};
    }
  }
  while (@cond) {
    my ($cond, $token_type) = @{shift @cond};
    if (@$cond >= 4 and
        ($cond->[1] eq 'in scope' or
         $cond->[1] eq 'not in scope' or
         $cond->[1] eq 'in scope not')) {
      if (ref $cond->[3]) {
        my $pattern_structure = $read_pattern->($token_type, $cond->[3]);
        if (defined $pattern_structure) {
          my $serialized = $serialize_pattern->($pattern_structure);
          $Data->{patterns}->{$serialized} = $pattern_structure;
          push @orig_pattern, [$pattern_structure => \($cond->[3])];
        } elsif (ref $cond->[3] eq 'HASH' and
                 $cond->[3]->{_same_tag_name}) {
          $cond->[3] = 'HTML-same-tag-name';
        }
      }
    } elsif (@$cond >= 3 and
             ($cond->[1] eq 'is' or $cond->[1] eq 'is not') and
             ref $cond->[2] eq 'HASH') {
      my $pattern_structure = $read_pattern->($token_type, $cond->[2]);
      if (defined $pattern_structure) {
        my $serialized = $serialize_pattern->($pattern_structure);
        $Data->{patterns}->{$serialized} = $pattern_structure;
        push @orig_pattern, [$pattern_structure => \($cond->[2])];
      } elsif (ref $cond->[2] eq 'HASH' and
               $cond->[2]->{_same_tag_name}) {
        $cond->[2] = 'HTML-same-tag-name';
      }
    } elsif ($cond->[0] eq 'and' and
             @$cond == 3 and
             $cond->[1]->[0] eq 'token' and
             $cond->[1]->[1] eq 'is a' and
             $cond->[1]->[2] eq 'START' and
             $cond->[2]->[0] eq 'token tag_name' and
             ($cond->[2]->[1] eq 'is' or $cond->[2]->[1] eq 'is not')) {
      my %group;
      if (ref $cond->[2]->[2]) {
        for (@{$cond->[2]->[2]}) {
          my $group = $tag_name_to_group->{$_}
              or die "|$_| is not in any tag name group";
          $group{$group} = 1;
        }
      } else {
        my $group = $tag_name_to_group->{$cond->[2]->[2]}
            or die "|$cond->[2]| is not in any tag name group";
        $group{$group} = 1;
      }
      $cond->[0] = 'token';
      $cond->[1] = 'is a';
      $cond->[2] = ($cond->[2]->[1] =~ /not/ ? 'START-NOT:' : 'START:') . join ' ', sort { $a cmp $b } keys %group;
    } elsif ($cond->[0] eq 'or' or $cond->[0] eq 'and') {
      unshift @cond, map { [$_, $token_type] } @$cond[1..$#$cond];
    } elsif ($cond->[0] eq 'token' and
             $cond->[1] eq 'is a' and
             $cond->[2] eq 'CHAR') {
      $cond->[2] = 'TEXT';
    }
  } # @cond

  my $key_to_group_name = {};
  {
    my @pattern = sort { scalar keys %{$a->[1]} <=> scalar keys %{$b->[1]} || $a->[0] cmp $b->[0] } map { [$_ => {map { $_ => 1 } split / /, $_}] } keys %{$Data->{patterns}};
    my $i = 0;
    my $el_to_pattern = {};
    for my $pattern (@pattern) {
      $i++;
      if (1 == keys %{$pattern->[1]}) {
        #
      } else {
        push @{$el_to_pattern->{$_} ||= []}, $i for keys %{$pattern->[1]};
      }
    }
    $el_to_pattern->{$_} = join ' ', @{$el_to_pattern->{$_}}
        for keys %$el_to_pattern;
    my $pattern_to_el = {};
    push @{$pattern_to_el->{$el_to_pattern->{$_}} ||= []}, $_
        for sort { $a cmp $b } keys %$el_to_pattern;
    my $element_groups = {map {
      (join ',', @$_) => $_;
    } values %$pattern_to_el};
    $Data->{element_matching}->{element_groups} = [sort { $a cmp $b } keys %$element_groups];

    for my $group_name (keys %$element_groups) {
      for (@{$element_groups->{$group_name}}) {
        $key_to_group_name->{$_} = $group_name;
      }
    }
  }

  for my $op (@orig_pattern) {
    my $groups = {};
    if (@{$op->[0]} == 1) {
      my $serialized = $serialize_pattern->($op->[0]);
      push @same_tag_name, $serialized;
      ${$op->[1]} = $serialized;
    } else {
      for (split / /, $serialize_pattern->($op->[0])) {
        my $group_name = $key_to_group_name->{$_}
            or die "|$_| does not belong to any group";
        $groups->{$group_name} = 1;
      }
      #${$op->[1]} = {definition => ${$op->[1]}, groups => $groups};
      ${$op->[1]} = join ' ', sort { $a cmp $b } keys %$groups;
    }
  }

  {
    my %found;
    my @tn = grep { not $found{$_}++ } @same_tag_name;
    $Data->{element_matching}->{element_types} = [sort { $a cmp $b } grep { not /:\*$/ } @tn];
    push @{$Data->{element_matching}->{element_groups}}, grep { /:\*$/ } @tn;
  }

  my $has_attr_specific = {};
  for (@{$Data->{element_matching}->{element_groups}},
       @{$Data->{element_matching}->{element_types}}) {
    for (split /[ ,]/, $_) {
      if (/^([^:\@]+:[^:\@]+)\@/) {
        $has_attr_specific->{$1} = 1;
      }
    }
  }
  for (@{$Data->{element_matching}->{element_types}}) {
    if ($has_attr_specific->{$_}) {
      $has_attr_specific->{$_} = 2;
    }
  }
  $Data->{element_matching}->{element_types} = [grep {
    not 2 == ($has_attr_specific->{$_} || 0);
  } @{$Data->{element_matching}->{element_types}}];
  push @{$Data->{element_matching}->{element_groups}}, grep {
    2 == ($has_attr_specific->{$_} || 0);
  } keys %$has_attr_specific;

  my %fnd;
  @{$Data->{element_matching}->{element_types}} = sort {
    $a cmp $b;
  } grep { not $fnd{$_}++ } @{$Data->{element_matching}->{element_types}};
  %fnd = ();
  @{$Data->{element_matching}->{element_groups}} = sort {
    $a cmp $b;
  } grep { not $fnd{$_}++ } @{$Data->{element_matching}->{element_groups}};
}

for my $im (keys %{$Data->{ims}}) {
  my @cond = keys %{$Data->{ims}->{$im}->{conds}};
  for my $cond (@cond) {
    if ($Data->{ims}->{$im}->{conds}->{$cond}->{using_the_rules_for}) {
      $Data->{ims}->{$im}->{conds}->{$cond} = (delete $Data->{ims}->{$im}->{conds}->{$cond}->{using_the_rules_for}) . ';' . $cond;
    } else {
      my $key = $im . ';' . $cond;
      if (@{$Data->{ims}->{$im}->{conds}->{$cond}->{actions}} == 1 and
          $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{type} eq 'USING-THE-RULES-FOR' and
          not $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{foster_parenting} and
          not ref $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{im}) {
        $key = '@@' . $Data->{ims}->{$im}->{conds}->{$cond}->{actions}->[0]->{im};
      } else {
        $Data->{actions}->{$key} = delete $Data->{ims}->{$im}->{conds}->{$cond}->{actions};
      }
      if ($cond =~ /^(START|END):(.+)$/) {
        my $type = $1;
        delete $Data->{ims}->{$im}->{conds}->{$cond};
        for (split /,/, $2) {
          $Data->{ims}->{$im}->{conds}->{"$type:$_"} = $key;
        }
      } else {
        $Data->{ims}->{$im}->{conds}->{$cond} = $key;
      }
    }
  }
  for (@{$Data->{tag_name_groups}}) {
    $Data->{ims}->{$im}->{conds}->{"START:$_"} ||= $Data->{ims}->{$im}->{conds}->{'START-ELSE'}
        if defined $Data->{ims}->{$im}->{conds}->{'START-ELSE'};
    $Data->{ims}->{$im}->{conds}->{"END:$_"} ||= $Data->{ims}->{$im}->{conds}->{'END-ELSE'}
        if defined $Data->{ims}->{$im}->{conds}->{'END-ELSE'};
  }
} # $im
{
  my $changed = 0;
  for my $im (keys %{$Data->{ims}}) {
    for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
      if ($Data->{ims}->{$im}->{conds}->{$cond} =~ /^\@\@(.+)$/) {
        unless ($Data->{ims}->{$im}->{conds}->{$cond} eq $Data->{ims}->{$1}->{conds}->{$cond}) {
          $Data->{ims}->{$im}->{conds}->{$cond} = $Data->{ims}->{$1}->{conds}->{$cond};
          $changed = 1;
        }
      }
    }
  } # $im
  redo if $changed;
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
    my $foreign = 0;
    my @ack;
    if ($cond =~ /^START:(.+)$/) {
      my $tag_names = [split /[ ,]/, $1];
      my $action_name = $Data->{ims}->{$im}->{conds}->{$cond};
      $Data->{actions}->{$action_name} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if ($act->{type} eq 'insert an HTML element' and
              not defined $act->{tag_name}) {
            for (@$tag_names) {
              $act->{possible_tag_names}->{$_} = {};
              $act->{possible_tag_names}->{$_}->{associate_form_owner} = 1
                  if $ELDefs->{categories}->{'form-associated element'}->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_};
            }
          } elsif ($act->{type} eq 'create an HTML element' and
                  not defined $act->{local_name}) {
            for (@$tag_names) {
              $act->{possible_tag_names}->{$_} = {};
              $act->{possible_tag_names}->{$_}->{associate_form_owner} = 1
                  if $ELDefs->{categories}->{'form-associated element'}->{elements}->{'http://www.w3.org/1999/xhtml'}->{$_};
            }
          } elsif ($act->{type} eq 'insert a foreign element') {
            $foreign = 1;
          } elsif ($act->{type} eq 'create an XML element') {
            $foreign = 1;
          } elsif ($act->{type} eq "acknowledge the token's self-closing flag") {
            push @ack, $act;
          }
        }
        return $acts;
      } $Data->{actions}->{$action_name};
    } elsif ($cond =~ /^START-ELSE$/) {
      my $action_name = $Data->{ims}->{$im}->{conds}->{$cond};
      $Data->{actions}->{$action_name} = for_actions {
        my $acts = shift;
        for my $act (@$acts) {
          if ($act->{type} eq 'insert an HTML element' and
              not defined $act->{tag_name}) {
            $act->{possible_tag_names}->{ELSE} = {};
          } elsif ($act->{type} eq 'create an HTML element' and
                  not defined $act->{local_name}) {
            $act->{possible_local_names}->{ELSE} = {};
          } elsif ($act->{type} eq 'insert a foreign element') {
            $foreign = 1;
          } elsif ($act->{type} eq 'create an XML element') {
            $foreign = 1;
          } elsif ($act->{type} eq "acknowledge the token's self-closing flag") {
            push @ack, $act;
          }
        }
        return $acts;
      } $Data->{actions}->{$action_name};
    }
    if ($foreign) {
      $_->{foreign} = 1 for @ack;
    }
  } # $cond
}

{
  my $ims = perl2json_chars $Data->{actions};
  my @step_name = keys %{$Data->{tree_steps}};
  for my $step_name (@step_name) {
    unless ($ims =~ /\Q$step_name\E/) {
      delete $Data->{tree_steps}->{$step_name};
    }
  }
  delete $Data->{tree_steps} if not keys %{$Data->{tree_steps}};
  delete $Data->{patterns};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

