use strict;
use warnings;
no warnings 'utf8';
use warnings FATAL => 'recursion';
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
$doc->inner_html (q{<!DOCTYPE html>});
for (@ARGV) {
  my $d = new Web::DOM::Document;
  my $parser = new Web::HTML::Parser;
  my $spec_path = path (__FILE__)->parent->parent->child ($_);
  $parser->parse_byte_string ('utf-8', $spec_path->slurp => $d);
  $doc->body->append_child ($_) for $d->body->child_nodes->to_list;
}

my $Data = {};

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/\A //;
  $s =~ s/ \z//;
  return $s;
} # _n

my $patterns = [
  ['Drop the attributes from the token, and act as described in the next entry; i.e. act as if this was a "br" start tag token with no attributes, rather than the end tag token that it actually is.' => 'SAME-AS-START-BR'],
  ['Set the form element pointer to null.' => 'set-form-null'],
  ['Run the application cache selection algorithm with no manifest, passing it the Document object.' => 'appcache-selection'],
  ['Stop parsing.' => 'stop-parsing'],
];

my $VERB = '(?:' . (join '|', map { quotemeta $_ } qw(
  abort
  acknowledge
  act
  ignore
  insert
  let
  mark
  move
  pop
  process
  push
  reconstruct
  reprocess
  return
  set
  stop
  switch
  unmark
  unset
)) . ')';
my $SENTENCE = qr/[A-Za-z0-9"'()+ -]+(?:, (?:relative|including|converted) [A-Za-z0-9"'()+ -]+(?:, is [A-Za-z0-9"'()+ -]+|)|)(?:, if any|)/;

