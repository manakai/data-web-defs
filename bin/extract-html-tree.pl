use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $doc = new Web::DOM::Document;
my $parser = new Web::HTML::Parser;
my $spec_path = path (__FILE__)->parent->parent->child (shift);
$parser->parse_byte_string (undef, $spec_path->slurp => $doc);

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

  if ($tc =~ s/^((?!Otherwise:)[A-Za-z]+):\s*//) {
    push @action, {type => 'label', label => lc $1};
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
    } elsif ($_->{DESC} =~ /^(otherwise, |)if ([A-Za-z0-9" -]+? that is not either (?:an?|the) \w+ element(?:, (?:or |)(?:an?|the) \w+ element)+), then ($SENTENCE)$/o) {
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
   } elsif ($_->{DESC} =~ /^($SENTENCE)(?:,? and|, then) ($VERB $SENTENCE)$/o) {
      my $f = $2;
      ((parse_step $1), (parse_step $f));
    } elsif ($_->{DESC} =~ /^($SENTENCE), and, if ($SENTENCE), ($SENTENCE)$/o) {
      my @a = ($1, $2, $3);
      ((parse_step $a[0]),
       {type => 'IF', cond => $a[1], actions => [parse_step $a[2]]});
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

my $im_name;
my @node = @{$doc->body->child_nodes};
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
                  push @$action_list, {type => 'actions', actions => $acts};
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
      } else { # not .switch
        unshift @node, $node->child_nodes->to_list;
      }
    } else {
      unshift @node, $node->child_nodes->to_list;
    } # $ln
  } # $node->node_type
}

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
   'SAME-AS', 'field'],
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
  [qr/append (.+) to (.+)/, 'append', 'ITEM', 'LIST'],
  [qr/increment (.+) by one/, 'increment', 'TARGET'],
  [qr/decrement (.+) by one/, 'decrement', 'TARGET'],
  [qr/process the token using the rules for the "([^"]+)" insertion mode/,
   'USING-THE-RULES-FOR', 'im'],
  [qr/process the token according to the rules given in the section corresponding to the (current insertion mode) in HTML content/,
   'USING-THE-RULES-FOR', 'IM'],
  [qr/insert (.+) at the end of (.+)/, 'insert at the end', 'ITEM', 'LIST'],
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
  [qr/insert the newly created element at (.+)/,
   'insert an element', 'LOCATION'],
  [qr/create an? (\w+) element whose ownerDocument is the Document object/,
   'create an HTML element', 'local_name'],
  [qr/create an element for the token in the HTML namespace, with (.+) as the intended parent/,
   'create an HTML element', 'INTENDED_PARENT'],
  [qr/create an element for the token in the HTML namespace, with the intended parent being (.+)/,
   'create an HTML element', 'INTENDED_PARENT'],
  [qr/generate implied end tags, except for (HTML elements with the same tag name as the token)/,
   'generate implied end tags', 'EXCEPT'],
  [qr/generate implied end tags, except for (\w+ elements)/,
   'generate implied end tags', 'EXCEPT'],
  [qr/change the token's tag name to "([^"]+)"/,
   "change the token's tag name", 'tag_name'],
  [qr/jump to the step labeled (\w+) below/,
   'skip to', 'label'],
  [qr/return to the step labeled (\w+)/,
   'jump back', 'label'],
  [qr/move on to the next one/, 'NEXT-TOKEN'],
  [qr/run the adoption agency algorithm for the tag name "([^"]+)"/,
   'adoption agency algorithm', 'tag_name'],
  [qr/run the adoption agency algorithm for the token's tag name/,
   'adoption agency algorithm'],
  [qr/run the application cache selection algorithm with (the result of applying the URL serializer algorithm to the resulting parsed URL with the exclude fragment flag set)/,
   'application cache selection algorithm', 'INPUT'],
  [qr/reprocess (.+) using the rules given in (.+)/,
   'reprocess', 'TARGET', 'RULE'],
  [qr/resolve (.+) to an absolute URL, relative to (.+)/,
   'resolve', 'INPUT', 'BASE'],
  [qr/drop the attributes from the token, and act as described in the next entry; i.e. act as if this was a ("br" start tag token) with no attributes, rather than the end tag token that it actually is/,
   'reprocess', 'RULE'],
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
  } elsif ($COND =~ /^the current node is an? (\w+) element$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is not (?:then |)an? (\w+) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is the root (html) element$/ or
           $COND =~ /^the stack of open elements has only one node on it$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => 'html'}];
  } elsif ($COND =~ /^the current node is not the root (html) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the current node is no longer an? (\w+) element$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the node immediately before it in the stack of open elements is an optgroup element$/) {
    $cond = ['oe[-2]', 'is', {ns => 'HTML', name => 'optgroup'}];
  } elsif ($COND =~ /^the current node is not an HTML element with the same tag name as (?:that of |)the token$/) {
    $cond = ['oe[-1]', 'is not', {ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the current node is an HTML element whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6"$/) {
    $cond = ['oe[-1]', 'is', {ns => 'HTML', name => [qw(h1 h2 h3 h4 h5 h6)]}];
  } elsif ($COND =~ /^the adjusted current node is an element in the (SVG|MathML) namespace$/) {
    $cond = ['adjusted current node', 'is', {ns => $1}];
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
  } elsif ($COND =~ /^node is an? (\w+) element$/) {
    $cond = ['node', 'is', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^node is in the special category$/) {
    $cond = ['node', 'is', {category => 'special'}];
  } elsif ($COND =~ /^node is in the special category, but is not an address, div, or p element$/) {
    $cond = ['node', 'is', {category => 'special', except => ['address', 'div', 'p']}];
  } elsif ($COND =~ /^the stack of open elements does not have an? (\w+) element$/) {
    $cond = ['oe', 'not in scope', {scope => 'all', ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^there is an? (\w+) element on the stack of open elements$/) {
    $cond = ['oe', 'in scope', {scope => 'all', ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^there is no (\w+) element on the stack of open elements$/) {
    $cond = ['oe', 'not in scope', {scope => 'all', ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements has an? (\w+) element in scope$/) {
    $cond = ['oe', 'in scope', {scope => 'scope', ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? (\w+) element in scope$/) {
    $cond = ['oe', 'not in scope', {scope => 'scope', ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements has an? (\w+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'in scope', {scope => $2, ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? (\w+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', {scope => $2, ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^the stack of open elements does not have an? (\w+) or (\w+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', {scope => $3, ns => 'HTML', name => [$1, $2]}];
  } elsif ($COND =~ /^the stack of open elements does not have an? (\w+), (\w+), or (\w+) element in ([\w ]+) scope$/) {
    $cond = ['oe', 'not in scope', {scope => $4, ns => 'HTML', name => [$1, $2, $3]}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in scope that is an HTML element with the same tag name as that of the token$/) {
    $cond = ['oe', 'in scope', {scope => 'scope', ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in ([\w ]+) scope that is an HTML element with the same tag name as (?:that of |)the token$/) {
    $cond = ['oe', 'in scope', {scope => $1, ns => 'HTML', same_tag_name_as_token => 1}];
  } elsif ($COND =~ /^the stack of open elements does not have an element in scope that is an HTML element and whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6"$/) {
    $cond = ['oe', 'not in scope', {scope => 'scope', ns => 'HTML', name => [qw(h1 h2 h3 h4 h5 h6)]}];
  } elsif ($COND =~ /^there is a node in the stack of open elements that is not either ((?:an?|the) \w+ element(?:, (?:or |)(?:an?|the) \w+ element)+)$/) {
    my @s;
    my $s = $1;
    push @s, $1 while $s =~ /(?:an?|the) (\w+) element/g;
    $cond = ['oe', 'in scope not', {ns => 'HTML', name => \@s}];
  } elsif ($COND =~ /^node is null or if the stack of open elements does not have node in scope$/) {
    $cond = ['or',
      ['node', 'is null'],
      ['oe', 'not in scope', 'node'],
    ];
  } elsif ($COND =~ /^there is no template element on the stack of open elements and the form element pointer is not null$/) {
    $cond = ['and',
      ['oe', 'not in scope', {scope => 'all', ns => 'HTML', name => 'template'}],
      ['form element pointer', 'is not null'],
    ];
  } elsif ($COND =~ /^node is the topmost element in the stack of open elements$/) {
    $cond = ['node', 'is', {ns => 'HTML', name => 'html'}];
  } elsif ($COND =~ /^the form element pointer is not null$/) {
    $cond = ['form element pointer', 'is not null'];
  } elsif ($COND =~ /^the token has its self-closing flag set$/) {
    $cond = ['token', 'has', 'self-closing flag'];
  } elsif ($COND =~ /^the list of active formatting elements contains an? (\w+) element between the end of the list and the last marker on the list \(or the start of the list if there is no marker on the list\)$/) {
    $cond = ['afe', 'in scope', {ns => 'HTML', name => $1}];
  } elsif ($COND =~ /^any of the tokens in the pending table character tokens list are character tokens that are not space characters$/) {
    $cond = ['pending table character tokens list', 'has non-space'];
  } elsif ($COND =~ /^the stack of template insertion modes is not empty$/) {
    $cond = ['stack of template insertion modes', 'is not empty'];
  } elsif ($COND =~ /^the next token is a U\+000A LINE FEED \(LF\) character token$/) {
    $cond = ['NEXT_IS_LF_TOKEN'];
  } elsif ($COND =~ /^the document is not an iframe srcdoc document$/) {
    $cond = ['iframe srcdoc document'];
  } elsif ($COND =~ /^the parser was originally created (?:for|as part of) the HTML fragment parsing algorithm$/) {
    $cond = ['fragment'];
  } elsif ($COND =~ /^the Document is being loaded as part of navigation of a browsing context$/) {
    $cond = ['navigate'];
  } elsif ($COND =~ /^the Document is not set to quirks mode$/) {
    $cond = ['quirks'];
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
  } elsif ($COND =~ /^the stack of script settings objects is empty$/) {
    $cond = ['stack of script settings objects', 'is empty'];
  }

  #warn $COND if not defined $cond;
  return $cond;
} # parse_cond

sub process_actions ($);
sub process_actions ($) {
  my $acts = shift;
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

      if ($act->{actions}) {
        $act->{actions} = process_actions $act->{actions};
      }
      push @$new_acts, $act;
    }
  }

  for my $act (@$new_acts) {
    if (defined $act->{IM}) {
      if ($act->{IM} =~ /^"([^"]+)"$/) {
        $act->{im} = ['im', $1];
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
        } elsif ($act->{ITEM} =~ /^(?:the current node(?: \([^()]+\)|)|elements|that \w+ element|that node|an element)$/) {
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
          warn $act->{VALUE};
        }
      } elsif ($act->{TARGET} =~ /^the (\w+) attribute on the resulting form element$/ and
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
        warn $act->{TARGET};
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
  }

  return $new_acts;
} # process_actions

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions} or next;
    $Data->{ims}->{$im}->{conds}->{$cond}->{actions} = process_actions $acts;
  }
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds} or {}}) {
    my $acts = $Data->{ims}->{$im}->{conds}->{$cond}->{actions} or next;
#    if (@$acts and $acts->[-1]->{type} eq 'SAME-AS-ELSE') {
#      pop @$acts;
#      push @$acts, @{$Data->{ims}->{$im}->{conds}->{ELSE}->{actions}};
#    }
  }
}

print perl2json_bytes_for_record $Data;
