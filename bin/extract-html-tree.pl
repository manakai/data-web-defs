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
    } elsif ($_->{DESC} =~ /^($SENTENCE?) until ($SENTENCE)$/o) {
      $_->{type} = 'UNTIL';
      $_->{COND} = $2;
      $_->{actions} = [parse_step $1];
      delete $_->{DESC};
      $_;
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
  [qr/push (.+) onto (.+)/, 'push', 'ITEM', 'LIST'],
  [qr/remove (.+) from (.+)/, 'remove', 'ITEM', 'LIST'],
  [qr/pop all the nodes (?:from (.+?), |)from (the current node) up to(.+)/,
   'pop', 'LIST', 'FROM-ITEM', 'TO-ITEM'],
  [qr/pop (.+) (?:off|from) (.+)/, 'pop', 'ITEM', 'LIST'],
  [qr/put (.+) in (.+)/, 'put', 'ITEM', 'LIST'],
  [qr/set (.+) to (.+)/, 'set', 'TARGET', 'VALUE'],
  [qr/let (.+) (?:be|have) (.+)/, 'set', 'TARGET', 'VALUE'],
  [qr/mark (.+) as (.+)/, 'mark', 'TARGET', 'VALUE'],
  [qr/unset (.+)/, 'unset', 'TARGET'],
  [qr/append (.+) to (.+)/, 'append', 'ITEM', 'LIST'],
  [qr/initialise (.+) to be (.+)/, 'set', 'TARGET', 'VALUE'],
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
  [qr/switch the tokenizer to the (.+) state/,
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

      if ($act->{actions}) {
        $act->{actions} = process_actions $act->{actions};
      }
      push @$new_acts, $act;
    }
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