sub parse_step ($);
sub parse_step ($) {
  my $tc = shift;
  my @action;

  return () if $tc =~ /^\s*Prompt:\s*If the token has an attribute /;

  if ($tc =~ s/^If the Document is being loaded as part of navigation of a browsing context, then: if the newly created element has a manifest attribute .*?\. The algorithm must be passed the Document object\.\s*//) {
    push @action, {type => 'if', cond => ['navigate'], actions => [
      {type => 'application cache selection algorithm', INPUT => 'manifest'},
    ]};
  }

  if ($tc =~ s/^((?!Otherwise:)[A-Za-z]+):\s*//) {
    push @action, {type => 'LABEL', label => lc $1};
  }

  1 while $tc =~ s/\s*\[\w+\]\s*$//;

  if ($tc =~ s/^([^.]+? for each [^.]+)\.\s+If (it is not, [^.]+)\.\s*//) {
    push @action, {type => 'UNPARSED', DESC => "$1, and if $2"};
  }

  while ($tc =~ s/^((?>[^.()]+|\.e\.|\([^()]+\))+)\.\s*(\([^()]+\)\s*|)//) {
    push @action, {type => 'UNPARSED', DESC => $1};
  }
  push @action, {type => 'UNPARSED', DESC => $tc} if length $tc;

  @action = map {
    if (defined $_->{DESC}) {
      $_->{DESC} =~ s/\s+$//;
      $_->{DESC} = lcfirst $_->{DESC};
      $_->{DESC} =~ s/^(?:now,|finally,|then,|first,|then,|in any case,|immediately|once again|at this stage,) //;
    }
    if (not defined $_->{DESC}) {
      $_;
    } elsif ($_->{DESC} eq 'otherwise:') {
      {type => 'ELSE', RUN_NEXT_ALL => 1};
    } elsif ($_->{DESC} =~ s/^(otherwise, |)if ($SENTENCE), then: //o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      $_->{actions} = [parse_step $_->{DESC}];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ($SENTENCE), (?:then |)($SENTENCE)$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      $_->{actions} = [parse_step $3];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ($SENTENCE), (?:then |)($SENTENCE)(?:;|:|, and then) ($SENTENCE)$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      my $f = $4;
      $_->{actions} = [(parse_step $3), (parse_step $f)];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ($SENTENCE), (?:then |)($SENTENCE)[;:] ($SENTENCE), (?:and(?: then|)|then) ($SENTENCE)$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      my $f = $4;
      my $i = $5;
      $_->{actions} = [(parse_step $3), (parse_step $f), (parse_step $i)];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ($SENTENCE), then(?: run these substeps|)(?: instead|):$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      $_->{RUN_NEXT} = 1;
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE), then ($SENTENCE), and if ($SENTENCE), ($SENTENCE); otherwise, if ($SENTENCE(?:, or $SENTENCE)*), ($SENTENCE)$/o) {
      $_->{type} = 'IF';
      my @a = ($3, $4, $5, $6);
      $_->{actions} = [(parse_step $2), {type => 'IF', COND => $a[0], actions => [parse_step $a[1]]}];
      delete $_->{DESC};
      ($_, {type => 'ELSIF', COND => $a[2], actions => [parse_step $a[3]]});
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ([A-Za-z0-9" -]+? is one of [A-Za-z0-9" -]+(?:, (?:or |)[A-Za-z0-9" -]+)+), then ($SENTENCE); ($SENTENCE)$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      my $f = $4;
      $_->{actions} = [(parse_step $3), (parse_step $f)];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ([A-Za-z0-9" -]+? that is not either (?:an?|the) [\w-]+ element(?:, (?:or |)(?:an?|the) [\w-]+ element)+), then ($SENTENCE)$/o) {
      $_->{type} = $1 ? 'ELSIF' : 'IF';
      $_->{COND} = $2;
      $_->{actions} = [parse_step $3];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE(?:, (?:or |and |)$SENTENCE)+), (?:then |)($SENTENCE)$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      $_->{actions} = [parse_step $2];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE(?:, (?:or |and |)$SENTENCE)+), then ($SENTENCE); ($SENTENCE)$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      $_->{actions} = [parse_step $2];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ([A-Za-z0-9" -]+, but is not an? [A-Za-z0-9" -]+(?:, (?:or |)[A-Za-z0-9" -]+)+ [A-Za-z0-9" -]+), then ($SENTENCE)$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      $_->{actions} = [parse_step $2];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE, or if it does, but $SENTENCE), then: ($SENTENCE)$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      $_->{actions} = [parse_step $2];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE), then ($SENTENCE), and if that is successful, ($SENTENCE); otherwise, if ($SENTENCE(?:, or $SENTENCE)+), ($SENTENCE)$/) {
      my @a = ($2, $3, $4, $5);
      ({type => 'IF', COND => $1, actions => [parse_step $a[0]]},
       {type => 'IF', COND => 'that is successful', actions => [parse_step $a[1]]},
       {type => 'ELSIF', COND => $a[2], actions => [parse_step $a[3]]});
    } elsif ($_->{DESC} =~ /^if ([A-Za-z0-9" -]+(?:, (?:or |)[A-Za-z0-9"-]+)+ [A-Za-z0-9" -]+), ($SENTENCE); ($SENTENCE)$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      my $f = $3;
      $_->{actions} = [(parse_step $2), (parse_step $f)];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^if ($SENTENCE), then run the appropriate steps from the following list:$/o) {
      $_->{type} = 'IF';
      $_->{COND} = $1;
      $_->{RUN_NEXT} = 1;
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^otherwise, ($SENTENCE)$/o) {
      $_->{type} = 'ELSE';
      $_->{actions} = [parse_step $1];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^otherwise, ($SENTENCE); ($SENTENCE)$/o) {
      $_->{type} = 'ELSE';
      my $f = $2;
      $_->{actions} = [(parse_step $1), (parse_step $2)];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^($SENTENCE) until ($SENTENCE(?:, (?:or |)[A-Za-z0-9" -]+)*)$/o) {
      $_->{type} = 'UNTIL';
      $_->{COND} = $2;
      $_->{actions} = [parse_step $1];
      delete $_->{DESC};
      $_;
    } elsif ($_->{DESC} =~ /^($SENTENCE), and then (keep [A-Za-z0-9" -]+) until ($SENTENCE(?:, (?:or |)[A-Za-z0-9" -]+)+)$/o) {
      my $f = $1;
      my $g = $2;
      $_->{type} = 'UNTIL';
      $_->{COND} = $3;
      $_->{actions} = [parse_step $g];
      delete $_->{DESC};
      ((parse_step $f), $_);
   } elsif ($_->{DESC} =~ /^($SENTENCE)(?:,? and|, then|, and then) ($VERB $SENTENCE)$/o) {
      my $f = $2;
      ((parse_step $1), (parse_step $f));
    } elsif ($_->{DESC} =~ /^($SENTENCE), and, if ($SENTENCE), ($SENTENCE)$/o) {
      my @a = ($1, $2, $3);
      ((parse_step $a[0]),
       {type => 'IF', COND => $a[1], actions => [parse_step $a[2]]});
    } elsif ($_->{DESC} =~ /^check to see if ($SENTENCE)(?:, and|\.) if it is not, ($SENTENCE)$/o) {
      {type => 'IF', COND => $1, actions => [parse_step $2]};
    } elsif ($_->{DESC} =~ /^(?:run|follow) (?:these|the following) steps:$/) {
      {type => 'STEP', RUN_NEXT => 1};
    } elsif ($_->{DESC} =~ /^otherwise, (?:run|follow) (?:these|the following) steps:$/) {
      {type => 'ELSE', RUN_NEXT => 1};
    } elsif ($_->{DESC} =~ /^otherwise, ($SENTENCE); then, for each ($SENTENCE), (.+)$/) {
      my $h = $2;
      my $f = $3;
      {type => 'ELSE', actions => [
        (parse_step $1),
        {type => 'FOR-EACH', ITEMS => $h, actions => [parse_step $f]},
      ]};
    } elsif ($_->{DESC} =~ /^otherwise, for each ($SENTENCE), (.+)$/) {
      my $i = $1;
      my $f = $2;
      {type => 'FOR-EACH', ITEMS => $i, actions => [parse_step $f]};
    } elsif ($_->{DESC} =~ /^enable foster parenting, ($SENTENCE), and then disable foster parenting$/o) {
      {type => 'with-foster-parenting', actions => [parse_step $1]};
    } elsif ($_->{DESC} =~ /^($SENTENCE, including node), then ($SENTENCE)$/o) {
      my $f = $2;
      ((parse_step $1), (parse_step $f));
    } else {
      $_;
    }
  } @action;
  
  if (@action == 1) {
    return @action;
  } else {
    return {type => 'STEP', actions => \@action};
  }
} # parse_step

sub parse_pattern ($) {
  my $pattern = shift;
  if ($pattern =~ /^An? ([\w-]+) element in the (\w+) namespace$/) {
    return {ns => $2, name => $1};
  } elsif ($pattern =~ /^([\w-]+) in the (\w+) namespace$/) {
    return {ns => $2, name => $1};
  } elsif ($pattern =~ /^An? ([\w-]+) element in the (\w+) namespace whose start tag token had an attribute with the name "([^"]+)" whose value was an ASCII case-insensitive match for the string "([^"]+)"$/) {
    return {ns => $2, name => $1, attrs => [{name => $3, lc_value => lc $4}]};
  } elsif ($pattern =~ /^All the element types listed above for the (.+?) algorithm\.$/) {
    return ['SAME-AS', $1];
  } else {
    die "Unknown pattern |$pattern|";
  }
} # parse_pattern

my $im_name;
my @node = @{$doc->body->child_nodes};
my $steps_name;
my $steps_type;
while (@node) {
  my $node = shift @node;
  if ($node->node_type == $node->ELEMENT_NODE) {
    my $ln = $node->local_name;
    if ($ln =~ /^h[1-6]$/ or $ln eq 'dt') {
      my $tc = _n $node->text_content;
      if ($tc =~ /^[0-9.]+ The "(.+)" insertion mode$/) {
        $im_name = _n $1;
        $Data->{ims}->{$im_name} ||= {};
      } elsif ($tc =~ /^[0-9.]+ The rules for parsing tokens in foreign content$/) {
        $im_name = 'in foreign content';
        $Data->{ims}->{$im_name} ||= {};
      } else {
        undef $im_name;
      }
      undef $steps_name;
      undef $steps_type;
    } elsif ($ln eq 'p') {
      my $tc = _n $node->text_content;
      if ($tc =~ /^(?:When|Where) the steps (?:above|below) (?:say|require) (?:the (?:user agent is|UA) |)to (.+?), (?:it means|they mean) (?:that |)(?:the (?:user agent|UA) must|to) (?:run|follow) (?:the following|these) (?:steps|algorithm):$/) {
        $steps_name = $1;
      } elsif ($tc =~ /^When the steps above require the UA to (.+?), it means that the UA must, while (.+?) is not (.+?), ([^,]+?)\.$/) {
        $Data->{ims}->{_steps}->{conds}->{$1}->{actions}
            = [{type => 'UNTIL',
                WHILE => 1,
                COND => "$2 is not $3",
                actions => [{type => 'UNPARSED', DESC => $4}]}];
      } elsif ($tc =~ /^When the steps below require the UA to (.+?), then, while (the current node is an? [\w-]+ element(?:, (?:or |)an? [\w-]+ element)+), the UA must (.+?).$/) {
        my $s = $1;
        $Data->{ims}->{_steps}->{conds}->{$1}->{actions}
            = [{type => 'UNTIL',
                WHILE => 1,
                COND => $2,
                actions => [{type => 'UNPARSED', DESC => $3}]}];
      } elsif ($tc =~ /^The (generic raw text element parsing algorithm) and the generic RCDATA element parsing algorithm consist of the following steps. These algorithms are always invoked in response to a start tag token.$/) {
        $steps_name = $1;
      } elsif ($tc =~ /^When the steps below require the user agent to (.+?) for a token, then,.*?the following table/) {
        $steps_name = $1;
      } elsif ($tc =~ /^When the steps below require the user agent to (.+?) for a token, then, if the token has an attribute named ([\w-]+), change its name to ([\w-]+) \([^()]+\).$/) {
        $Data->{tables}->{$1} = {$2 => $3};
      } elsif ($tc =~ /^A node is an? (.+?) if it is one of the following elements:$/) {
        $steps_name = $1;
      } elsif ($tc =~ /^The stack of open elements is said to (.+?) when it has that element in the specific scope consisting of the following element types:$/) {
        $steps_name = $1;
        $steps_name =~ s/^have /has /;
        $steps_name =~ s/a particular element/an element/;
      } elsif ($tc =~ /^The stack of open elements is said to (.+?) when it has that element in the specific scope consisting of all element types except the following:$/) {
        $steps_name = $1;
        $steps_name =~ s/^have /has /;
        $steps_name =~ s/a particular element/an element/;
        $steps_type = 'patterns_not';
      } elsif ($tc =~ /^Elements in the stack of open elements fall into the following categories:$/) {
        $steps_name = 'category';
        $steps_type = 'category';
      } elsif ($tc =~ /known as the (tree construction dispatcher):$/) {
        $steps_name = $1;
        $steps_type = $1;
      } else {
        unshift @node, $node->child_nodes->to_list;
      }
    } elsif ($ln eq 'dl') {
      if (defined $im_name and $node->class_list->contains ('switch')) {
        my $switch_conds = [];
        my $was_dd;
        for my $n (@{$node->children}) {
          my $ln = $n->local_name;
          if ($ln eq 'dt') {
            my $cond = _n $n->text_content;
            if ($cond =~ /^A character token that is U\+([0-9A-F]+) [0-9A-Z-\s]+(?:\([^()]+\)|)$/) {
              $cond = sprintf 'CHAR:%04X', hex $1;
            } elsif ($cond =~ /^A character token that is one of (U\+[0-9A-F]+ [0-9A-Z-\s]+(?:\([^()]+\)|)(?:(?:, |,? or )U\+[0-9A-F]+ [0-9A-Z-\s]+(?:\([^()]+\)|))*)$/) {
              my $s = $1;
              my @s;
              push @s, hex $1 while $s =~ /U\+([0-9A-F]+)/g;
              $cond = 'CHAR:' . join ' ', map { sprintf '%04X', $_ } @s;
              if ($cond eq 'CHAR:0009 000A 000C 000D 0020') {
                $cond = 'CHAR:WS';
              }
            } elsif ($cond =~ /^A character token, if the current node is ([a-z0-9_.-]+(?:(?:, |,? or )[a-z0-9-_]+)*) element$/) {
              $cond = 'CURRENT-CHAR:';
              my $s = $1;
              my @s;
              push @s, $1 while $s =~ /([a-z0-9_.-]+)/g;
              $cond .= join ' ', sort { $a cmp $b } grep { not $_ eq 'or' } @s;
            } elsif ($cond =~ /^An? (start|end) tag (?:token |)whose tag name is "([^"]+)"$/) {
              $cond = (uc $1) . ':' . $2;
            } elsif ($cond =~ /^An? (start|end) tag (?:token |)whose tag name is "([^"]+)", if the token has any attributes named ("[^"]+"(?:(?:, |,? or )"[^"]+")*)$/) {
              $cond = (uc $1) . '-ATTR:' . $2;
              my $s = $3;
              my @s;
              push @s, $1 while $s =~ /"([^"]+)"/g;
              $cond .= ':' . join ' ', sort { $a cmp $b } @s;
            } elsif ($cond =~ /^An? (start|end) tag (?:token |)whose tag name is "([^"]+)", if (the current node is a script element in the SVG namespace|the scripting flag is disabled|the scripting flag is enabled)$/) {
              $cond = {
                'the current node is a script element in the SVG namespace' => 'SVGSCRIPT',
                'the scripting flag is disabled' => 'NOSCRIPT',
                'the scripting flag is enabled' => 'SCRIPT',
              }->{$3} . '-' . (uc $1) . ':' . $2;
            } elsif ($cond =~ /^An? (start|end) tag (?:token |)whose tag name is one of: ("[^"]+"(?:, "[^"]+")*)$/) {
              my $token = $1;
              my $s = $2;
              my @s;
              push @s, $1 while $s =~ /"([^"]+)"/g;
              $cond = (uc $token) . ':' . join ' ', sort { $a cmp $b } @s;
            } elsif ($cond eq 'Any other start tag') {
              $cond = 'START-ELSE';
            } elsif ($cond eq 'Any other end tag') {
              $cond = 'END-ELSE';
            } elsif ($cond eq 'A character token') {
              $cond = 'CHAR-ELSE';
            } elsif ($cond eq 'Any other character token') {
              $cond = 'CHAR-ELSE';
            } elsif ($cond eq 'Anything else') {
              $cond = 'ELSE';
            } elsif ($cond eq 'An end-of-file token') {
              $cond = 'EOF';
            } elsif ($cond =~ /^A (DOCTYPE|comment) token$/) {
              $cond = uc $1;
            } else {
              $cond = 'MISC:' . $cond;
            }
            $Data->{ims}->{$im_name}->{conds}->{$cond} ||= {};
            $switch_conds = [] if $was_dd;
            push @$switch_conds, $cond;
            $was_dd = 0;
          } elsif ($ln eq 'dd') {
            my @action;
            my $action = $n;
            my @n = map { [$_, \@action] } $n->child_nodes->to_list;
            while (@n) {
              my ($action, $action_list) = @{shift @n};
              if ($action->node_type == $action->ELEMENT_NODE) {
                my $ln = $action->local_name;
                if ($ln eq 'p') {
                  next if $action->class_list->contains ('note');
                  next if $action->class_list->contains ('example');
                  my $tc = _n $action->text_content;
                  push @$action_list, parse_step $tc;
                } elsif ($ln eq 'li') {
                  if ($action->query_selector ('p')) {
                    unshift @n, map { [$_, $action_list] } $action->children->to_list;
                  } else {
                    my $tc = _n $action->text_content;
                    push @$action_list, parse_step $tc;
                  }
                } elsif ($ln eq 'ol') {
                  my $acts = [];
                  unshift @n, map { [$_, $acts] } $action->children->to_list;
                  push @$action_list, {type => 'STEP', actions => $acts};
                } elsif ($ln eq 'dl') {
                  my $act_list = [];
                  push @$action_list, {type => 'STEP', actions => $act_list};
                  my $acts = $act_list;
                  my $has_if;
                  for (@{$action->children}) {
                    my $n = $_->local_name;
                    if ($n eq 'dt') {
                      $acts = [];
                      my $cond = $_->text_content;
                      $cond =~ s/^If //;
                      if ($cond eq 'Otherwise') {
                        push @$act_list,
                            {type => 'ELSE',
                             actions => $acts};
                      } else {
                        push @$act_list,
                            {type => $has_if ? 'ELSIF' : 'IF',
                             COND => $_->text_content,
                             actions => $acts};
                      }
                      $has_if = 1;
                    } elsif ($n eq 'dd') {
                      my $ac = [];
                      unshift @n, map { [$_, $ac] } $_->children->to_list;
                      push @$acts, {type => 'STEP', actions => $ac};
                    } else {
                      unshift @n, [$_, $acts];
                      push @$acts, {type => 'STEP', actions => $acts};
                    }
                  }
                } elsif ($ln eq 'table') {
                  push @$action_list,
                      {type => 'TABLE', node => $action};
                } else {
                  push @$action_list,
                      {type => 'misc', desc => $action->inner_html};
                }
              } elsif ($action->node_type == $action->TEXT_NODE) {
                my $tc = _n $action->text_content;
                push @$action_list, parse_step $tc if length $tc;
              }
            } # @n
            push @{$Data->{ims}->{$im_name}->{conds}->{$_}->{actions} ||= []}, @action
                for @$switch_conds;
            $was_dd = 1;
          }
        }
      } elsif (defined $steps_type and $steps_type eq 'category') {
        my $category_name;
        my $list;
        for my $el ($node->children->to_list) {
          my $ln = $el->local_name;
          if ($ln eq 'dt') {
            $category_name = lc $el->query_selector ('dfn')->text_content;
            $list = {};
          } elsif ($ln eq 'dd' and defined $category_name) {
            my $tc = _n $el->text_content;
            $tc =~ s/^[^:]+: //;
            while ($tc =~ s/^(\w+)'s ([\w-]+(?:, (?:and |)[\w-]+)+)(?:; (?:and |)|\.)//) {
              my $name = $1;
              my $els = [split /, (?:and |)/, $2];
              $list->{$name}->{$_} = 1 for @$els;
            }
            if ($tc =~ s/^([\w-]+(?:, (?:and |)[\w-]+)+)//) {
              my $els = [split /, (?:and |)/, $1];
              $list->{HTML}->{$_} = 1 for @$els;
            }
            $Data->{patterns}->{$category_name . ' category'} = [map { {ns => $_, name => [sort { $a cmp $b } keys %{$list->{$_}}]} } sort { $a cmp $b } keys %$list];
            delete $Data->{patterns}->{$category_name . ' category'}
                unless @{$Data->{patterns}->{$category_name . ' category'}};
          }
        }
        undef $steps_name;
        undef $steps_type;
      } elsif (defined $steps_type and $steps_type eq 'tree construction dispatcher') {
        my @cond;
        for my $el ($node->children->to_list) {
          my $ln = $el->local_name;
          if ($ln eq 'dt') {
            my $cond = _n $el->text_content;
            if ($cond =~ /^If (.+? is .+?) and (.+? is .+)$/) {
              push @cond, ['and', $1, $2];
            } elsif ($cond =~ /^If (.+? is .+)$/) {
              push @cond, $1;
            } else {
              die "Unknown cond |$cond|";
            }
          } elsif ($ln eq 'dd') {
            last;
          }
        }
        $Data->{dispatcher_html} = \@cond;
        undef $steps_name;
        undef $steps_type;
      } else { # not .switch
        unshift @node, $node->child_nodes->to_list;
      }
    } elsif (defined $steps_name and
             $steps_name eq 'reset the insertion mode appropriately' and
             $ln eq 'ol') {
      my $map = {};
      for ($node->children->to_list) {
        my $t = _n $_->text_content;
        if ($t =~ /^If node is an? (\w+(?:(?:, or | or |, )\w+)*) element, then switch the insertion mode to "([^"]+)" and abort these steps.(?: \([^()]+\)|)$/) {
          my $mode = $2;
          $map->{always}->{$_} = $mode for split /, or | or |, /, $1;
        } elsif ($t =~ /^If node is an? (\w+(?:(?:, or | or |, )\w+)*) element and last is false, then switch the insertion mode to "([^"]+)" and abort these steps.(?: \([^()]+\)|)$/) {
          my $mode = $2;
          $map->{last_is_false}->{$_} = $mode for split /, or | or |, /, $1;
        }
      }
      $Data->{reset_im_by_html_element} = $map;
    } elsif (defined $steps_name and $ln eq 'ol') {
      my $acts = [];
      my @n = map { [$_, $acts] } $node->children->to_list;
      while (@n) {
        my ($action, $action_list) = @{shift @n};
        my $ln = $action->local_name;
        if ($ln eq 'p') {
          next if $action->class_list->contains ('note');
          next if $action->class_list->contains ('example');
          my $tc = _n $action->text_content;
          push @$action_list, parse_step $tc;
        } elsif ($ln eq 'li') {
          if ($action->query_selector ('p')) {
            unshift @n, map { [$_, $action_list] } $action->children->to_list;
          } else {
            my $tc = _n $action->text_content;
            push @$action_list, parse_step $tc;
          }
        } else {
          my $tc = _n $action->text_content;
          push @$action_list, parse_step $tc;
        }
      }
      $Data->{ims}->{_steps}->{conds}->{$steps_name}->{actions} = $acts;
      if ($steps_name eq 'generic raw text element parsing algorithm') {
        $steps_name =~ s/raw text/RCDATA/;
        $Data->{ims}->{_steps}->{conds}->{$steps_name}->{actions} = [map { {%$_} } @$acts];

        for my $act (@{$Data->{ims}->{_steps}->{conds}->{'generic raw text element parsing algorithm'}->{actions}}) {
          $act->{DESC} =~ s/^if the algorithm that was invoked is the generic raw text element parsing algorithm, (.+?); otherwise the algorithm invoked was the generic RCDATA element parsing algorithm, (.+)$/$1/;
        }
        for my $act (@{$Data->{ims}->{_steps}->{conds}->{'generic RCDATA element parsing algorithm'}->{actions}}) {
          $act->{DESC} =~ s/^if the algorithm that was invoked is the generic raw text element parsing algorithm, (.+?); otherwise the algorithm invoked was the generic RCDATA element parsing algorithm, (.+)$/$2/;
        }
      }
      undef $steps_name;
      undef $steps_type;
    } elsif (defined $steps_name and $ln eq 'table') {
      my @label;
      for (@{$node->query_selector_all ('thead > tr > *')}) {
        push @label, _n $_->text_content;
      }
      my @data;
      for (@{$node->query_selector_all ('tbody tr')}) {
        my @cell = @{$_->cells};
        my $data = {};
        for (0..$#cell) {
          my $code = $cell[$_]->query_selector ('code');
          if (defined $code) {
            $data->{$label[$_]} = $code->text_content;
          } elsif ($label[$_] eq 'Namespace') {
            my $tc = _n $cell[$_]->text_content;
            $tc =~ s/ namespace$//;
            $data->{$label[$_]} = $tc;
          }
        }
        push @data, $data;
      }
      my %label = map { $_ => 1 } @label;
      if ($label{'Attribute name on token'} and
          $label{'Attribute name on element'}) {
        $Data->{tables}->{$steps_name} = {map { $_->{'Attribute name on token'} => $_->{'Attribute name on element'} } @data};
      } elsif ($label{'Attribute name'} and
               $label{Prefix} and
               $label{'Local name'} and
               $label{Namespace}) {
        $Data->{tables}->{$steps_name} = {map { $_->{'Attribute name'} => [$_->{Prefix}, $_->{'Local name'}, $_->{Namespace}] } @data};
      } else {
        die "Unknown table type |$steps_name|";
      }
      undef $steps_name;
      undef $steps_type;
    } elsif (defined $steps_name and $ln eq 'ul') {
      $Data->{$steps_type // 'patterns'}->{$steps_name} = [map { parse_pattern _n $_->text_content } grep { $_->local_name eq 'li' } $node->children->to_list];
      undef $steps_name;
      undef $steps_type;
    } else {
      unshift @node, $node->child_nodes->to_list;
    } # $ln
  } # $node->node_type
}

