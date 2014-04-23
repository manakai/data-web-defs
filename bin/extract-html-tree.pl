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

sub parse_step ($);
sub parse_step ($) {
  my $tc = shift;
  my @action;

  $tc =~ s/\s*\(fragment case\)\s*$//;

  while (length $tc) {
    $tc =~ s/^\s+//;
    $tc =~ s/^Finally, //;
    $tc =~ s/^then //;
    $tc = ucfirst $tc;
    if ($tc =~ s/^Parse error\.// or
        $tc =~ s/^This is a parse error(?:\.|;)//) {
      push @action, {type => 'error'};
    } elsif ($tc =~ s/^If //) {
      if ($tc =~ s/^the parser was originally created as part of the HTML fragment parsing algorithm, //) {
        push @action, {type => 'if',
                       cond => 'fragment',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of open elements has an? ([a-z0-9_.-]+) element in ([a-z ]+ scope), then //) {
        push @action, {type => 'if',
                       cond => 'in-scope',
                       elements => [$1],
                       scope => $2,
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of open elements does not have an? ([a-z0-9_.-]+) element in scope, //) {
        push @action, {type => 'if',
                       cond => 'not-in-scope',
                       elements => [$1],
                       scope => 'scope',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of open elements does not have an? ([a-z0-9_.-]+) element in ([a-z ]+ scope), then //) {
        push @action, {type => 'if',
                       cond => 'not-in-scope',
                       elements => [$1],
                       scope => $2,
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of open elements does not have an element in scope that is an HTML element and whose tag name is one of ("[^"]+"(?:(?:, or|,|or) "[^"]+")*), then //) {
        my $s = $1;
        my @s;
        push @s, $1 while $s =~ /"([^"]+)"/g;
        push @action, {type => 'if',
                       cond => 'not-in-scope',
                       elements => [sort { $a cmp $b } @s],
                       scope => 'scope',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^there is no ([a-z0-9_.-]+) element on the stack of open elements, then //) {
        push @action, {type => 'if',
                       cond => 'not-in-scope',
                       elements => [$1],
                       scope => 'stack',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^there is a node in the stack of open elements that is not either ((?:an?|the) [a-z0-9_.-]+ element(?:(?:, or|,| or) (?:an?|the) [a-z0-9_.-]+ element)*), then //) {
        my $s = $1;
        my @s;
        push @s, $1 while $s =~ /an? ([a-z0-9_.-]+) element/g;
        push @action, {type => 'if',
                       cond => 'in-scope',
                       not_elements => [sort { $a cmp $b } @s],
                       scope => 'stack',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of open elements does not have an element in scope that is an HTML element and with the same tag name as that of the token, then //) {
        push @action, {type => 'if',
                       cond => 'in-scope',
                       same_tag_name => 1,
                       scope => 'stack',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the stack of template insertion modes is not empty, then //) {
        push @action, {type => 'if',
                       cond => 'template-ims-not-empty',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the Document is being loaded as part of navigation of a browsing context, then: //) {
        push @action, {type => 'if',
                       cond => 'in-navigate',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the current node is not an? ([a-z0-9_.-]+) element, then //) {
        push @action, {type => 'if',
                       cond => 'current-node',
                       elements => [$1],
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the current node is not an HTML element with the same tag name as that of the token, then //) {
        push @action, {type => 'if',
                       cond => 'current-node',
                       same_tag_name => 1,
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the list of active formatting elements contains an a element between the end of the list and the last marker on the list \(or the start of the list if there is no marker on the list\), then //) {
        push @action, {type => 'if',
                       cond => 'in-afe-scope',
                       actions => [parse_step $tc]};
      } elsif ($tc =~ s/^the frameset-ok flag is set to "not ok", //) {
        push @action, {type => 'if',
                       cond => 'frameset-not-ok',
                       actions => [parse_step $tc]};
      } else {
        push @action, {type => 'if',
                       cond => 'misc',
                       desc => $tc};
      }
      last;
    } elsif ($tc =~ s/^Otherwise:$//) {
      push @action, {type => 'OTHERWISE'};
    } elsif ($tc =~ s/^Otherwise, //) {
      push @action, {type => 'otherwise',
                     actions => [parse_step $tc]};
      last;
    } elsif ($tc =~ s/^Process the token using the rules for the "([^"]+)" insertion mode\.\s*//) {
      push @action, {type => 'USING', im => $1};
    } elsif ($tc =~ s/^(?:R|Then, r)eprocess the (?:current |)token\.\s*//) {
      push @action, {type => 'reprocess'};
    } elsif ($tc =~ s/^[Ss]witch the insertion mode to "([^"]+)"\.\s*//) {
      push @action, {type => 'switch', im => $1};
    } elsif ($tc =~ s/^[Ss]witch the insertion mode to "([^"]+)"(?: and|, then) reprocess the token\.\s*//) {
      push @action, {type => 'switch', im => $1};
      push @action, {type => 'reprocess'};
    } elsif ($tc =~ s/^Reset the insertion mode appropriately\.\s*//) {
      push @action, {type => 'reset-im'};
    } elsif ($tc =~ s/^Create an html element whose ownerDocument is the Document object\.//) {
      push @action, {type => 'create-html-element', name => 'html'};
    } elsif ($tc =~ s/^Create an element for the token in the HTML namespace, with the Document as the intended parent\.//) {
      push @action, {type => 'create-html-element'};
    } elsif ($tc =~ s/^Append it to the Document object\.//) {
      push @action, {type => 'append-to-document'};
    } elsif ($tc =~ s/^Insert the character\.// or
             $tc =~ s/^Insert the token's character\.\s*//) {
      push @action, {type => 'insert-char'};
                  } elsif ($tc =~ s/^Insert a U\+FFFD REPLACEMENT CHARACTER character\.\s*//) {
                    push @action, {type => 'insert-char',
                                   value => "\x{FFFD}"};
                  } elsif ($tc =~ s/^Insert a comment\.\s*//) {
                    push @action, {type => 'insert-comment'};
                  } elsif ($tc =~ s/^Insert a comment as the last child of the Document object\.\s*//) {
                    push @action, {type => 'insert-comment',
                                   position => 'document-last-child'};
                  } elsif ($tc =~ s/^Insert a comment as the last child of the first element in the stack of open elements \(the html element\)\.\s*//) {
                    push @action, {type => 'insert-comment',
                                   position => 'oe-first-last-child'};
                  } elsif ($tc =~ s/^Insert an HTML element for the token(?:\.|, then )//) {
                    push @action, {type => 'insert-html-element'};
                  } elsif ($tc =~ s/^Insert an HTML element for a "([^"]+)" start tag token with no attributes(?:\.|, then )//) {
                    push @action, {type => 'insert-html-element',
                                   name => $1};
                  } elsif ($tc =~ s/^Follow the generic raw text element parsing algorithm\.\s*//) {
                    push @action, {type => 'raw-text'};
                  } elsif ($tc =~ s/^Follow the generic PCDATA element parsing algorithm\.\s*//) {
                    push @action, {type => 'pcdata'};
                  } elsif ($tc =~ s/^Put this element in the stack of open elements\.//) {
                    push @action, {type => 'push-to-oe'};
                  } elsif ($tc =~ s/^Pop the current node (?:which \([^().]+\))?(?:off|from) the stack of open elements(?:; the new current node will be [^.]+)?\.\s*//) {
                    push @action, {type => 'pop-oe'};
                  } elsif ($tc =~ s/^Pop elements from the stack of open elements until an? ([a-z0-9_.-]+) element has been popped from the stack\.\s*//) {
                    push @action, {type => 'pop-oe', until => [$1]};
                  } elsif ($tc =~ s/^Pop elements from the stack of open elements until an HTML element with the same tag name as the token has been popped from the stack\.//) {
                    push @action, {type => 'pop-oe', until_same_tag_name => 1};
                  } elsif ($tc =~ s/^Pop elements from the stack of open elements until an HTML element whose tag name is one of ("[^"]+"(?:(?:, or|,|or) "[^"]+")*) has been popped from the stack\.//) {
        my $s = $1;
        my @s;
        push @s, $1 while $s =~ /"([^"]+)"/g;
        push @action, {type => 'pop-oe', until => [sort { $a cmp $b } @s]};
      } elsif ($tc =~ s/^Acknowledge the token's self-closing flag, if it is set\.\s*//) {
        push @action, {type => 'ack-self-closing'};
      } elsif ($tc =~ s/^Generate implied end tags\.\s*//) {
        push @action, {type => 'implied-end-tags'};
      } elsif ($tc =~ s/^Generate implied end tags, except for ([a-z0-9_.-]+) elements\.//) {
        push @action, {type => 'implied-end-tags',
                       except => [$1]};
      } elsif ($tc =~ s/^Generate implied end tags, except for HTML elements with the same tag name as the token\.//) {
        push @action, {type => 'implied-end-tags',
                       except_same_tag_name => 1};
      } elsif ($tc =~ s/^Close a p element\.\s*//) {
                    push @action, {type => 'close-p'};
                  } elsif ($tc =~ s/^Clear the stack back to a ([a-z ]+ context)\. \(See below\.\)\s*//) {
                    push @action, {type => 'pop-oe', context => $1};
                  } elsif ($tc =~ s/^Run the adoption agency algorithm for the token's tag name\.\s*//) {
                    push @action, {type => 'aaa'};
                  } elsif ($tc =~ s/^Reconstruct the active formatting elements, if any\.\s*//) {
                    push @action, {type => 'reconstruct-afe'};
                  } elsif ($tc =~ s/^Insert a marker at the end of the list of active formatting elements\.\s*//) {
                    push @action, {type => 'push-marker-to-afe'};
                  } elsif ($tc =~ s/^Clear the list of active formatting elements up to the last marker\.\s*//) {
                    push @action, {type => 'clear-afe-upto-marker'};
                  } elsif ($tc =~ s/^Push the node pointed to by the head element pointer onto the stack of open elements\.\s*//) {
                    push @action, {type => 'push-head-element-to-oe'};
                  } elsif ($tc =~ s/^Remove the node pointed to by the head element pointer from the stack of open elements\.\s*(?:\([^()]+\)|)\s*//) {
                    push @action, {type => 'remove-head-element-from-oe'};
                  } elsif ($tc =~ s/^Set the head element pointer to the newly created head element\.\s*//) {
                    push @action, {type => 'set-head-element'};
                  } elsif ($tc =~ s/^Set the frameset-ok flag to "not ok"\.\s*//) {
                    push @action, {type => 'frameset-not-ok'};
                  } else {
                    my $matched;
                    for (@$patterns) {
                      if ($tc =~ s/^\Q$_->[0]\E//) {
                        push @action, {type => $_->[1]};
                        $matched = 1;
                        last;
                      }
                    }

                    if ($matched) {
                      #
                    } elsif ($tc =~ s/^Act as described in the "anything else" entry below\.\s*//) {
                    push @action, {type => 'SAME-AS-ELSE'};
                  } elsif ($tc =~ s/^Take a deep breath, then act as described in the "any other end tag" entry below\.\s*//) {
                    push @action, {type => 'breath'};
                    push @action, {type => 'SAME-AS-END-ELSE'};
                  } elsif ($tc =~ s/^Run (?:these|the following) (?:sub|)steps:\s*//) {
                    push @action, {type => 'RUN-NEXT'};
                  } elsif ($tc =~ s/^Ignore the token\.\s*//) {
                    #
                  } elsif ($tc =~ s/^([^.]+\.)//) {
                    push @action, {type => 'misc', desc => $1};
                  } elsif ($tc =~ /\S/) {
                    push @action, {type => 'misc', desc => $tc};
last;
                  }
                  }
  }
  return @action;
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
