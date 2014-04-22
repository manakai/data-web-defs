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

my $state_name;
my @node = @{$doc->body->child_nodes};
while (@node) {
  my $node = shift @node;
  if ($node->node_type == $node->ELEMENT_NODE) {
    my $ln = $node->local_name;
    if ($ln =~ /^h[1-6]$/ or $ln eq 'dt') {
      my $tc = _n $node->text_content;
      if ($tc =~ /^[0-9.]+\s+(.+state)\s*$/) {
        $state_name = _n $1;
        $state_name =~ s/^([A-Z])(?=[a-z0-9_.\s-])/lc $1/e;
        $Data->{states}->{$state_name} ||= {};
      } elsif ($tc =~ /^(.+state)\s*$/) { # xml5
        $state_name = _n $1;
        $state_name =~ s/^([A-Z])(?=[a-z0-9_.\s-])/lc $1/e;
        $Data->{states}->{$state_name} ||= {};
      } else {
        undef $state_name;
      }
    } elsif ($ln eq 'dl') {
      if (defined $state_name and $node->class_list->contains ('switch')) {
        my $switch_conds = [];
        my $was_dd;
        for my $n (@{$node->children}) {
          my $ln = $n->local_name;
          if ($ln eq 'dt') {
            my $cond = _n $n->text_content;
            if ($cond eq 'EOF') {
              #
            } elsif ($cond eq 'Anything else') {
              $cond = 'ELSE';
            } elsif ($cond eq 'Uppercase ASCII letter') {
              $cond = 'UPPER';
            } elsif ($cond eq 'Lowercase ASCII letter') {
              $cond = 'LOWER';
            } elsif ($cond =~ /^U\+([0-9A-F]+)\s+[0-9A-Z-\s]+(?:\([^()\s]+\)|)$/) {
              $cond = 'CHAR:' . $1;
            } elsif ($cond =~ /^u?U\+([0-9A-F]+)(?:\s+\([^()+]\)|):?\s*$/) { # xml5
              $cond = 'CHAR:' . $1;
            } else {
              $cond = 'MISC:' . $cond;
            }
            $Data->{states}->{$state_name}->{conds}->{$cond} ||= {};
            $switch_conds = [] if $was_dd;
            push @$switch_conds, $cond;
            $was_dd = 0;
          } elsif ($ln eq 'dd') {
            my $action = _n $n->text_content;
            my @action;
            while (1) {
              if ($action =~ s/^Parse error\.\s*// or
                  $action =~ s/^Otherwise, this is a parse error\.\s*//) {
                push @action, {type => 'error'};
              } elsif ($action =~ s/^(?:S|s|Finally, s|Then s)witch to the ([A-Za-z0-9 ._()-]+ state)(?:\.\s*|\s*$)//) {
                push @action, {type => 'switch', state => $1};
              } elsif ($action =~ s/^Switch to the ([A-Za-z0-9 ._()-]+ state), with the additional allowed character being U\+([0-9A-F]+) [A-Z0-9 _-]+ \([^()]+\)\.\s*//) {
                push @action, {type => 'switch', state => $1,
                               allowed_char => chr hex $2};
              } elsif ($action =~ s/^If the temporary buffer is the string "script", then switch to the ([A-Za-z0-9 ._()-]+ state)\. Otherwise, switch to the ([A-Za-z0-9 ._()-]+ state)\.\s*//) {
                push @action, {type => 'switch-by-temp',
                               state => $2,
                               script_state => $1};
              } elsif ($action =~ s/^Emit the token\.\s*// or
                       $action =~ s/^Emit (?:the current|that|the) (?:tag|DOCTYPE|comment) token(?:\.\s*| and then )// or
                       $action =~ s/^Emit the current token and then //) { # xml5
                push @action, {type => 'emit'};
              } elsif ($action =~ s/^Emit the current (?:tag |)token as (start tag token|empty tag token|short end tag token)(?:\.\s*| and then )//) { # xml5
                push @action, {type => 'emit-as', token => $1};
              } elsif ($action =~ s/^Emit a short end tag token and then //) { # xml5
                push @action, {type => 'emit', token => 'short end tag token'};
              } elsif ($action =~ s/^[Ee]mit the (?:current |)input character as (?:a |)character token\.\s*//) {
                push @action, {type => 'emit-char'};
              } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+|\([^()]+\)) character(?: token|)\.\s*//) {
                push @action, {type => 'emit-char', value => chr hex $1};
              } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+|\([^()]+\)) character token,?(?: and|) (a|the) /Emit $2 /) {
                push @action, {type => 'emit-char', value => chr hex $1};
              } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) \([^()]+\) character as character token and also //) { # xml5
                push @action, {type => 'emit-char', value => chr hex $1};
              } elsif ($action =~ s/^Emit two U\+([0-9A-F]+) \([^()]+\) characters as character tokens and also //) { # xml5
                push @action, {type => 'emit-char', value => (chr hex $1) . (chr hex $1)};
              } elsif ($action =~ s/^Emit a character token for each of the characters in the temporary buffer \(in the order they were added to the buffer\)\.\s*//) {
                push @action, {type => 'emit-temp'};
              } elsif ($action =~ s/^Emit an end-of-file token\.\s*//) {
                push @action, {type => 'emit-eof'};
              } elsif ($action =~ s/^Reconsume the (?:current input |EOF |)character\.\s*//) {
                push @action, {type => 'reconsume'};
              } elsif ($action =~ s/^[Rr](?:eprocess|econsume) the (?:current |)input character in the ([A-Za-z0-9 ._()-]+ state)\.\s*//) { # xml5
                push @action, {type => 'switch', state => $1};
                push @action, {type => 'reconsume'};
              } elsif ($action =~ s/^Append the current input character to the (?:current |)(?:tag|DOCTYPE|comment) token's (tag name|name|public identifier|system identifier|data)\.\s*//) {
                push @action, {type => 'append', field => $1};
              } elsif ($action =~ s/^Append the current (?:input |)character to the tag name and //) { # xml5
                push @action, {type => 'append', field => 'tag name'};
              } elsif ($action =~ s/^Append the current (?:input |)character to the (?:comment|pi's) data(?:\.\s*| and )//) { # xml5
                push @action, {type => 'append', field => 'data'};
              } elsif ($action =~ s/^Append the current input character to the name of the entity\.\s*//) { # xml5
                push @action, {type => 'append', field => 'name'};
              } elsif ($action =~ s/^Append the lowercase version of the current input character \(add 0x0020 to the character's code point\) to the current (?:tag|DOCTYPE) token's (tag name|name)\.\s*//) {
                push @action, {type => 'append', field => $1,
                               offset => 0x0020};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the current DOCTYPE token's (name|public identifier|system identifier)\.\s*//) {
                push @action, {type => 'append', field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Append two U\+002D (?:HYPHEN-MINUS characters \(-\)|\(-\) characters),?(?: and|) ([^.]+ to the comment token's data\.)\s*/Append $1/) {
                push @action, {type => 'append', field => 'data',
                               value => '--'};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+ character \([^()]+\)|\([^()]+\)),?(?: and|) ([^.]+ to the comment token's data\.)\s*/Append $2/) {
                push @action, {type => 'append', field => 'data',
                               value => chr hex $1};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character (?:\([^()]+\) |)to the (?:current tag|comment) token's (tag name|data)\.\s*//) {
                push @action, {type => 'append', field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Append the (?:current |)input character to the current attribute's (name|value)(?:\.\s*| and then )//) {
                push @action, {type => 'append-to-attr', field => $1};
              } elsif ($action =~ s/^Append the lowercase version of the current input character \(add 0x0020 to the character's code point\) to the current attribute's name\.\s*//) {
                push @action, {type => 'append-to-attr', field => 'name',
                               offset => 0x0020};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the current attribute's (name|value)\.\s*//) {
                push @action, {type => 'append-to-attr', field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Append the current input character to the temporary buffer\.\s*//) {
                push @action, {type => 'append-to-temp'};
              } elsif ($action =~ s/^Append the lowercase version of the current input character \(add 0x0020 to the character's code point\) to the temporary buffer\.\s*//) {
                push @action, {type => 'append-to-temp', offset => 0x0020};
              } elsif ($action =~ s/^Append the current input character to the current entity token's value\.\s*//) { # xml5
                push @action, {type => 'append-to-entity', field => 'value'};
              } elsif ($action =~ s/^Set the temporary buffer to the empty string\.\s*//) {
                push @action, {type => 'set-empty-to-temp'};
              } elsif ($action =~ s/^Create (?:a new|an) ((?:start tag|end tag|tag|DOCTYPE|processing instruction) token)(?:\.\s*|,? and |, )//) {
                push @action, {type => 'create', token => $1};
              } elsif ($action =~ s/^Create an entity token with the name set to the current input character and the value set to the empty string\.\s*//) { # xml5
                push @action, {type => 'create', token => 'entity token'};
                push @action, {type => 'set', field => 'name'};
                push @action, {type => 'set-empty', field => 'value'};
              } elsif ($action =~ s/^Start a new attribute in the current tag token\.\s*//) {
                push @action, {type => 'create-attr'};
              } elsif ($action =~ s/^[Ss]et (?:its|the token's) (tag name|name) to the (?:current |)input character(?:\.\s*|, then )//) {
                push @action, {type => 'set', field => $1};
              } elsif ($action =~ s/^Set target to the current input character and data to the empty string\.\s*//) { # xml5
                push @action, {type => 'set', field => 'target'};
                push @action, {type => 'set-empty', field => 'data'};
              } elsif ($action =~ s/^[Ss]et (?:its|the token's) (tag name|name) to the lowercase version of the current input character \(add 0x0020 to the character's code point\)(?:\.\s*|, then )//) {
                push @action, {type => 'set', field => $1, offset => 0x0020};
              } elsif ($action =~ s/^Set the token's (name) to a U\+([0-9A-F]+) [A-Z0-9 _-]+ character\.\s*//) {
                push @action, {type => 'set', field => $1,
                               value => chr hex $2};
              } elsif ($action =~ s/^Set the DOCTYPE token's (public identifier|system identifier) to the empty string \(not missing\), then //) {
                push @action, {type => 'set-empty', field => $1};
              } elsif ($action =~ s/^Set that attribute's name to the current input character,? and its value to the empty string(?:\.\s*| and then )//) {
                push @action, {type => 'set-to-attr', field => 'name'};
                push @action, {type => 'set-empty-to-attr', field => 'value'};
              } elsif ($action =~ s/^Set that attribute's name to the lowercase version of the current input character \(add 0x0020 to the character's code point\), and its value to the empty string\.\s*//) {
                push @action, {type => 'set-to-attr', field => 'name',
                               offset => 0x0020};
                push @action, {type => 'set-empty-to-attr', field => 'value'};
              } elsif ($action =~ s/^Set that attribute's name to a U\+([0-9A-F]+) [A-Z0-9 _-]+ character, and its value to the empty string\.\s*//) {
                push @action, {type => 'set-to-attr', field => 'name',
                               value => chr hex $1};
                push @action, {type => 'set-empty-to-attr', field => 'value'};
              } elsif ($action =~ s/^Append an entity\.\s*//) { # xml5
                push @action, {type => 'append-entity'};
              } elsif ($action =~ s/^Set the self-closing flag of the current tag token\.\s*//) {
                push @action, {type => 'set-flag', field => 'self-closing flag'};
              } elsif ($action =~ s/^Set (?:the DOCTYPE token's|its) force-quirks flag to on\.\s*//) {
                push @action, {type => 'set-flag', field => 'force-quirks flag'};
              } elsif ($action =~ s/^Set the entity flag to "([^"]+)"\.\s*//) { # xml5
                push @action, {type => 'set', field => 'entity flag', value => $1};
              } elsif ($action =~ s/^If the current end tag token is an appropriate end tag token, then switch to the ([A-Za-z0-9 ._-]+ state)\.\s*//) {
                push @action, {type => 'switch', state => $1,
                               if => 'appropriate end tag',
                               break => 1};
              } elsif ($action =~ s/^If the current end tag token is an appropriate end tag token, then switch to the ([A-Za-z0-9 ._()-]+ state) and emit the current tag token\.\s*//) {
                push @action, {type => 'switch-and-emit', state => $1,
                               if => 'appropriate end tag',
                               break => 1};
              } elsif ($action =~ s/^If the six characters starting from the current input character are an ASCII case-insensitive match for the word "PUBLIC", then consume those characters and switch to the after DOCTYPE public keyword state\.\s*//) {
                push @action, {type => 'consume-and-switch-if-keyword',
                               state => 'after DOCTYPE public keyword state',
                               keyword => 'PUBLIC',
                               break => 1};
              } elsif ($action =~ s/Otherwise, if the six characters starting from the current input character are an ASCII case-insensitive match for the word "SYSTEM", then consume those characters and switch to the after DOCTYPE system keyword state\.\s*//) {
                push @action, {type => 'consume-and-switch-if-keyword',
                               state => 'after DOCTYPE system keyword state',
                               keyword => 'SYSTEM',
                               break => 1};
              } elsif ($action =~ s/^(?:T|Otherwise, t)reat it as per the "anything else" entry below\.\s*//) {
                push @action, {type => 'SAME-AS-ELSE'};
              } elsif ($action =~ s/^Ignore the character\.\s*//) {
                #
              } elsif ($action =~ s/^\(Don't[^()]+\)\s*// or
                       $action =~ s/^\(This does not [^()]+\)\s*//) {
                #
              } elsif ($action =~ s/^[Ss]tay in (?:the current|this) state\.\s*//) { # xml5
                #
              } elsif ($action =~ s/^([^.]+\.+)\s*//) {
                push @action, {type => 'misc', desc => $1};
              } else {
                last;
              }
            }
            push @action, {type => 'misc', desc => $action} if length $action;
            if ('CHAR:0009 CHAR:000A CHAR:000C CHAR:0020' eq join ' ', @$switch_conds) {
              delete $Data->{states}->{$state_name}->{conds}->{$_}
                  for @$switch_conds;
              $switch_conds = ['WS:HTML'];
            } elsif ('CHAR:0009 CHAR:000A CHAR:0020' eq join ' ', @$switch_conds) {
              delete $Data->{states}->{$state_name}->{conds}->{$_}
                  for @$switch_conds;
              $switch_conds = ['WS:XML'];
            }
            push @{$Data->{states}->{$state_name}->{conds}->{$_}->{actions} ||= []}, @action
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

for my $state (keys %{$Data->{states}}) {
  for my $cond (keys %{$Data->{states}->{$state}->{conds} or {}}) {
    my $acts = $Data->{states}->{$state}->{conds}->{$cond}->{actions} or next;
    if (@$acts and $acts->[-1]->{type} eq 'SAME-AS-ELSE') {
      pop @$acts;
      push @$acts, @{$Data->{states}->{$state}->{conds}->{ELSE}->{actions}};
    }

    if (@$acts) {
      my $new_acts = [];
      push @$new_acts, shift @$acts;
      for (@$acts) {
        if ({
              'emit-char' => 1,
              'append' => 1,
            }->{$_->{type}} and
            $new_acts->[-1]->{type} eq $_->{type} and
            ((not defined $new_acts->[-1]->{field} and
              not defined $_->{field}) or
             (defined $new_acts->[-1]->{field} and
              defined $_->{field} and
              $new_acts->[-1]->{field} eq $_->{field})) and
            defined $new_acts->[-1]->{value} and
            defined $_->{value} and
            not defined $new_acts->[-1]->{if} and
            not defined $new_acts->[-1]->{break} and
            not defined $_->{if} and
            not defined $_->{break}) {
          $new_acts->[-1]->{value} .= $_->{value};
        } else {
          push @$new_acts, {%$_};
        }
      }
      @$acts = @$new_acts;
    }
  }
}

print perl2json_bytes_for_record $Data;