sub for_actions (&$);
sub for_actions (&$) {
  my ($code, $acts) = @_;
  my $new_acts = [];
  for (@$acts) {
    my $act = {%$_};
    for (qw(actions false_actions between_actions ws_actions null_actions
            char_actions ws_char_actions ws_seq_actions
            null_char_actions null_seq_actions)) {
      $act->{$_} = &for_actions ($code, $act->{$_}) if defined $act->{$_};
    }
    push @$new_acts, $act;
  }
  return $code->($new_acts);
} # for_actions

sub resolve_action_structure ($);
sub resolve_action_structure ($) {
  my $acts = [@{$_[0]}];

  my $new_acts = [];
  my $container = $new_acts;
  while (@$acts) {
    my $act = shift @$acts;
    $act = {%$act};
    push @$container, $act;
    if ($act->{RUN_NEXT_ALL} and not $act->{actions}) {
      $container = $act->{actions} = [];
      delete $act->{RUN_NEXT_ALL};
    }
  }
  $acts = $new_acts;

  $new_acts = [];
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{RUN_NEXT} and
        not defined $act->{actions} and
        @$acts and
        $acts->[0]->{type} eq 'STEP' and
        defined $acts->[0]->{actions} and
        2 == keys %{$acts->[0]}) {
      $act->{actions} = $acts->[0]->{actions};
      delete $act->{RUN_NEXT};
      shift @$acts;
    } elsif ($act->{type} eq 'STEP' and
             @{$act->{actions}} and
             $act->{actions}->[-1]->{RUN_NEXT} and
             not defined $act->{actions}->[-1]->{actions} and
             $acts->[0]->{type} eq 'STEP' and
             defined $acts->[0]->{actions} and
             2 == keys %{$acts->[0]}) {
      $act->{actions}->[-1]->{actions} = $acts->[0]->{actions};
      delete $act->{actions}->[-1]->{RUN_NEXT};
      shift @$acts;
    }
    push @$new_acts, $act;
  }
  $acts = $new_acts;

  $new_acts = [];
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'STEP' and
        ($act->{actions}->[0]->{type} eq 'ELSE' or
         $act->{actions}->[0]->{type} eq 'ELSIF')) {
      my $if = {%{$act->{actions}->[0]}};
      $if->{actions} = [@{$if->{actions}}, @{$act->{actions}}[1..$#{$act->{actions}}]];
      push @$new_acts, $if;
    } else {
      push @$new_acts, $act;
    }
  }
  $acts = $new_acts;

  $new_acts = [];
  while (@$acts) {
    my $act = pop @$acts;
    if ($act->{type} eq 'ELSE' and
        defined $act->{actions} and
        2 == keys %$act) {
      if (@$acts and
          ($acts->[-1]->{type} eq 'IF' or $acts->[-1]->{type} eq 'ELSIF') and
          not defined $acts->[-1]->{false_actions}) {
        $acts->[-1]->{false_actions} = $act->{actions};
        next;
      }
    } elsif ($act->{type} eq 'ELSIF') {
      if (@$acts and
          ($acts->[-1]->{type} eq 'IF' or $acts->[-1]->{type} eq 'ELSIF') and
          not defined $acts->[-1]->{false_actions}) {
        $act->{type} = 'IF';
        $acts->[-1]->{false_actions} = [$act];
        next;
      } elsif (@$acts and
               $acts->[-1]->{type} eq 'STEP' and
               @{$acts->[-1]->{actions}} and
               $acts->[-1]->{actions}->[-1]->{type} eq 'IF' and
               not defined $acts->[-1]->{actions}->[-1]->{false_actions}) {
        $act->{type} = 'IF';
        $acts->[-1]->{actions}->[-1]->{false_actions} = [$act];
        next;
      }
    } elsif ($act->{type} eq 'TABLE') {
      if (@$acts) {
        $acts->[-1]->{TABLE_ELEMENT} = $act->{node};
        next;
      }
    }
    unshift @$new_acts, $act;
  }

  for my $act (@$new_acts) {
    for (qw(actions false_actions between_actions)) {
      $act->{$_} = resolve_action_structure $act->{$_} if defined $act->{$_};
    }
  }
  $acts = $new_acts;

  $new_acts = [];
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'STEP' and 2 == keys %$act) {
      push @$new_acts, @{$act->{actions}};
    } else {
      push @$new_acts, $act;
    }
  }
  $acts = $new_acts;

  return $new_acts;
} # resolve_action_structure

my $DescIsType = {};
$DescIsType->{$_} = 1 for
  'abort these steps',
  "acknowledge the token's self-closing flag",
  'adjust foreign attributes',
  'adjust MathML attributes',
  'adjust SVG attributes',
  'application cache selection algorithm',
  'change the encoding',
  'clear the list of active formatting elements up to the last marker',
  'clear the stack back to a table body context',
  'clear the stack back to a table context',
  'clear the stack back to a table row context',
  'close a p element',
  'close the cell',
  'generate all implied end tags thoroughly',
  'generate implied end tags',
  'generic raw text element parsing algorithm',
  'generic RCDATA element parsing algorithm',
  'insert a character',
  'insert a comment',
  'ignore the token',
  'insert an HTML element',
  'parse error',
  'perform a microtask checkpoint',
  'prepare a script',
  'process the SVG script element',
  'push onto the list of active formatting elements',
  'reconstruct the active formatting elements',
  'reprocess the token',
  'reset the insertion mode appropriately',
  'stop parsing',
  'take a deep breath',
  'add the attribute and its corresponding value to that element',
  ;
my $NormalizeDesc = {};
$NormalizeDesc->{$_->[0]} = $_->[1] for
    ["acknowledge the token's self-closing flag, if it is set" => "acknowledge the token's self-closing flag"],
    ['adjust foreign attributes for the token' => 'adjust foreign attributes'],
    ['adjust MathML attributes for the token' => 'adjust MathML attributes'],
    ['adjust SVG attributes for the token' => 'adjust SVG attributes'],
    ['close the cell (see below)' => 'close the cell'],
    ['insert the character' => 'insert a character'],
    ['insert an HTML element for the token', 'insert an HTML element'],
    ["insert the token's character" => 'insert a character'],
    ['prepare the script' => 'prepare a script'],
    ['push onto the list of active formatting elements that element' => 'push onto the list of active formatting elements'],
    ['reconstruct the active formatting elements, if any' => 'reconstruct the active formatting elements'],
    ['reprocess it' => 'reprocess the token'],
    ['reprocess the current token' => 'reprocess the token'],
    ['run the application cache selection algorithm with no manifest' => 'application cache selection algorithm'],
    ['run the application cache selection algorithm with no manifest, passing it the Document object' => 'application cache selection algorithm'],
    ['stop these steps' => 'abort these steps'],
    ['process the script element according to the SVG rules, if the user agent supports SVG' => 'process the SVG script element'],
    ['change the encoding to the resulting encoding' => 'change the encoding'],

    ['the algorithm must be passed the Document object' => ''],
    ;

my $DescPatterns = [
  [qr/act as described in the "([^"]+)" entry below/,
   'SAME-AS', 'FIELD'],
  [qr/act as described in the steps for an? ("[^"]+" end tag) below/,
   'SAME-AS', 'FIELD'],
  [qr/push (.+) onto (.+)/, 'PUSH', 'ITEM', 'LIST'],
  [qr/remove that element from the list of active formatting elements and the stack of open elements if the adoption agency algorithm didn't already remove it \([^()]+\)/,
   'REMOVE-THAT-FROM-AFE-AND-OE'],
  [qr/remove (.+) from (.+)/, 'REMOVE', 'ITEM', 'LIST'],
  [qr/pop all the nodes (?:from (.+?), |)from (the current node) up to(.+)/,
   'POP', 'LIST', 'FROM-ITEM', 'TO-ITEM'],
  [qr/pop (.+) (?:off|from) (.+?); the new current node will be .+/,
   'POP', 'ITEM', 'LIST'],
  [qr/pop (.+) (?:off|from) (.+)/, 'POP', 'ITEM', 'LIST'],
  [qr/keep popping more (.+) from (.+)/, 'POP', 'ITEM', 'LIST'],
  [qr/put (.+) in (.+)/, 'PUSH', 'ITEM', 'LIST'],
  [qr/set (.+?) (?:back |)to (?:point to |)(.+)/, 'SET', 'TARGET', 'VALUE'],
  [qr/let (.+?) (?:be|have) (.+)/, 'SET', 'TARGET', 'VALUE'],
  [qr/initialise (.+) to be (.+)/, 'SET', 'TARGET', 'VALUE'],
  [qr/mark (.+) as (?:being |)(.+)/, 'MARK', 'TARGET', 'VALUE'],
  [qr/unset (.+)/, 'UNSET', 'TARGET'],
  [qr/increment (.+) by one/, 'INCREMENT', 'TARGET'],
  [qr/decrement (.+) by one/, 'DECREMENT', 'TARGET'],
  [qr/process the token using the rules for the "([^"]+)" insertion mode/,
   'USING-THE-RULES-FOR', 'im'],
  [qr/process the token according to the rules given in the section corresponding to the (current insertion mode) in HTML content/,
   'USING-THE-RULES-FOR', 'IM'],
  [qr/append (.+?) to (.+)/, 'APPEND', 'ITEM', 'LIST'],
  [qr/insert (.+?) at the end of (.+)/, 'APPEND', 'ITEM', 'LIST'],
  [qr/insert a comment as (.+)/, 'insert a comment', 'AS'],
  [qr/insert a (.+) character/, 'insert a character', 'CHAR'],
  [qr/insert the characters given by (.+)/, 'insert a character', 'CHAR'],
  [qr/insert (?:more |)characters \((see below for what they should say)\)/,
   'insert a character', 'CHAR'],
  [qr/switch the insertion mode to (.+)/,
   'switch the insertion mode', 'IM'],
  [qr/switch the tokenizer to the (.+ state)/,
   'switch the tokenizer', 'state'],
  [qr/insert an HTML element for an? "([^"]+)" start tag token with (.+)/,
   'insert an HTML element', 'tag_name', 'ATTRS'],
  [qr/insert a foreign element for the token, in (.+)/,
   'insert a foreign element', 'NS'],
  [qr/insert the newly created element at (.+)/, 'APPEND', 'LOCATION'],
  [qr/create an? ([\w-]+) element whose ownerDocument is the Document object()/,
   'create an HTML element', 'local_name', 'ATTRS'],
  [qr/create an element for the token in the HTML namespace, with (.+) as the intended parent/,
   'create an HTML element', 'INTENDED_PARENT'],
  [qr/create an element for the token in the HTML namespace, with the intended parent being (.+)/,
   'create an HTML element', 'INTENDED_PARENT'],
  [qr/generate implied end tags, except for (HTML elements with the same tag name as the token)/,
   'generate implied end tags', 'EXCEPT'],
  [qr/generate implied end tags, except for ([\w-]+ elements)/,
   'generate implied end tags', 'EXCEPT'],
  [qr/change the token's tag name to "([^"]+)"/,
   "change the token's tag name", 'tag_name'],
  [qr/jump to the step labeled (\w+) below/, 'SKIP-TO', 'label'],
  [qr/return to the step labeled (\w+)/, 'JUMP-BACK', 'label'],
  [qr/move on to the next one/, 'NEXT-TOKEN'],
  [qr/run the adoption agency algorithm for the tag name "([^"]+)"/,
   'adoption agency algorithm', 'tag_name'],
  [qr/run the adoption agency algorithm for the token's tag name/,
   'adoption agency algorithm'],
  [qr/run the application cache selection algorithm with (the result of applying the URL serializer algorithm to the resulting parsed URL with the exclude fragment flag set)/,
   'application cache selection algorithm', 'INPUT'],
  [qr/resolve (.+) to an absolute URL, relative to (.+)/,
   'resolve', 'INPUT', 'BASE'],
  [qr/reprocess (.+) using the rules given in (.+)/,
   'REPROCESS', 'TARGET', 'RULE'],
  [qr/drop the attributes from the token, and act as described in the next entry; i.e. act as if this was a ("br" start tag token) with no attributes, rather than the end tag token that it actually is/,
   'REPROCESS', 'RULE'],
  [qr/ignore that token/ => 'IGNORE-THAT-TOKEN'],
];

sub parse_cond ($);
sub parse_cond ($) {
  my $COND = shift;

  my $cond;
  if ($COND =~ /^([^,]+), and ([^,]+)$/) {
    my ($l, $r) = ($1, $2);
    $cond = ['and',
      (parse_cond ($l) // ['COND', $l]),
      (parse_cond ($r) // ['COND', $r]),
    ];
  } elsif ($COND =~ /^([^,]+), or if ([^,]+)$/) {
    my ($l, $r) = ($1, $2);
    $cond = ['or',
      (parse_cond ($l) // ['COND', $l]),
      (parse_cond ($r) // ['COND', $r]),
    ];
  } elsif ($COND =~ /^([^,]+), (?:if |)([^,]+), or if ([^,]+)$/) {
    my ($l, $r, $m) = ($1, $2, $3);
    $cond = ['or',
      (parse_cond ($l) // ['COND', $l]),
      (parse_cond ($r) // ['COND', $r]),
      (parse_cond ($m) // ['COND', $m]),
    ];
  } elsif ($COND =~ /^the current node is an? ([\w-]+) element$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is not now an? ([\w-]+) element or an? ([\w-]+) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => [$1, $2]}];
  } elsif ($COND =~ /^the current node is not (?:then |)an? ([\w-]+) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is the root (html) element$/ or
           $COND =~ /^the stack of open elements has only one node on it$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => 'html'}];
  } elsif ($COND =~ /^the current node is not the root (html) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is no longer an? ([\w-]+) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the node immediately before it in the stack of open elements is an optgroup element$/) {
    $cond = ['oe[-2]', 'is', {ns => 'HTML', name => 'optgroup'}];
  } elsif ($COND =~ /^the current node is not an HTML element with the same tag name as (?:that of |)the token$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the current node is an HTML element whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6"$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => [qw(h1 h2 h3 h4 h5 h6)]}];
  } elsif ($COND =~ /^the new current node is in the SVG namespace$/) {
    $cond = ['oe[-1]', 'is', {ns => 'SVG'}];
  } elsif ($COND =~ /^the adjusted current node is an element in the (HTML|SVG|MathML) namespace$/) {
    $cond = ['adjusted current node', 'is', {ns => $1}];
  } elsif ($COND =~ /^the adjusted current node is an? ([\w-]+) element in the (\w+) namespace$/) {
    $cond = ['adjusted current node', 'is', {ns => $2, name => $1}];
  } elsif ($COND =~ /^the adjusted current node is an? (.+? integration point)$/) {
    $cond = ['adjusted current node', 'is', {$1 => 1}];
  } elsif ($COND =~ /^the current node is not node$/ or
           $COND =~ /^node is not the current node$/) {
    $cond = ['oe[-1]', 'is', 'node'];
  } elsif ($COND =~ /^the second element on the stack of open elements is not a body element$/) {
    $cond = ['oe[1]', 'is not', {ns => 'HTML', name => 'body'}];
  } elsif ($COND =~ /^node is not an element in the HTML namespace$/) {
    $cond = ['node', 'is not', {ns => 'HTML'}];
  } elsif ($COND =~ /^node is an HTML element with the same tag name as the token$/) {
    $cond = ['node', 'is', {ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^node's tag name, converted to ASCII lowercase, is the same as the tag name of the token$/) {
    $cond = ['node', 'lc is', {same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^node's tag name, converted to ASCII lowercase, is not the same as the tag name of the token$/) {
    $cond = ['node', 'lc is not', {same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^node is an? ([\w-]+) element$/) {
    $cond = ['node', 'is', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^node is in the special category$/) {
    $cond = ['node', 'is', {category => 'special'}];
  } elsif ($COND =~ /^node is in the special category, but is not an address, div, or p element$/) {
    $cond = ['node', 'is', {category => 'special', except => ['address', 'div', 'p']}];
  } elsif ($COND =~ /^the stack of open elements does not have an? ([\w-]+) element$/) {
    $cond = ['oe', 'not in scope', 'all', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^there is an? ([\w-]+) element on the stack of open elements$/) {
    $cond = ['oe', 'in scope', 'all', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^there is no ([\w-]+) element on the stack of open elements$/) {
    $cond = ['oe', 'not in scope', 'all', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements has an? ([\w-]+) element in scope$/) {
    $cond = ['oe', 'in scope', 'scope', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? ([\w-]+) element in scope$/) {
    $cond = ['oe', 'not in scope', 'scope', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements has an? ([\w-]+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'in scope', $2, {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? ([\w-]+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', $2, {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? ([\w-]+) or ([\w-]+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', $3, {ns => 'HTML', name => [$1, $2]}];
  } elsif ($COND =~ /^the stack of open elements does not have an? ([\w-]+), ([\w-]+), or ([\w-]+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', $4, {ns => 'HTML', name => [$1, $2, $3]}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in scope that is an HTML element with the same tag name as that of the token$/) {
    $cond = ['oe', 'not in scope', 'scope', {ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in ([\w ]+) scope that is an HTML element with the same tag name as (?:that of |)the token$/) {
    $cond = ['oe', 'not in scope', $1, {ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in scope that is an HTML element and whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6"$/) {
    $cond = ['oe', 'not in scope', 'scope', {ns => 'HTML', name => [qw(h1 h2 h3 h4 h5 h6)]}];
  } elsif ($COND =~ /^there is a node in the stack of open elements that is not either ((?:an?|the) [\w-]+ element(?:, (?:or |)(?:an?|the) [\w-]+ element)+)$/) {
    my @s;
    my $s = $1;
    push @s, $1 while $s =~ /(?:an?|the) ([\w-]+) element/g;
    $cond = ['oe', 'in scope not', 'all', {ns => 'HTML', name => \@s}];
  } elsif ($COND =~ /^node is null or if the stack of open elements does not have node in scope$/) {
    $cond = ['or',
      ['node', 'is null'],
      ['oe', 'not in scope', 'all', 'node'],
    ];
  } elsif ($COND =~ /^there is no template element on the stack of open elements and the form element pointer is not null$/) {
    $cond = ['and',
      ['oe', 'not in scope', 'all', {ns => 'HTML', name => 'template'}],
      ['form element pointer', 'is not null'],
    ];
  } elsif ($COND =~ /^node is the topmost element in the stack of open elements$/) {
    $cond = ['node', 'is', {ns => 'HTML', name => 'html'}];
  } elsif ($COND =~ /^the form element pointer is not null$/) {
    $cond = ['form element pointer', 'is not null'];
  } elsif ($COND =~ /^the token has its self-closing flag set$/) {
    $cond = ['token', 'has', 'self-closing flag'];
  } elsif ($COND =~ /^If the token's tag name is "([^"]+)"$/) {
    $cond = ['token tag_name', 'is', $1];
  } elsif ($COND =~ /^the list of active formatting elements contains an? ([\w-]+) element between the end of the list and the last marker on the list \(or the start of the list if there is no marker on the list\)$/) {
    $cond = ['afe', 'in scope', 'marker', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^any of the tokens in the pending table character tokens list are character tokens that are not space characters$/) {
    $cond = ['pending table character tokens list', 'has non-space'];
  } elsif ($COND =~ /^the stack of template insertion modes is not empty$/) {
    $cond = ['stack of template insertion modes', 'is not empty'];
  } elsif ($COND =~ /^the next token is a U\+000A LINE FEED \(LF\) character token$/) {
    $cond = ['NEXT_IS_LF_TOKEN'];
  } elsif ($COND =~ /^the document is not an iframe srcdoc document$/) {
    $cond = ['not iframe srcdoc document'];
  } elsif ($COND =~ /^the parser was originally created (?:for|as part of) the HTML fragment parsing algorithm$/) {
    $cond = ['fragment'];
  } elsif ($COND =~ /^the Document is being loaded as part of navigation of a browsing context$/) {
    $cond = ['navigate'];
  } elsif ($COND =~ /^the Document is not set to quirks mode$/) {
    $cond = ['not quirks'];
  } elsif ($COND =~ /^the frameset-ok flag is set to "not ok"$/) {
    $cond = ['frameset-ok flag', 'is', 'not ok'];
  } elsif ($COND =~ /^the parser was not originally created as part of the HTML fragment parsing algorithm \(fragment case\)$/) {
    $cond = ['fragment'];
  } elsif ($COND =~ /^the insertion mode is one of "in table", "in caption", "in table body", "in row", or "in cell"$/) {
    $cond = ['im', 'is', ['in table', 'in caption', 'in table body', 'in row', 'in cell']];
  } elsif ($COND =~ /^the parser's script nesting level is zero$/) {
    $cond = ['script nesting level', 'is', 0];
  } elsif ($COND =~ /^there is a pending parsing-blocking script$/) {
    $cond = ['pending parsing-blocking script'];
  } elsif ($COND =~ /^the stack of open elements is empty$/) {
    $cond = ['oe', 'is empty'];
  } elsif ($COND =~ /^the stack of script settings objects is empty$/) {
    $cond = ['stack of script settings objects', 'is empty'];
  } elsif ($COND =~ /^the token does not have an attribute with the name "type", or if it does, but that attribute's value is not an ASCII case-insensitive match for the string "hidden"$/) {
    $cond = ['token[type]', 'lc is not', 'hidden'];
  } elsif ($COND =~ /^the token has an attribute called "action"$/) {
    $cond = ['token', 'has attr', 'action'];
  } elsif ($COND =~ /^the element has a charset attribute, and getting an encoding from its value results in a supported ASCII-compatible character encoding or a UTF-16 encoding, and the confidence is currently tentative$/) {
    $cond = ['can change the encoding'];
  } elsif ($COND =~ /^the token's tag name is one of the ones in the first column of the following table$/) {
    $cond = ['TAG-NAME-IN-NEXT-TABLE'];
  } elsif ($COND =~ /^the token is an? (.+) token$/) {
    $cond = ['token', 'is a', {
      'character' => 'CHAR',
      'end-of-file' => 'EOF',
    }->{$1} || uc $1];
  } elsif ($COND =~ /^the token is an? (start|end) tag$/) {
    $cond = ['token', 'is a', uc $1];
  } elsif ($COND =~ /^the token is a start tag whose tag name is neither "([^"]+)" nor "([^"]+)"$/) {
    $cond = ['and', ['token', 'is a', 'START'], ['token tag_name', 'is not', [$1, $2]]];
  } elsif ($COND =~ /^the token is a start tag whose tag name is "([^"]+)"$/) {
    $cond = ['and', ['token', 'is a', 'START'], ['token tag_name', 'is', [$1]]];
  }

  #warn $COND if not defined $cond;
  return $cond;
} # parse_cond

my $used_error_names = {};
sub error_name ($) {
  my $name = lc shift;
  $name =~ s[:(\w+(?: \w+){3,})]{
    my $s = ':' . join '', map { substr $_, 0, 1 } split m{ }, $1;
    $s =~ s/((\w)\2\2+)/$2 . length $1/ge;
    $s;
  }ge;
  $name =~ s/[^a-z0-9]/-/g;
  $name =~ s/-char-0000$/-null/;
  $name =~ s/-char-ws$/-ws/;
  $name =~ s/-char-else$/-char/;
  if ($used_error_names->{$name}++) {
    return $name . '-' . $used_error_names->{$name};
  } else {
    return $name;
  }
} # error_name

sub process_actions ($$);
sub process_actions ($$) {
  my ($acts, $error_context) = @_;
  my $new_acts = [];

  ACT: for my $act (@$acts) {
    $act->{DESC} = $NormalizeDesc->{$act->{DESC}} // $act->{DESC}
        if defined $act->{DESC};
    next if $act->{type} eq 'UNPARSED' and not length $act->{DESC};
    next if $act->{type} eq 'UNPARSED' and $act->{DESC} =~ /^this might cause /;

    if ($act->{type} eq 'UNPARSED' and
        $DescIsType->{$act->{DESC}}) {
      push @$new_acts, {type => $act->{DESC}};
    } elsif ($act->{type} eq 'UNPARSED' and
             $act->{DESC} =~ /^(?:this is a|follow the) (.+)$/ and
             $DescIsType->{$1}) {
      push @$new_acts, {type => $1};
    } else {
      if ($act->{type} eq 'UNPARSED') {
        for my $p (@$DescPatterns) {
          if ($act->{DESC} =~ /^$p->[0]$/) {
            my $t = {type => $p->[1]};
            for (2..$#$p) {
              no strict 'refs';
              $t->{$p->[$_]} = ${$_-1};
            }
            push @$new_acts, $t;
            next ACT;
          }
        }
      }

      if (($act->{type} eq 'IF' or $act->{type} eq 'ELSIF') and
          defined $act->{COND}) {
        my $cond = parse_cond $act->{COND};
        if (defined $cond) {
          $act->{cond} = $cond;
          delete $act->{COND};
        }
      }

      for (qw(actions false_actions between_actions)) {
        if ($act->{$_}) {
          $act->{$_} = process_actions $act->{$_}, $error_context;
        }
      }
      push @$new_acts, $act;
    }
  }

  for my $act (@$new_acts) {
    if (defined $act->{IM}) {
      if ($act->{IM} =~ /^"([^"]+)"$/) {
        $act->{im} = $1;
        delete $act->{IM};
      } elsif ($act->{IM} eq 'the original insertion mode') {
        $act->{im} = ['original'];
        delete $act->{IM};
      } elsif ($act->{IM} eq 'current insertion mode') {
        $act->{im} = ['current'];
        delete $act->{IM};
      } else {
        warn $act->{IM};
      }
    }

    if ($act->{type} eq 'POP') {
      if (not defined $act->{LIST} or
          $act->{LIST} eq 'the stack of open elements' or
          $act->{LIST} eq 'the stack of open elements stack' or
          $act->{LIST} eq 'this stack' or
          $act->{LIST} eq 'the stack' or
          $act->{LIST} eq 'the bottom of the stack of open elements') {
        if (not defined $act->{ITEM}) {
          if ($act->{'FROM-ITEM'} eq 'the current node') {
            if ($act->{'TO-ITEM'} eq ' node, including node') {
              $act->{type} = 'pop-oe';
              $act->{until} = 'node';
              delete $act->{'FROM-ITEM'};
              delete $act->{'TO-ITEM'};
              delete $act->{LIST};
            } elsif ($act->{'TO-ITEM'} eq ', but not including, the root html element') {
              $act->{type} = 'pop-oe';
              $act->{until} = 'oe[1]';
              delete $act->{'FROM-ITEM'};
              delete $act->{'TO-ITEM'};
              delete $act->{LIST};
            }
          }
        } elsif ($act->{ITEM} =~ /^(?:the current node(?: \([^()]+\)|)|elements|that [\w-]+ element|that node|an element)$/) {
          $act->{type} = 'pop-oe';
          delete $act->{LIST};
          delete $act->{ITEM};
        } else {
          warn $act->{ITEM};
        }
      } elsif ($act->{LIST} eq 'the stack of template insertion modes') {
        if (not defined $act->{ITEM}) {
          #
        } elsif ($act->{ITEM} eq 'the current template insertion mode') {
          $act->{type} = 'pop-template-ims';
          delete $act->{LIST};
          delete $act->{ITEM};
        } else {
          warn $act->{ITEM};
        }
      } else {
        warn $act->{LIST};
      }
    } # POP

    if ($act->{type} eq 'PUSH') {
      if ($act->{LIST} eq 'the stack of open elements' or
          $act->{LIST} eq 'the stack of open elements so that it is the new current node') {
        if ($act->{ITEM} eq 'the node pointed to by the head element pointer') {
          $act->{type} = 'push-oe';
          $act->{item} = 'head element pointer';
          delete $act->{LIST};
          delete $act->{ITEM};
        } elsif ($act->{ITEM} eq 'this element' or
                 $act->{ITEM} eq 'the element') {
          $act->{type} = 'push-oe';
          delete $act->{LIST};
          delete $act->{ITEM};
        } else {
          warn $act->{ITEM};
        }
      } elsif ($act->{LIST} eq 'the stack of template insertion modes so that it is the new current template insertion mode') {
        if ($act->{ITEM} =~ /^"([^"]+)"$/) {
          $act->{type} = 'push-template-ims';
          $act->{im} = $1;
          delete $act->{LIST};
          delete $act->{ITEM};
        } else {
          warn $act->{ITEM};
        }
      } else {
        warn $act->{LIST};
      }
    } # PUSH

    if ($act->{type} eq 'REMOVE') {
      if ($act->{LIST} eq 'the stack of open elements') {
        if ($act->{ITEM} eq 'the node pointed to by the head element pointer') {
          $act->{type} = 'remove-oe';
          $act->{item} = 'head element pointer';
          delete $act->{LIST};
          delete $act->{ITEM};
        } elsif ($act->{ITEM} eq 'node') {
          $act->{type} = 'remove-oe';
          $act->{item} = 'node';
          delete $act->{LIST};
          delete $act->{ITEM};
        } else {
          warn $act->{ITEM};
        }
      } elsif ($act->{LIST} eq 'its parent node, if it has one' and
               $act->{ITEM} eq 'the second element on the stack of open elements') {
        $act->{type} = 'remove-tree';
        $act->{item} = 'oe[1]';
        delete $act->{LIST};
        delete $act->{ITEM};
      } else {
        warn $act->{LIST};
      }
    } # REMOVE

    if ($act->{type} eq 'SET') {
      if ($act->{TARGET} eq 'node') {
        if ($act->{VALUE} eq 'the current node (the bottommost node of the stack)') {
          $act->{type} = 'set-node';
          $act->{value} = 'oe[-1]';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } elsif ($act->{VALUE} eq 'the previous entry in the stack of open elements') {
          $act->{type} = 'set-node';
          $act->{value} = 'oe[i-1]';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } elsif ($act->{VALUE} eq 'the element that the form element pointer is set to, or null if it is not set to an element') {
          $act->{type} = 'set-node';
          $act->{value} = 'form element pointer';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} eq 'script' and
               $act->{VALUE} eq 'the current node (which will be a script element)') {
        $act->{type} = 'set-script';
        $act->{value} = 'oe[-1]';
      } elsif ($act->{TARGET} eq 'the frameset-ok flag') {
        if ($act->{VALUE} eq '"not ok"') {
          $act->{type} = 'set-false';
          $act->{target} = 'frameset-ok';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} eq 'the pending table character tokens') {
        if ($act->{VALUE} eq 'an empty list of tokens') {
          $act->{type} = 'set-empty';
          $act->{target} = 'pending table character tokens';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} eq 'the original insertion mode') {
        if ($act->{VALUE} eq 'the current insertion mode') {
          $act->{type} = 'set-current-im';
          $act->{target} = 'original insertion mode';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} eq 'the head element pointer' and
               $act->{VALUE} eq 'the newly created head element') {
        $act->{type} = 'set-head-element-pointer';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the form element pointer') {
        if ($act->{VALUE} eq 'the element created') {
          $act->{type} = 'set-form-element-pointer';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } elsif ($act->{VALUE} eq 'null') {
          $act->{type} = 'set-null';
          $act->{target} = 'form element pointer';
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} eq 'the parser pause flag') {
        if ($act->{VALUE} eq 'true' or
            $act->{VALUE} eq 'false') {
          $act->{type} = 'set-' . $act->{VALUE};
          $act->{target} = $act->{TARGET};
          $act->{target} =~ s/^the //;
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          #warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} =~ /^the ([\w-]+) attribute on the resulting form element$/ and
               $act->{VALUE} =~ /^the value of the "(\Q$1\E)" attribute of the token$/) {
        $act->{type} = 'set-form-attr';
        $act->{target} = $1;
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the old insertion point' and
               $act->{VALUE} eq 'the same value as the current insertion point') {
        $act->{type} = 'set-insertion-point';
        $act->{target} = 'old insertion point';
        $act->{value} = 'current insertion point';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the insertion point' and
               $act->{VALUE} eq 'just before the next input character') {
        $act->{type} = 'set-insertion-point';
        $act->{target} = 'insertion point';
        $act->{value} = 'before next input character';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the insertion point' and
               $act->{VALUE} eq 'the value of the old insertion point') {
        $act->{type} = 'set-insertion-point';
        $act->{target} = 'insertion point';
        $act->{value} = 'old insertion point';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the adjusted insertion location' and
               $act->{VALUE} eq 'the appropriate place for inserting a node') {
        $act->{type} = 'set-appropriate-place';
        $act->{target} = 'adjusted insertion location';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } elsif ($act->{TARGET} eq 'the Document' and 
               $act->{VALUE} eq 'quirks mode') {
        $act->{type} = 'set-compat-mode';
        $act->{value} = 'quirks';
        delete $act->{TARGET};
        delete $act->{VALUE};
      } else {
        #warn $act->{TARGET};
      }
    } # SET

    if ($act->{type} eq 'MARK') {
      if ($act->{TARGET} eq 'the element' or
          $act->{TARGET} eq 'the script element') {
        if ($act->{VALUE} =~ /^"([^"]+)"$/) {
          $act->{type} = 'set-node-flag';
          $act->{target} = $1;
          delete $act->{TARGET};
          delete $act->{VALUE};
        } else {
          warn $act->{VALUE};
        }
      } else {
        warn $act->{TARGET};
      }
    } # MARK

    if ($act->{type} eq 'UNSET') {
      if ($act->{TARGET} =~ /^the element's "([^"]+)" flag$/) {
        $act->{type} = 'unset-node-flag';
        $act->{target} = $1;
        delete $act->{TARGET};
      } else {
        warn $act->{TARGET};
      }
    } # UNSET

    if ($act->{type} eq 'APPEND') {
      if (defined $act->{LOCATION}) {
        if ($act->{LOCATION} eq 'the adjusted insertion location') {
          $act->{type} = 'append-to-adjusted-insertion-location';
          delete $act->{LOCATION};
        } else {
          warn $act->{LOCATION};
        }
      } elsif ($act->{LIST} eq 'the Document object' and
               $act->{ITEM} eq 'it') {
        $act->{type} = 'append-to-document';
        delete $act->{LIST};
        delete $act->{ITEM};
      } elsif ($act->{LIST} eq 'the pending table character tokens list' and
               $act->{ITEM} eq 'the character token') {
        $act->{type} = 'append-to-pending-table-character-tokens-list';
        delete $act->{LIST};
        delete $act->{ITEM};
      } elsif ($act->{ITEM} eq 'a DocumentType node') {
        $act->{type} = 'append-to-document';
        $act->{item} = 'DocumentType';
        delete $act->{LIST};
        delete $act->{ITEM};
      } elsif ($act->{LIST} eq 'the list of active formatting elements' and
               $act->{ITEM} eq 'a marker') {
        $act->{type} = 'append-marker-to-afe';
        delete $act->{LIST};
        delete $act->{ITEM};
      } else {
        warn $act->{LIST};
      }
    } # APPEND

    if ($act->{type} eq 'INCREMENT' or
        $act->{type} eq 'DECREMENT') {
      $act->{type} = lc $act->{type};
      $act->{target} = $act->{TARGET};
      $act->{target} =~ s/^the //;
      $act->{target} =~ s/^parser's //;
      delete $act->{TARGET};
    } # INCREMENT/DECREMENT

    if ($act->{type} eq 'insert a comment' and
        defined $act->{AS}) {
      if ($act->{AS} eq 'the last child of the Document object') {
        $act->{position} = 'document';
        delete $act->{AS};
      } elsif ($act->{AS} eq 'the last child of the first element in the stack of open elements (the html element)') {
        $act->{position} = 'oe[0]';
        delete $act->{AS};
      } else {
        warn $act->{AS};
      }
    } # insert a comment

    if ($act->{type} eq 'insert a character' and
        defined $act->{CHAR}) {
      if ($act->{CHAR} eq 'see below for what they should say') {
        $act->{type} = 'insert-chars';
        $act->{value} = ['prompt-string'];
        delete $act->{CHAR};
      } elsif ($act->{CHAR} eq 'the pending table character tokens list') {
        $act->{type} = 'insert-chars';
        $act->{value} = ['pending table character tokens list'];
        delete $act->{CHAR};
      } elsif ($act->{CHAR} =~ /^U\+([0-9A-F]+) [A-Z ]+$/) {
        $act->{value} = chr hex $1;
        delete $act->{CHAR};
      } else {
        warn $act->{CHAR};
      }
    } # insert a character

    if ($act->{type} eq 'insert an HTML element') {
      if (defined $act->{ATTRS}) {
        if ($act->{ATTRS} eq 'no attributes') {
          $act->{attrs} = 'none';
          delete $act->{ATTRS};
        } elsif ($act->{ATTRS} =~ /^all the attributes from the "isindex" token except "name", "action", and "prompt", and with an attribute named "name" with the value "isindex"$/) {
          $act->{attrs} = 'isindex';
          delete $act->{ATTRS};
        } else {
          warn $act->{ATTRS};
        }
      }
    } # insert an HTML element

    if ($act->{type} eq 'insert a foreign element') {
      if ($act->{NS} eq 'the same namespace as the adjusted current node') {
        $act->{ns} = 'inherit';
        delete $act->{NS};
      } elsif ($act->{NS} =~ /^the (\w+) namespace$/) {
        $act->{ns} = $1;
        delete $act->{NS};
      } else {
        warn $act->{NS};
      }
    } # insert a foreign element

    if ($act->{type} eq 'create an HTML element') {
      if (defined $act->{INTENDED_PARENT}) {
        if ($act->{INTENDED_PARENT} eq 'the element in which the adjusted insertion location finds itself') {
          $act->{intended_parent} = 'adjusted insertion location parent';
          delete $act->{INTENDED_PARENT};
        } elsif ($act->{INTENDED_PARENT} eq 'the Document') {
          $act->{INTENDED_PARENT} = 'document';
          delete $act->{INTENDED_PARENT};
        } else {
          warn $act->{INTENDED_PARENT};
        }
      }
      if (defined $act->{ATTRS} and (delete $act->{ATTRS}) eq '') {
        $act->{attrs} = 'none';
      }
    } # create an HTML element

    if ($act->{type} eq 'generate implied end tags') {
      if (defined $act->{EXCEPT}) {
        if ($act->{EXCEPT} eq 'HTML elements with the same tag name as the token') {
          $act->{except} = {ns => 'HTML', same_tag_name_as_token => 1};
          delete $act->{EXCEPT};
        } elsif ($act->{EXCEPT} =~ /^([\w-]+) elements$/) {
          $act->{except} = {ns => 'HTML', name => $1};
          delete $act->{EXCEPT};
        } else {
          warn $act->{EXCEPT};
        }
      }
    } # generate implied end tags

    if ($act->{type} eq 'UNTIL') {
      if (@{$act->{actions}} == 1 and
          $act->{actions}->[0]->{type} eq 'pop-oe' and
          1 == keys %{$act->{actions}->[0]} and
          defined $act->{COND} and
          3 == keys %$act) {
        if ($act->{COND} =~ /^an? ([\w-]+) element has been popped from the stack$/) {
          $act->{type} = 'pop-oe';
          $act->{until} = {ns => 'HTML', name => $1};
          delete $act->{actions};
          delete $act->{COND};
        } elsif ($act->{COND} =~ /^an? ([\w-]+) element or an? ([\w-]+) element has been popped from the stack$/) {
          $act->{type} = 'pop-oe';
          $act->{until} = {ns => 'HTML', name => [$1, $2]};
          delete $act->{actions};
          delete $act->{COND};
        } elsif ($act->{COND} =~ /^an HTML element with the same tag name as the token has been popped from the stack$/) {
          $act->{type} = 'pop-oe';
          $act->{until} = {ns => 'HTML', same_tag_name_as_token => 1};
          delete $act->{actions};
          delete $act->{COND};
        } elsif ($act->{COND} =~ /^an HTML element whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6" has been popped from the stack$/) {
          $act->{type} = 'pop-oe';
          $act->{until} = {ns => 'HTML', name => [qw(h1 h2 h3 h4 h5 h6)]};
          delete $act->{actions};
          delete $act->{COND};
        } elsif ($act->{COND} =~ /^the current node is a MathML text integration point, an HTML integration point, or an element in the HTML namespace$/) {
          $act->{type} = 'pop-oe';
          $act->{while_not} = ['or',
                               {'MathML text integration point' => 1},
                               {'HTML integration point' => 1},
                               {ns => 'HTML'}];
          delete $act->{actions};
          delete $act->{COND};
        } elsif ($act->{COND} =~ /^node has been popped from the stack$/) {
          $act->{type} = 'pop-oe';
          $act->{until} = 'node';
          delete $act->{actions};
          delete $act->{COND};
        } else {
          die "Unknown UNTIL COND |$act->{COND}|";
        }
      } elsif (4 == keys %$act and $act->{WHILE}) {
        if ($act->{COND} =~ /^the current node is not an? ([\w-]+(?:, (?:or |)[\w-]+)+) element$/) {
          $act->{type} = 'pop-oe';
          $act->{while_not} = {ns => 'HTML', name => [split /, (?:or |)/, $1]};
          delete $act->{actions};
          delete $act->{COND};
          delete $act->{WHILE};
        } elsif ($act->{COND} =~ /^the current node is (an? [\w-]+ element(?:, (?:or |)an? [\w-]+ element)+)$/) {
          my $s = $1;
          my @s;
          push @s, $1 while $s =~ /([\w-]+) element/g;
          $act->{type} = 'pop-oe';
          $act->{while} = {ns => 'HTML', name => \@s};
          delete $act->{actions};
          delete $act->{COND};
          delete $act->{WHILE};
        } else {
          die "Unknown WHILE COND |$act->{COND}|";
        }
      } else {
        warn "Unknown UNTIL";
      }
    } # UNTIL

    if ($act->{type} eq 'FOR-EACH' and
        $act->{ITEMS} eq 'attribute on the token' and
        @{$act->{actions}} == 1 and
        $act->{actions}->[0]->{type} eq 'IF' and
        @{$act->{actions}->[0]->{actions}} == 1 and
        $act->{actions}->[0]->{actions}->[0]->{type} eq 'add the attribute and its corresponding value to that element') {
      if ($act->{actions}->[0]->{COND} =~ /^the attribute is already present on (the top element of the stack of open elements|the body element \(the second element\) on the stack of open elements)$/) {
        $act->{type} = 'set-attrs-if-missing';
        $act->{node} = $1 =~ /second/ ? 'oe[1]' : 'oe[0]';
        delete $act->{actions};
        delete $act->{ITEMS};
      } else {
        warn $act->{actions}->[0]->{COND};
      }
    }

    if ($act->{type} eq 'IF' and
        defined $act->{TABLE_ELEMENT} and
        ref $act->{cond} eq 'ARRAY' and
        @{$act->{cond}} == 3 and
        $act->{cond}->[0] eq 'and' and
        $act->{cond}->[1]->[0] eq 'adjusted current node' and
        $act->{cond}->[1]->[1] eq 'is' and
        $act->{cond}->[1]->[2]->{ns} eq 'SVG' and
        $act->{cond}->[2]->[0] eq 'TAG-NAME-IN-NEXT-TABLE' and
        @{$act->{actions}} == 1 and
        $act->{actions}->[0]->{DESC} eq 'change the tag name to the name given in the corresponding cell in the second column') {
      my $table_el = delete $act->{TABLE_ELEMENT};
      $act->{cond} = $act->{cond}->[1];
      $act->{actions} = [{type => 'fixup-svg-tag-name'}];
      for (@{$table_el->tbodies->[0]->rows}) {
        my $tag_name = $_->cells->[0]->query_selector ('code')->text_content;
        my $local_name = $_->cells->[1]->query_selector ('code')->text_content;
        $Data->{tables}->{svg_tag_name_mapping}->{$tag_name} = $local_name;
      }
    }

    if ($act->{type} eq 'REPROCESS') {
      if ($act->{RULE} eq '"br" start tag token') {
        $act->{type} = 'SAME-AS';
        $act->{FIELD} = '"br" start tag';
        delete $act->{RULE};
      } elsif ($act->{RULE} eq 'the "anything else" entry in the "in table" insertion mode' and
               $act->{TARGET} eq 'the character tokens in the pending table character tokens list') {
        $act->{type} = 'reprocess pending table character tokens list';
        $act->{FIELD} = 'anything else';
        $act->{im} = 'in table';
        delete $act->{RULE};
        delete $act->{TARGET};
      }
    } # REPROCES
  } # $act

  for my $act (@$new_acts) {
    if ($act->{type} eq 'IF') {
      if (3 == keys %$act and
          defined $act->{cond} and
          defined $act->{actions}) {
        $act->{type} = 'if';
      } elsif (4 == keys %$act and
               defined $act->{cond} and
               defined $act->{actions} and
               defined $act->{false_actions}) {
        $act->{type} = 'if';
      } else {
        #warn "Unknown IF";
      }
    }
  }
  $acts = $new_acts;

  $new_acts = [];
  {
    my $container = $new_acts;
    my $label;
    while (@$acts) {
      my $act = shift @$acts;
      $act = {%$act};
      if (defined $label and
          $act->{type} eq 'LABEL' and
          $act->{label} eq $label) {
        $container = $new_acts;
        undef $label;
      }
      push @$container, $act;
      if ($act->{type} eq 'if' and
          not defined $act->{false_actions} and
          @{$act->{actions}} and
          $act->{actions}->[-1]->{type} eq 'SKIP-TO') {
        $label = $act->{actions}->[-1]->{label};
        $container = $act->{false_actions} = [];
      }
    }
    die "Label not found: |$label|" if defined $label;
  }
  $acts = $new_acts;

  return $new_acts;
} # process_actions

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions} or next;
    $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = resolve_action_structure $acts;
  }
}

for my $im (keys %{$Data->{ims}}) {
  my @cond = keys %{$Data->{ims}->{$im}->{conds} or {}};
  my $search_cond = sub {
    my ($type, $tag_name) = @_;
    my $cond;
    my $has_else;
    for (@cond) {
      if (/^\Q$type\E:(.+)$/) {
        if ({map { $_ => 1 } split / /, $1}->{$tag_name}) {
          $cond = $_;
          last;
        }
      } elsif ($_ eq $type.'-ELSE') {
        $has_else = 1;
      }
    }
    $cond //= $type.'-ELSE' if $has_else;
    $cond //= 'ELSE';
    return $cond;
  }; # $search_cond

  my @deleted_cond;
  my $script_conds = {};
  my $noscript_conds = {};
  for my $cond (@cond) {
    if ($cond =~ /^CURRENT-CHAR:(.+)$/) {
      my $els = [split / /, $1];
      my $found;
      for (@cond) {
        if (/^(?:CHAR:|CHAR-ELSE$)/) {
          $Data->{ims}->{$im}->{conds}->{$_}->{actions}
              = [{type => 'if',
                  cond => ['oe[-1]', 'is', {ns => 'HTML', name => $els}],
                  actions => $Data->{ims}->{$im}->{conds}->{$cond}->{actions},
                  false_actions => $Data->{ims}->{$im}->{conds}->{$_}->{actions}}];
          $found = 1 if $_ eq 'CHAR-ELSE';
        }
      }
      unless ($found) {
        $Data->{ims}->{$im}->{conds}->{'CHAR-ELSE'}->{actions}
            = [{type => 'if',
                cond => ['oe[-1]', 'is', {ns => 'HTML', name => $els}],
                actions => $Data->{ims}->{$im}->{conds}->{$cond}->{actions},
                false_actions => $Data->{ims}->{$im}->{conds}->{ELSE}->{actions}}];
      }
      push @deleted_cond, $cond;
    } elsif ($cond =~ /^SCRIPT-START:(.+)$/) {
      $script_conds->{$1} = $cond;
    } elsif ($cond =~ /^NOSCRIPT-START:(.+)$/) {
      $noscript_conds->{$1} = $cond;
    } elsif ($cond =~ /^SVGSCRIPT-END:(.+)$/) {
      my $tag_names = [split / /, $1];
      for my $tag_name (@$tag_names) {
        my $else_cond = $search_cond->('END', $tag_name);
        $Data->{ims}->{$im}->{conds}->{'END:'.$tag_name}->{actions}
            = [{type => 'if',
                cond => ['oe[-1]', 'is', {ns => 'SVG', name => 'script'}],
                actions => $Data->{ims}->{$im}->{conds}->{$cond}->{actions},
                false_actions => $Data->{ims}->{$im}->{conds}->{$else_cond}->{actions}}];
      }
      push @deleted_cond, $cond;
    } elsif ($cond =~ /^START-ATTR:(.+?):(.+)$/) {
      my $attrs = $2;
      my $tag_names = [split / /, $1];
      for my $tag_name (@$tag_names) {
        my $else_cond = $search_cond->('START', $tag_name);
        $Data->{ims}->{$im}->{conds}->{'START:'.$tag_name}->{actions}
            = [{type => 'if',
                cond => ['token', 'has attr', [split / /, $attrs]],
                actions => $Data->{ims}->{$im}->{conds}->{$cond}->{actions},
                false_actions => $Data->{ims}->{$im}->{conds}->{$else_cond}->{actions}}];
      }
      push @deleted_cond, $cond;
    }
  } # $cond

  my $any_script_conds = {%$script_conds, %$noscript_conds};
  for my $tag_name (keys %$any_script_conds) {
    my $script_cond = $script_conds->{$tag_name}
        // $search_cond->('START', $tag_name);
    my $noscript_cond = $noscript_conds->{$tag_name}
        // $search_cond->('START', $tag_name);
    $Data->{ims}->{$im}->{conds}->{'START:'.$tag_name}->{actions}
        = [{type => 'if',
            cond => ['scripting'],
            actions => $Data->{ims}->{$im}->{conds}->{$script_cond}->{actions},
            false_actions => $Data->{ims}->{$im}->{conds}->{$noscript_cond}->{actions}}];
  }
  delete $Data->{ims}->{$im}->{conds}->{$_}
      for @deleted_cond, values %$script_conds, values %$noscript_conds;
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    for (qw(actions false_actions between_actions)) {
      my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{$_};
      if (defined $acts) {
        $acts = for_actions {
          my $acts = shift;
          for my $act (@$acts) {
            if ($act->{type} eq 'parse error') {
              $act->{name} = error_name join '-', $im, $cond;
            }
          }
          return $acts;
        } process_actions $acts, join '-', $im, $cond;
        $Data->{ims}->{$im}->{conds}->{$cond}->{$_} = $acts;
      }
    }
  }
}

sub replace_break_action ($$);
sub replace_break_action ($$) {
  my ($acts, $label) = @_;
  for my $act (@$acts) {
    if ($act->{type} eq 'SKIP-TO' and
        $act->{label} eq $label) {
      $act->{type} = 'break-for-each';
      delete $act->{label};
    }
    for (qw(actions false_actions between_actions)) {
      replace_break_action $act->{$_}, $label if defined $act->{$_};
    }
  }
} # replace_break_action

sub process_action_blocks ($);
sub process_action_blocks ($) {
  my $acts = shift;

  for my $act (@$acts) {
    for (qw(actions false_actions between_actions)) {
      $act->{$_} = process_action_blocks $act->{$_} if defined $act->{$_};
    }
  }

  my $new_acts = [];
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'if' and
        @{$act->{actions} or []} and
        @{$act->{false_actions} or []}) {
      if ($act->{actions}->[-1]->{type} eq 'SKIP-TO' and
          $act->{false_actions}->[-1]->{type} eq 'JUMP-BACK') {
        push @$new_acts, $act;
        push @$new_acts, splice @{$act->{false_actions}}, -2, 1, ()
            if @{$act->{false_actions}} >= 2 and
               $act->{false_actions}->[-2]->{type} eq 'set-node' and
               $act->{false_actions}->[-2]->{value} eq 'oe[i-1]';
        push @$new_acts, pop @{$act->{false_actions}};
        next;
      } elsif ($act->{actions}->[-1]->{type} eq 'JUMP-BACK') {
        push @$new_acts, $act;
        push @$new_acts, splice @{$act->{actions}}, -2, 1, ()
            if @{$act->{actions}} >= 2 and
               $act->{actions}->[-2]->{type} eq 'set-node' and
               $act->{actions}->[-2]->{value} eq 'oe[i-1]';
        push @$new_acts, pop @{$act->{actions}};
        push @{$act->{false_actions}}, {type => 'break-for-each'};
        next;
      }
    } elsif ($act->{type} eq 'LABEL' and
             @$new_acts >= 2 and
             $new_acts->[-1]->{type} eq 'if' and
             $new_acts->[-1]->{cond}->[0] eq 'node' and
             $new_acts->[-2]->{type} eq 'set-node' and
             $new_acts->[-2]->{value} eq 'oe[-1]') {
      $new_acts->[-1]->{cond} = [@{$new_acts->[-1]->{cond}}];
      $new_acts->[-1]->{cond}->[0] = 'oe[-1]';
      @$new_acts[-1, -2] = @$new_acts[-2, -1];
    } elsif ($act->{type} eq 'with-foster-parenting' and
             @{$act->{actions}} == 1 and
             $act->{actions}->[0]->{type} eq 'USING-THE-RULES-FOR') {
      $act->{type} = $act->{actions}->[0]->{type};
      $act->{im} = $act->{actions}->[0]->{im};
      $act->{foster_parenting} = 1;
      delete $act->{actions};
    } elsif ($act->{type} eq 'if' and
             $act->{cond}->[0] eq 'navigate' and
             @{$act->{actions}} == 1 and
             $act->{actions}->[0]->{type} eq 'application cache selection algorithm') {
      $act->{type} = 'appcache-processing';
      $act->{can_have_manifest} = 1 if $act->{actions}->[0]->{INPUT};
      delete $act->{cond};
      delete $act->{actions};
    } elsif ($act->{type} eq 'if' and
             $act->{cond}->[0] eq 'NEXT_IS_LF_TOKEN' and
             @{$act->{actions}} == 2 and
             $act->{actions}->[0]->{type} eq 'IGNORE-THAT-TOKEN' and
             $act->{actions}->[1]->{type} eq 'NEXT-TOKEN') {
      $act->{type} = 'ignore-next-lf';
      delete $act->{cond};
      delete $act->{actions};
    }
    push @$new_acts, $act;
  }
  $acts = $new_acts;

  $new_acts = [];
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'if' and
        @{$act->{actions} or []} >= 1 and
        defined $act->{false_actions} and
        $act->{actions}->[-1]->{type} eq 'ignore the token') {
      $act->{false_actions} = [@{$act->{false_actions}}, @$acts];
      $acts = [];
      push @$new_acts, $act;
    } else {
      push @$new_acts, $act;
    }
  }
  $acts = $new_acts;

  my @before_label;
  my @in_label;
  my @between;
  my $label;
  my $in_between;
  while (@$acts) {
    my $act = shift @$acts;
    if (not defined $label and $act->{type} eq 'LABEL') {
      $label = $act->{label};
    } elsif (defined $label and
             $act->{type} eq 'JUMP-BACK' and
             $act->{label} eq $label) {
      push @before_label, {type => 'LOOP', label => $label,
                           actions => [@in_label]};
      $before_label[-1]->{between_actions} = [@between] if $in_between;
      @between = ();
      @in_label = ();
      undef $label;
      undef $in_between;

      if (@before_label >= 2 and
          $before_label[-2]->{type} eq 'set-node' and
          $before_label[-2]->{value} eq 'oe[-1]') {
        $before_label[-1]->{type} = 'for-each-reverse-oe-as-node';
        delete $before_label[-1]->{label};
        splice @before_label, -2, 1, ();

        if (@$acts and $acts->[0]->{type} eq 'LABEL') {
          replace_break_action $before_label[-1]->{actions}, $acts->[0]->{label};
          shift @$acts;
        }
      }
    } elsif (defined $label and not $in_between and
             $act->{type} eq 'set-node' and $act->{value} eq 'oe[i-1]') {
      $in_between = 1;
    } else {
      if (defined $label) {
        if ($in_between) {
          push @between, $act;
        } else {
          push @in_label, $act;
        }
      } else {
        push @before_label, $act;
      }
    }
  }
  if (defined $label) {
    if ($in_between) {
      $new_acts = [@before_label, {type => 'LABEL', label => $label}, @in_label, {type => 'set-node', value => 'oe[i-1]'}, @between];
    } else {
      $new_acts = [@before_label, {type => 'LABEL', label => $label}, @in_label];
    }
  } else {
    $new_acts = [@before_label];
  }

  return $new_acts;
} # process_action_blocks

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    for (qw(actions false_actions between_actions)) {
      my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{$_};
      $Data->{ims}->{$im}->{conds}->{$cond}->{$_} = process_action_blocks $acts if defined $acts;
    }
  }
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    my @def = $Data->{ims}->{$im}->{conds}->{$cond};
    while (@def) {
      my $def = shift @def;
      for my $key (qw(actions false_actions between_actions)) {
        my $acts = $def->{$key} or next;
        my $new_acts = [];
        while (@$acts) {
          my $act = pop @$acts;
          if ($act->{type} eq 'REMOVE-THAT-FROM-AFE-AND-OE' and
              @$acts and
              $acts->[-1]->{type} eq 'adoption agency algorithm') {
            $acts->[-1]->{remove_from_afe_and_oe} = 1;
            next;
          }

          if (defined $act->{actions} or
              defined $act->{false_actions} or
              defined $act->{between_actions}) {
            push @def, $act;
          }
          unshift @$new_acts, $act;
        }
        $def->{$key} = $new_acts;
      }
    }
  }
}

for my $def (
  $Data->{ims}->{text}->{conds}->{'END:script'},
  $Data->{ims}->{'in foreign content'}->{conds}->{'END:script'}->{actions}->[0],
) {
  my $acts = $def->{actions} or next;
  my $new_acts = [];
  my $prev_was_script;
  my $n = 1;
  for my $act (@$acts) {
    if ({
          'set-script' => 1,
          'set-insertion-point' => 1,
          'prepare a script' => 1,
          'process the SVG script element' => 1,
          'misc' => 1,
        }->{$act->{type}} or
        (($act->{type} eq 'if' or $act->{type} eq 'IF') and
         {
           'stack of script settings objects' => 1,
           'script nesting level' => 1,
           'pending parsing-blocking script' => 1,
         }->{$act->{cond}->[0]}) or
        (defined $act->{target} and 
         {
           'script nesting level' => 1,
           'parser pause flag' => 1,
         }->{$act->{target}})) {
      unless ($prev_was_script) {
        push @$new_acts, {type => 'script-processing-' . $n++};
      }
      $prev_was_script = 1;
    } else {
      push @$new_acts, $act;
      $prev_was_script = 0;
    }
  }
  if ($n == 2) { # only script-processing-1
    $acts = $new_acts;
    $new_acts = [];
    for my $act (@$acts) {
      if ($act->{type} eq 'pop-oe') {
        push @$new_acts, {type => 'script-processing-1'}, $act;
      } elsif ($act->{type} eq 'script-processing-1') {
        push @$new_acts, {type => 'script-processing-2'};
      } else {
        push @$new_acts, $act;
      }
    }
  }
  $def->{actions} = $new_acts;
}

for my $def (
  $Data->{ims}->{'in head'}->{conds}->{'START:meta'},
) {
  my $acts = $def->{actions} or next;
  my $new_acts = [];
  my $prev_was_script;
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'if' and
        $act->{cond}->[0] eq 'can change the encoding' and
        @$acts and
        $acts->[0]->{DESC} =~ /^otherwise, if the element has an http-equiv/) {
      push @$new_acts, {type => 'change-the-encoding-if-appropriate'};
      shift @$acts;
    } else {
      push @$new_acts, $act;
    }
  }
  $def->{actions} = $new_acts;
}

my @doctype_switch_def;
for my $def (
  $Data->{ims}->{'initial'}->{conds}->{'DOCTYPE'},
) {
  my $acts = $def->{actions} or next;
  my $new_acts = [];
  my $prev_was_doctype;
  while (@$acts) {
    my $act = shift @$acts;
    if ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /parse error/) {
      push @$new_acts, {type => 'if', cond => ['legacy doctype'],
                        actions => [{type => 'parse error',
                                     name => error_name 'initial-DOCTYPE'}]};
      $prev_was_doctype = 0;
    } elsif ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /DOCTYPE token matches/) {
      push @$new_acts, {type => 'doctype-switch'} unless $prev_was_doctype;
      $prev_was_doctype = 1;
    } elsif ($act->{type} eq 'misc' and $act->{desc} =~ /<li>/) {
      push @doctype_switch_def, $act->{desc};
    } elsif ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /^conformance checkers may,/) {
      #
    } elsif ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /^associate the DocumentType node with the Document object/) {
      #
    } elsif ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /^the system identifier and public identifier strings must be compared/) {
      #
    } elsif ($act->{type} eq 'UNPARSED' and $act->{DESC} =~ /^a system identifier whose value is the empty string is not/) {
      #
    } else {
      push @$new_acts, $act;
      $prev_was_doctype = 0;
    }
  }
  $def->{actions} = $new_acts;
}
if (@doctype_switch_def == 3) {
  my $el = $doc->create_element ('div');
  $el->inner_html ($doctype_switch_def[0]);
  for (@{$el->query_selector_all ('li')}) {
    my $text = _n $_->text_content;
    $text =~ s/\xA0/ /g;
    if ($text =~ /^The DOCTYPE token's name is a case-sensitive match for the string "(html)", the token's public identifier is the case-sensitive string "([^"]+)", and the token's system identifier is either missing or the case-sensitive string "([^"]+)".$/) {
      push @{$Data->{doctype_switch}->{obsolete_permitted} ||= []},
          [$2, $3], [$2, undef];
    } elsif ($text =~ /^The DOCTYPE token's name is a case-sensitive match for the string "(html)", the token's public identifier is the case-sensitive string "([^"]+)", and the token's system identifier is the case-sensitive string "([^"]+)".$/) {
      push @{$Data->{doctype_switch}->{obsolete_permitted} ||= []},
          [$2, $3];
    } else {
      die "Unparsable doctype switch def: |$text|";
    }
  }
  {
    no warnings 'uninitialized';
    @{$Data->{doctype_switch}->{obsolete_permitted}} = sort {
      $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1];
    } @{$Data->{doctype_switch}->{obsolete_permitted}};
  }

  for ([1 => 'quirks'], [2 => 'limited_quirks']) {
    $el->inner_html ($doctype_switch_def[$_->[0]]);
    my $p = $_->[1];
    for (@{$el->query_selector_all ('li')}) {
      my $text = _n $_->text_content;
      $text =~ s/\xA0/ /g;
      if ($text =~ /^The public identifier is set to: "([^"]+)"$/) {
        $Data->{doctype_switch}->{$p}->{values}->{public_id}->{uc $1} = 1;
      } elsif ($text =~ /^The system identifier is set to: "([^"]+)"$/) {
        $Data->{doctype_switch}->{$p}->{values}->{system_id}->{uc $1} = 1;
      } elsif ($text =~ /^The public identifier starts with: "([^"]+)"$/) {
        $Data->{doctype_switch}->{$p}->{values}->{public_id_prefix}->{uc $1} = 1;
      } elsif ($text =~ /^The system identifier is missing and the public identifier starts with: "([^"]+)"$/) {
        $Data->{doctype_switch}->{$p}->{values}->{public_id_prefix_if_no_system_id}->{uc $1} = 1;
      } elsif ($text =~ /^The system identifier is not missing and the public identifier starts with: "([^"]+)"$/) {
        $Data->{doctype_switch}->{$p}->{values}->{public_id_prefix_if_system_id}->{uc $1} = 1;
      } elsif ($text =~ /^The force-quirks flag is set to on.$/) {
        #
      } elsif ($text =~ /^The name is set to anything other than "html" \(compared case-sensitively\).$/) {
        #
      } else {
        die "Unparsable doctype switch def: |$text|";
      }
    }
  }
} else {
  die "Unsupported doctype switch definition: there is |@{[scalar @doctype_switch_def]}| defs";
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    my @def = $Data->{ims}->{$im}->{conds}->{$cond};
    while (@def) {
      my $def = shift @def;
      for my $key (qw(actions false_actions between_actions)) {
        my $acts = $def->{$key} or next;
        my $new_acts = [];
        for my $act (@$acts) {
          if ($act->{type} eq 'SAME-AS') {
            if ($act->{FIELD} eq 'anything else') {
              my $else = $Data->{ims}->{$im}->{conds}->{ELSE}
                  or die "Insertion mode |$im| has no |ELSE|";
              push @$new_acts, @{$else->{actions}};
              next;
            } elsif ($act->{FIELD} eq 'any other end tag') {
              my $else = $Data->{ims}->{$im}->{conds}->{'END-ELSE'}
                  or die "Insertion mode |$im| has no |END-ELSE|";
              push @$new_acts, @{$else->{actions}};
              next;
            } elsif ($act->{FIELD} eq 'any other start tag') {
              my $else = $Data->{ims}->{$im}->{conds}->{'START-ELSE'}
                  or die "Insertion mode |$im| has no |START-ELSE|";
              push @$new_acts, @{$else->{actions}};
              next;
            } elsif ($act->{FIELD} eq '"script" end tag') {
              my $else = $Data->{ims}->{$im}->{conds}->{'END:script'}->{actions}->[0]
                  or die "Insertion mode |$im| has no |END:script|";
              push @$new_acts, @{$else->{actions}};
              next;
            } elsif ($act->{FIELD} eq '"br" start tag') {
              my $else = $Data->{ims}->{$im}->{conds}->{[grep { /^START:.*\bbr\b/ } keys %{$Data->{ims}->{$im}->{conds}}]->[0]}
                  or die "Insertion mode |$im| has no |START:br|";
              push @$new_acts, map {
                if ($_->{type} eq 'insert an HTML element') {
                  +{%$_, tag_name => 'br', attrs => 'none'};
                } else {
                  $_;
                }
              } @{$else->{actions}};
              next;
            } else {
              warn $act->{FIELD};
            }
          }
          if (defined $act->{actions} or
              defined $act->{false_actions} or
              defined $act->{between_actions}) {
            push @def, $act;
          }
          push @$new_acts, $act;
        }
        $def->{$key} = $new_acts;
      }
    }
  }
}

for my $pattern (keys %{$Data->{patterns}}) {
  my $new = [];
  for (@{$Data->{patterns}->{$pattern}}) {
    if (ref $_ eq 'ARRAY' and $_->[0] eq 'SAME-AS') {
      push @$new, @{$Data->{patterns}->{$_->[1]}};
    } else {
      push @$new, $_;
    }
  }
  $Data->{patterns}->{$pattern} = $new;
}
unshift @$_, 'or' for values %{$Data->{patterns}};

unshift @$_, 'or' for values %{$Data->{patterns_not}};

$Data->{dispatcher_html} = [map {
  if (ref $_) {
    [$_->[0], map {
      my $cond = parse_cond $_;
      if (defined $cond) {
        $cond;
      } else {
        ['COND', $_];
      }
    } @$_[1..$#$_]];
  } else {
    my $cond = parse_cond $_;
    if (defined $cond) {
      $cond;
    } else {
      ['COND', $_];
    }
  }
} @{$Data->{dispatcher_html}}];

$Data->{steps} = $Data->{ims}->{_steps}->{conds};
delete $Data->{ims}->{_steps};

print perl2json_bytes_for_record $Data;
