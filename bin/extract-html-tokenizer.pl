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
$parser->parse_byte_string ('utf-8', $spec_path->slurp => $doc);

my $Data = {};

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/\A //;
  $s =~ s/ \z//;
  return $s;
} # _n

$Data->{char_sets}->{'WS:HTML'}->{$_} = 1
    for 0x0009, 0x000A, 0x000C, 0x0020;
$Data->{char_sets}->{'WS:XML'}->{$_} = 1
    for 0x0009, 0x000A, 0x0020;
$Data->{char_sets}->{'LETTER'}->{$_} = 1,
$Data->{char_sets}->{'UPPER'}->{$_} = 1
    for (ord 'A')..(ord 'Z');
$Data->{char_sets}->{'LETTER'}->{$_} = 1,
$Data->{char_sets}->{'LOWER'}->{$_} = 1
    for (ord 'a')..(ord 'z');
$Data->{char_sets}->{'DIGIT'}->{$_} = 1
    for (ord '0')..(ord '9');
$Data->{char_sets}->{'HEXDIGIT'}->{$_} = 1
    for (ord '0')..(ord '9'), (ord 'A')..(ord 'F'), (ord 'a')..(ord 'f');

my $state_name;
my $PreserveStateBeforeSwitching = {};

my $LoopCount = {};
sub check_loop ($) {
  my $key = $_[0];
  $LoopCount->{$key}++;
  if ($LoopCount->{$key} > 100000) {
    require Carp;
    die "check_loop: $key > 100000", Carp::longmess ();
  }
  if ($LoopCount->{$key} > 100000-10) {
    require Carp;
    warn "check_loop: $key > 100000", Carp::longmess ();
  }
} # check_loop

sub parse_action ($) {
  my $action = shift;
  my @action;
  while (1) {
    check_loop 'parse_action';
    $action =~ s/^\s+//;
    if ($action =~ s/^Otherwise, this is a parse error. Switch to the ((?:DOCTYPE |)bogus comment state). The next character that is consumed, if any, is the first character that will be in the comment\.//) {
      push @action,
          {type => 'parse error'},
          {type => 'append-temp', field => 'data'},
          {type => 'switch', state => $1};
    } elsif ($action =~ s/^Parse error\.\s*// or
             $action =~ s/^Otherwise, this is a parse error\.\s*//) {
      push @action, {type => 'parse error'};
    } elsif ($action =~ s/^This is an? ([\w-]+) parse error\.\s*// or
             $action =~ s/^Otherwise, this is an? ([\w-]+) parse error\.\s*//) {
      push @action, {type => 'parse error',
                     code => $1};
    } elsif ($action =~ s/^Parse error \(offset=([0-9]+)\)\.$// or
             $action =~ s/^Otherwise, this is a parse error \(offset=([0-9]+)\)\.\s*//) {
      push @action, {type => 'parse error', index_offset => $1};
    } elsif ($action =~ s/^(?:S|s|Finally, s|Then s|Otherwise, s)witch to the ([A-Za-z0-9 ._()-]+? state)(?:\.\s*|\s*$)//) {
      push @action, {type => 'switch', state => $1};
    } elsif ($action =~ s/^Set the return state to the (.+? state)\.\s+Switch to the character reference state\.//) {
      if (index ($1, 'attribute') > -1) {
        push @action,
            {type => 'set-to-temp', value => '&'},
            {type => 'switch', state => "$1 - character reference state"};
      } else {
        push @action, {type => 'switch', state => "character reference in $1"};
      }
    } elsif ($action =~ s/^Reconsume in the ([A-Za-z0-9 ._()-]+? state)\s*\.//) {
      push @action, {type => 'switch', state => $1}, {type => 'reconsume'};
    } elsif ($action =~ s/^Switch to the ((?:DOCTYPE |)bogus comment state) \(don't consume anything in the current state\)\.//) {
      push @action,
          {type => 'switch', state => $1},
          {type => 'reconsume'};
    } elsif ($action =~ s/^(?:S|s|Finally, s|Then s|Otherwise, s)witch to the ([A-Za-z0-9 ._()-]+? state) with initial data "([^"]+)"(?:\.\s*|\s*$)//) {
      push @action, {type => 'switch', state => $1, INITIAL_DATA => $2};
    } elsif ($action =~ s/^\QSwitch to the character reference in attribute value state, with the additional allowed character being U+0022 QUOTATION MARK (").\E//) {
      push @action,
          {type => 'set-to-temp', value => '&'},
          {type => 'switch', state => 'attribute value (double-quoted) state - character reference state'};
    } elsif ($action =~ s/^\QSwitch to the character reference in attribute value state, with the additional allowed character being U+0027 APOSTROPHE (').\E//) {
      push @action, 
          {type => 'set-to-temp', value => '&'},
          {type => 'switch', state => 'attribute value (single-quoted) state - character reference state'};
    } elsif ($action =~ s/^\QSwitch to the character reference in attribute value state, with the additional allowed character being U+003E GREATER-THAN SIGN (>).\E//) {
      push @action, 
          {type => 'set-to-temp', value => '&'},
          {type => 'switch', state => 'attribute value (unquoted) state - character reference state'};
    } elsif ($action =~ s/^If the temporary buffer is the string "script", then switch to the ([A-Za-z0-9 ._()-]+? state)\. Otherwise, switch to the ([A-Za-z0-9 ._()-]+? state)\.\s*//) {
      push @action, {type => 'switch-by-temp',
                     state => $2,
                     script_state => $1};

    } elsif ($action =~ s/^Emit the token\.\s*// or
             $action =~ s/^Emit the current token\.\s*// or
             $action =~ s/^Emit the comment\.// or
             $action =~ s/^Emit (?:the current|that|the) (?:tag |DOCTYPE |comment |)token(?:\.\s*| and then )//) {
      push @action, {type => 'emit'};
    } elsif ($action =~ s/^Emit the current (?:tag |)token as (start tag token|empty tag token|short end tag token)(?:\.\s*| and then )//) { # xml5
      push @action, {type => 'emit-as', token => $1};
    } elsif ($action =~ s/^Emit a short end tag token and then //) { # xml5
      push @action, {type => 'emit', token => 'short end tag token'};
    } elsif ($action =~ s/^[Ee]mit the (?:current |)input character as (?:a |)character token\.\s*//) {
      push @action, {type => 'emit-char'};
    } elsif ($action =~ s/^[Ee]mit the (?:current |)input character as (?:a |)character token \(offset=([0-9]+)\)\.\s*//) {
      push @action, {type => 'emit-char', index_offset => $1};
    } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+|)(\([^()]+\)|) character(?: token|)\.\s*//) {
      push @action, {type => 'emit-char', value => chr hex $1};
    } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+|)(\([^()]+\)|) character(?: token|) \(offset=([0-9]+)\)\.\s*//) {
      push @action, {type => 'emit-char', value => chr hex $1,
                     index_offset => $2};
    } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+|\([^()]+\)) character token,?(?: and|) (an?|the) /Emit $2 /) {
      push @action, {type => 'emit-char', value => chr hex $1};
    } elsif ($action =~ s/^Emit a U\+([0-9A-F]+) \([^()]+\) character as character token and also //) { # xml5
      push @action, {type => 'emit-char', value => chr hex $1};
    } elsif ($action =~ s/^Emit two U\+([0-9A-F]+) (?:\([^()]+\)|[A-Z0-9 ]+) character(?:s as character|) tokens(?: and also |\.)//) {
      push @action, {type => 'emit-char', value => (chr hex $1) . (chr hex $1)};
    } elsif ($action =~ s/^Emit a character token for each of the characters in the temporary buffer \(in the order they were added to the buffer\)\.\s*//) {
      push @action, {type => 'emit-temp'};
    } elsif ($action =~ s/^Emit an end-of-file token\.\s*//) {
      push @action, {type => 'emit-eof'};
    } elsif ($action =~ s/^Emit an end-of-DOCTYPE token\.\s*//) {
      push @action, {type => 'emit-end-of-DOCTYPE'};

              } elsif ($action =~ s/^Reconsume the (?:current input |EOF |)character\.\s*//) {
                push @action, {type => 'reconsume'};
              } elsif ($action =~ s/^[Rr](?:eprocess|econsume) the (?:current |)input character in the ([A-Za-z0-9 ._()-]+ state)\.\s*//) { # xml5
                push @action, {type => 'switch', state => $1};
                push @action, {type => 'reconsume'};
              } elsif ($action =~ s/^Append the current input character to the (?:current |)(?:tag |DOCTYPE |comment |)token's (tag name|name|public identifier|system identifier|notation name|data|target|value|content keyword)\.\s*//) {
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
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the temporary buffer\.\s*//) {
                push @action, {type => 'append-to-temp',
                               value => chr hex $1};
              } elsif ($action =~ s/^Append two U\+002D (?:HYPHEN-MINUS characters \(-\)|\(-\) characters) to the comment token's data\.\s*//) {
                push @action, {type => 'append', field => 'data',
                               value => '--'};
              } elsif ($action =~ s/^Append two U\+002D (?:HYPHEN-MINUS characters \(-\)|\(-\) characters),?(?: and|) ([^.]+ to the comment token's data\.)\s*/Append $1/) {
                push @action, {type => 'append', field => 'data',
                               value => '--'};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) (?:[A-Z0-9 _-]+ character \([^()]+\)|\([^()]+\)),?(?: and|) ([^.]+ to the comment token's data\.)\s*/Append $2/) {
                push @action, {type => 'append', field => 'data',
                               value => chr hex $1};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character (?:\([^()]+\) |)to the (?:current tag|current|comment) token's (tag name|name|data|target|value|public identifier|system identifier|notation name|content keyword)(?: \(offset=([0-9]+)\)|)\.\s*//) {
                push @action, {type => 'append', field => $2,
                               value => chr hex $1};
                $action[-1]->{index_offset} = $3 if defined $3;
              } elsif ($action =~ s/^Append the (?:current |)input character to the current attribute(?: definition|)'s (name|value|declared type|default type)(?:\.\s*| and then )//) {
                push @action, {type => 'append-to-attr', field => $1};
              } elsif ($action =~ s/^Append the lowercase version of the current input character \(add 0x0020 to the character's code point\) to the current attribute's name\.\s*//) {
                push @action, {type => 'append-to-attr', field => 'name',
                               offset => 0x0020};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the current attribute(?: definition|)'s (name|value|declared type|default type)\.\s*//) {
                push @action, {type => 'append-to-attr', field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Append the current input character to the temporary buffer\.\s*//) {
                push @action, {type => 'append-to-temp'};
              } elsif ($action =~ s/^Append the lowercase version of the current input character \(add 0x0020 to the character's code point\) to the temporary buffer\.\s*//) {
                push @action, {type => 'append-to-temp', offset => 0x0020};
              } elsif ($action =~ s/^Append the current input character to the current entity token's value\.\s*//) { # xml5
                push @action, {type => 'append-to-entity', field => 'value'};
              } elsif ($action =~ s/^Append the temporary buffer's value to the current token's (value)\.//) {
                push @action, {type => 'append-temp', field => $1};
              } elsif ($action =~ s/^Set the temporary buffer to the empty string\.\s*//) {
                push @action, {type => 'set-empty-to-temp'};
              } elsif ($action =~ s/^Set a U\+([0-9A-F]+) [A-Z0-9 _-]+ character (?:\([^()]+\) |)to the temporary buffer\.//) {
                push @action, {type => 'set-to-temp', value => chr hex $1};
              } elsif ($action =~ s/^Set the current input character to the temporary buffer\.//) {
                push @action, {type => 'set-to-temp'};
              } elsif ($action =~ s/^Create (?:a new|an) ((?:start tag|end tag|tag|DOCTYPE|processing instruction|ENTITY|NOTATION|parameter entity|ATTLIST|ELEMENT) token)(?:\.\s*|,? and |, )//) {
                push @action, {type => 'create', token => $1};
              } elsif ($action =~ s/^Create an entity token with the name set to the current input character and the value set to the empty string\.\s*//) { # xml5
                push @action, {type => 'create', token => 'entity token'};
                push @action, {type => 'set', field => 'name'};
                push @action, {type => 'set-empty', field => 'value'};
              } elsif ($action =~ s/^Start a new attribute in the current tag token\.\s*//) {
                push @action, {type => 'create-attr'};
              } elsif ($action =~ s/^Create an attribute definition\.//) {
                push @action, {type => 'create-attrdef'};
              } elsif ($action =~ s/^Append the attribute definition to the list of attribute definitions of the current token\.//) {
                push @action, {type => 'insert-attrdef'};
              } elsif ($action =~ s/^Create an allowed token and append it to the list of allowed tokens of the current attribute definition\.//) {
                push @action, {type => 'insert-allowed-token'};
              } elsif ($action =~ s/^Create a new content model group\.//) {
                push @action, {type => 'create-cmgroup'};
              } elsif ($action =~ s/^Set the current token's content model group to the content model group\.//) {
                push @action, {type => 'set-cmgroup',
                               field => 'content model group'};
              } elsif ($action =~ s/^Set the stack of the open content model groups to a stack that contains only the content model group\.//) {
                push @action, {type => 'push-cmgroup-as-only-item'};
              } elsif ($action =~ s/^Push the content model group to the stack of open content model groups\.//) {
                push @action, {type => 'push-cmgroup'};
              } elsif ($action =~ s/^Append the content model group to the current content model group\.//) {
                push @action, {type => 'append-cmgroup'};
              } elsif ($action =~ s/^Pop the current content model group off the stack of open content model groups\.//) {
                push @action, {type => 'pop-cmgroup'};
              } elsif ($action =~ s/^Create a content model element and append it to the current content model group\.//) {
                push @action, {type => 'insert-cmelement'};
              } elsif ($action =~ s/^Create a marked section whose status is INCLUDE and push it onto the stack of open marked sections\.//) {
                push @action, {type => 'insert-INCLUDE'};
              } elsif ($action =~ s/^Create a marked section whose status is IGNORE and push it onto the stack of open marked sections\.//) {
                push @action, {type => 'insert-IGNORE'};
    } elsif ($action =~ s/^[Cc]reate a comment token whose data is the empty string(?:\.|, and )//) {
      push @action,
          {type => 'create', token => 'comment token'},
          {type => 'set-empty', field => 'data'};
    } elsif ($action =~ s/^\QCreate a comment token whose data is the "[CDATA[" string.\E//) {
      push @action,
          {type => 'create', token => 'comment token'},
          {type => 'set-empty', field => 'data'},
          {type => 'append-temp', field => 'data'},
          {type => 'append', field => 'data'};
    } elsif ($action =~ s/^Create a comment token whose (data) is "([^"]+)"\.//) {
      push @action,
          {type => 'create', token => 'comment token', index_offset => 1},
          {type => 'set', field => $1, value => $2};

              } elsif ($action =~ s/^Pop the current marked section off the stack of open marked sections and reset the state\.//) {
                push @action, {type => 'pop-section'};
              } elsif ($action =~ s/^[Ss]et (?:its|the (?:current |)token's) (tag name|name|target|data|notation name|content keyword) to the (?:current |)input character(?:\.\s*|, then )//) {
                push @action, {type => 'set', field => $1};
              } elsif ($action =~ s/^[Ss]et the current token's (value) to the empty string\.//) {
                push @action, {type => 'set-empty', field => $1};
              } elsif ($action =~ s/^Set target to the current input character and data to the empty string\.\s*//) { # xml5
                push @action, {type => 'set', field => 'target'};
                push @action, {type => 'set-empty', field => 'data'};
              } elsif ($action =~ s/^[Ss]et (?:its|the token's) (tag name|name) to the lowercase version of the current input character \(add 0x0020 to the character's code point\)(?:\.\s*|, then )//) {
                push @action, {type => 'set', field => $1, offset => 0x0020};
              } elsif ($action =~ s/^Set (?:the token's|its|the current token's) (name|tag name|target|data|notation name) to a U\+([0-9A-F]+) [A-Z0-9 _-]+ (?:\([^()]+\) |)character\.\s*//) {
                push @action, {type => 'set', field => $1,
                               value => chr hex $2};
              } elsif ($action =~ s/^Set (?:the (?:current |)DOCTYPE token's|its) (public identifier|system identifier|tag name|name|target|data) to the empty string(?: \(offset=([0-9]+)\)|)(?: \(not missing\), then |\.)//) {
                push @action, {type => 'set-empty', field => $1};
                $action[-1]->{index_offset} = $2 if defined $2;
              } elsif ($action =~ s/^[Ss]et its (tag name) to the empty string\.//) {
                push @action, {type => 'set-empty', field => $1};
              } elsif ($action =~ s/^Set that attribute name and value to the empty string\.//) {
                push @action,
                    {type => 'set-empty-to-attr', field => 'name'},
                    {type => 'set-empty-to-attr', field => 'value'};
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
              } elsif ($action =~ s/^Set the current attribute definition's (name|value|declared type|default type) to a U\+([0-9A-F]+) [A-Z0-9 _-]+ character\.\s*//) {
                push @action, {type => 'set-to-attr', field => $1,
                               value => chr hex $2};
              } elsif ($action =~ s/^Set the current attribute definition's (name|value|declared type|default type) to the empty string\.//) {
                push @action, {type => 'set-empty-to-attr', field => $1};
              } elsif ($action =~ s/^Set the current attribute definition's (name|value|declared type|default type) to the current input character\.//) {
                push @action, {type => 'set-to-attr', field => $1};
              } elsif ($action =~ s/^Append the current input character to the current allowed token's (value)\.//) {
                push @action, {type => 'append-to-allowed-token',
                               field => $1};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the current allowed token's (value)\.\s*//) {
                push @action, {type => 'append-to-allowed-token',
                               field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Set the current allowed token's (value) to the current input character\.//) {
                push @action, {type => 'set-to-allowed-token',
                               field => $1};
              } elsif ($action =~ s/^Set the current allowed token's (value) to a U\+([0-9A-F]+) [A-Z0-9 _-]+ character\.\s*//) {
                push @action, {type => 'set-to-allowed-token',
                               field => $1,
                               value => chr hex $2};
              } elsif ($action =~ s/^Set the current content model group's (repetition) to the current input character\.//) {
                push @action, {type => 'set-to-cmgroup', field => $1};
              } elsif ($action =~ s/^Append the current input character as a content model separator to the current content model group\.//) {
                push @action, {type => 'append-separator-to-cmgroup'};
              } elsif ($action =~ s/^Set the current content model element's (repetition) to the current input character\.//) {
                push @action, {type => 'set-to-cmelement', field => $1};
              } elsif ($action =~ s/^Set the current content model element's (name) to the current input character\.//) {
                push @action, {type => 'set-to-cmelement',
                               field => $1};
              } elsif ($action =~ s/^Set the current content model element's (name) to a U\+([0-9A-F]+) [A-Z0-9 _-]+ character\.\s*//) {
                push @action, {type => 'set-to-cmelement',
                               field => $1,
                               value => chr hex $2};
              } elsif ($action =~ s/^Append the current input character to the current content model element's (name)\.//) {
                push @action, {type => 'append-to-cmelement',
                               field => $1};
              } elsif ($action =~ s/^Append a U\+([0-9A-F]+) [A-Z0-9 _-]+ character to the current content model element's (name)\.\s*//) {
                push @action, {type => 'append-to-cmelement',
                               field => $2,
                               value => chr hex $1};
              } elsif ($action =~ s/^Append an entity\.\s*//) { # xml5
                push @action, {type => 'append-entity'};
              } elsif ($action =~ s/^Set the (.+? flag) of the current (?:tag |)token\.\s*//) {
                push @action, {type => 'set-flag', field => $1};
              } elsif ($action =~ s/^Set the DTD mode to (.+?)\.\s*//) {
                push @action, {type => 'set-DTD-mode', value => $1};
              } elsif ($action =~ s/^Set (?:the (?:current |)DOCTYPE token's|its) force-quirks flag to on\.\s*//) {
                push @action, {type => 'set-flag', field => 'force-quirks flag'};
              } elsif ($action =~ s/^Set the entity flag to "([^"]+)"\.\s*//) { # xml5
                push @action, {type => 'set', field => 'entity flag', value => $1};
              } elsif ($action =~ s/^If the current end tag token is an appropriate end tag token, then switch to the ([A-Za-z0-9 ._-]+? state)\.\s*//) {
                push @action, {type => 'switch', state => $1,
                               if => 'appropriate end tag',
                               break => 1};
              } elsif ($action =~ s/^If the current end tag token is an appropriate end tag token, then switch to the ([A-Za-z0-9 ._()-]+? state) and emit the current tag token\.\s*//) {
                push @action, {type => 'switch-and-emit', state => $1,
                               if => 'appropriate end tag',
                               break => 1};
              } elsif ($action =~ s/^If the six characters starting from the current input character are an? (ASCII case-insensitive|case-sensitive) match for the word "PUBLIC", then (this is a parse error; |)consume those characters and switch to the after DOCTYPE public keyword state\.\s*//) {
                push @action, {type => 'IF-KEYWORD',
                               keyword => 'PUBLIC',
                               case_insensitive => ($1 eq 'ASCII case-insensitive' ? ($2 ? 'error' : 1) : 0),
                               value => [
                                 {type => 'switch',
                                  'state' => 'after DOCTYPE public keyword state'},
                               ]};
              } elsif ($action =~ s/Otherwise, if the six characters starting from the current input character are an? (ASCII case-insensitive|case-sensitive) match for the word "SYSTEM", then (this is a parse error; |)consume those characters and switch to the after DOCTYPE system keyword state\.\s*//) {
                push @action, {type => 'IF-KEYWORD',
                               keyword => 'SYSTEM',
                               case_insensitive => ($1 eq 'ASCII case-insensitive' ? ($2 ? 'error' : 1) : 0),
                               value => [
                                 {type => 'switch',
                                  'state' => 'after DOCTYPE system keyword state'},
                               ]};
    } elsif ($action =~ s/^If the DTD mode of the parser is ((?:not |)internal subset), switch to the (.*? state)\.//) {
      push @action, {type => 'switch', state => $2,
                     if => 'DTD mode is ' . $1,
                     break => 1};
    } elsif ($action =~ s/^If the parser was originally created as part of the XML fragment parsing algorithm, emit an end-of-file token and (?:return|abort these steps)\.//) {
      push @action, {type => 'emit-eof',
                     if => 'fragment',
                     break => 1};
    } elsif ($action =~ s/^If the parser was originally created as part of the XML fragment parsing algorithm, switch to the (DTD state) and (?:return|abort these steps)\.//) {
      push @action, {type => 'switch',
                     state => $1,
                     if => 'fragment', break => 1};
    } elsif ($action =~ s/^If the parser was originally created as part of the XML fragment parsing algorithm, this is a parse error; switch to the (DTD state) and (?:return|abort these steps)\.//) {
      push @action, {type => 'parse error-and-switch',
                     state => $1,
                     if => 'fragment', break => 1};
    } elsif ($action =~ s/^If the parser was originally created as part of the XML fragment parsing algorithm, this is a parse error \(offset=1\); switch to the (DTD state) and (?:return|abort these steps)\.//) {
      push @action, {type => 'parse error-and-switch',
                     state => $1,
                     index_offset => 1,
                     if => 'fragment', break => 1};
    } elsif ($action =~ s/^If the parser was originally created for a parameter entity reference in a markup declaration, this is a parse error; switch to the (.+? state) and (?:return|abort these steps)\.//) {
      push @action, {type => 'parse error-and-switch',
                     state => $1,
                     if => 'md-fragment', break => 1};
    } elsif ($action =~ s/^If the parser was originally created for a parameter entity reference in a markup declaration, this is a parse error \(offset=1\); switch to the (.+? state) and (?:return|abort these steps)\.//) {
      push @action, {type => 'parse error-and-switch',
                     state => $1,
                     index_offset => 1,
                     if => 'md-fragment', break => 1};
    } elsif ($action =~ s/^If the stack of open marked sections is not empty, parse error\.//) {
      push @action, {type => 'parse error', if => 'sections is not empty'};
    } elsif ($action =~ s/^If the parser was originally created for a parameter entity reference in a markup declaration, (?:return|abort these steps)\.//) {
      push @action, {type => 'break', if => 'md-fragment'};

    } elsif ($action =~ s/^(?:T|Otherwise, t)reat it as per the "anything else" entry below\.\s*//) {
      push @action, {type => 'SAME-AS-ELSE'};
    } elsif ($action =~ s/^Ignore the character\.\s*//) {
      #
    } elsif ($action =~ s/^\(Don't[^()]+\)\s*// or
             $action =~ s/^\(This does not [^()]+\)\s*//) {
      #
    } elsif ($action =~ s/^[Ss]tay in (?:the current|this) state\.\s*//) { # xml5
      #
    } elsif ($action =~ s/^Consume every character up to the next occurrence of the three character sequence U\+005D RIGHT SQUARE BRACKET U\+005D RIGHT SQUARE BRACKET U\+003E GREATER-THAN SIGN \(\]\]>\), or the end of the file \(EOF\), whichever comes first\. Emit a series of character tokens consisting of all the characters consumed except the matching three character sequence at the end \(if one was found before the end of the file\)\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => ']]>',
           value => [{type => 'SWITCH'}],
           not_anchored => 1,
           else_value => [{type => 'emit-temp'}]},
          {type => 'emit-char'};
    } elsif ($action =~ s/^Consume every character up to and including the first U\+003E GREATER-THAN SIGN character \(>\) or the end of the file \(EOF\), whichever comes first\. If more than one character was consumed, then emit a comment token whose data is the concatenation of all the characters starting from and including the character that caused the state machine to switch into the bogus comment state, up to and including the character immediately before the last consumed character \(i\.e\. up to the character just before the U\+003E or EOF character\), but with any U\+0000 NULL characters replaced by U\+FFFD REPLACEMENT CHARACTER characters\. \(.+\)//) {
      push @action,
          {type => 'APPEND-UNTIL', field => 'data', value => '>',
           replace_null => 1},
          {type => 'emit'};
    } elsif ($action =~ s/^Consume every character up to the first U\+003E \(>\) or EOF, whichever comes first\. Emit a comment token whose data is the concatenation of all those consumed characters\. Then consume the next input character and switch to the data state reprocessing the EOF character if that was the character consumed\.//) { # xml5
      push @action,
          {type => 'APPEND-UNTIL', field => 'data', value => '>'},
          {type => 'emit'},
          {type => 'switch', state => 'data state'},
          {type => 'RECONSUME-IF-EOF'};
    } elsif ($action =~ s/^Consume every character up to the first U\+003E \(>\) or EOF, whichever comes first\. Emit a comment token whose data is the concatenation of all those consumed characters\. Then consume the next input character and switch to the DOCTYPE internal subset state reprocessing the EOF character if that was the character consumed\.//) { # xml5
      push @action,
          {type => 'APPEND-UNTIL', field => 'data', value => '>'},
          {type => 'emit'},
          {type => 'switch', state => 'DOCTYPE internal subset state'},
          {type => 'RECONSUME-IF-EOF'};
    } elsif ($action =~ s/^If the end of the file was reached, reconsume the EOF character\.//) {
      push @action, {type => 'RECONSUME-IF-EOF'};
    } elsif ($action =~ s/^When the user agent leaves the attribute name state \(and before emitting the tag token, if appropriate\), the complete attribute's name must be compared to the other attributes on the same token; if there is already an attribute on the token with the exact same name, then this is an? (?:[\w-]+ |)parse error and the new attribute must be removed from the token\.// or
             $action =~ s/^When the user agent leaves this state \(and before emitting the tag token, if appropriate\), the complete attribute's name must be compared to the other attributes on the same token; if there is already an attribute on the token with the exact same name, then this is an? (?:[\w-]+ |)parse error and the new attribute must be dropped, along with the value that gets associated with it \(if any\)\.//) {
      #
    } elsif ($action =~ s/^Attempt to consume a character reference\.//) {
      push @action, {type => 'consume-charref'};
    } elsif ($action =~ s/^Attempt to consume a character reference, with no additional allowed character.//) {
      push @action,
          {type => 'SET-ALLOWED-CHAR', value => undef},
          {type => 'consume-charref'};
    } elsif ($action =~ s/^If nothing is returned, emit a U\+0026 AMPERSAND character \(&\) token\.//) {
      push @action, {type => 'emit-char-if-nothing', value => '&'};
    } elsif ($action =~ s/^Otherwise, emit the character tokens that were returned\.//) {
      push @action, {type => 'emit-unless-nothing'};
    } elsif ($action =~ s/^If nothing is returned, append a U\+0026 AMPERSAND character \(&\) to the current attribute's value\.//) {
      push @action, {type => 'append-to-attr-if-nothing', value => '&'};
    } elsif ($action =~ s/^Otherwise, append the returned character tokens to the current attribute's value\.//) {
      push @action, {type => 'append-to-attr-unless-nothing'};
    } elsif ($action =~ s/^Finally, switch back to the attribute value state that switched into this state\.//) {
      push @action, {type => 'SWITCH-BACK'};
      $PreserveStateBeforeSwitching->{$state_name} = 1;
    } elsif ($action =~ s/^If the next two characters are both U\+002D HYPHEN-MINUS characters \(-\), consume those two characters, create a comment token whose data is the empty string, and switch to the ((?:DOCTYPE |)comment start state)\.// or
             $action =~ s/^If the next two characters are both U\+002D \(-\) characters, consume those two characters, create a comment token whose data is the empty string and then switch to the (comment state)\.// or # xml5
             $action =~ s/^If the next two characters are both U\+002D \(-\) characters, then consume those characters and switch to the (DOCTYPE comment state)\.//) { # xml5
      push @action,
          {type => 'IF-KEYWORD',
           keyword => '--',
           value => [
             {type => 'create', token => 'comment token'},
             {type => 'set-empty', field => 'data'},
             {type => 'switch', state => $1},
           ]};
    } elsif ($action =~ s/^Otherwise, if the next seven characters are an ASCII case-insensitive match for the word "DOCTYPE", then consume those characters and switch to the DOCTYPE state\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => 'DOCTYPE',
           case_insensitive => 1,
           value => [
             {type => 'switch', state => 'DOCTYPE state'},
           ]};
    } elsif ($action =~ s/^(?:Otherwise, i|I)f the next \S+ characters are a case-sensitive match for the (?:word|string) "(\S+?)", then consume those characters and switch to the (.+? state)\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => $1,
           value => [
             {type => 'switch', state => $2},
           ]};
    } elsif ($action =~ s/^Otherwise, if the next \S+ characters are an ASCII case-insensitive match for the word "(\S+?)", then this is a parse error; consume those characters and switch to the (.+? state)\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => $1,
           case_insensitive => 'error',
           value => [
             {type => 'switch', state => $2},
           ]};
    } elsif ($action =~ s/^Otherwise, if the next seven characters are an exact match for "DOCTYPE", then this is a parse error\. Consume those characters and switch to the DOCTYPE state\.//) { # xml5
      push @action,
          {type => 'IF-KEYWORD',
           keyword => 'DOCTYPE',
           value => [
             {type => 'parse error'},
             {type => 'switch', state => 'DOCTYPE state'},
           ]};
    } elsif ($action =~ s/^Otherwise, if the next (?:six|seven|eight) characters are an exact match for "(ENTITY|ATTLIST|NOTATION)", then consume those characters and switch to the (DOCTYPE (?:ENTITY|ATTLIST|NOTATION) state)\.//) { # xml5
      push @action,
          {type => 'IF-KEYWORD',
           keyword => $1,
           value => [
             {type => 'switch', state => $2},
           ]};
    } elsif ($action =~ s/^Otherwise, if there is an adjusted current node and it is not an element in the HTML namespace and the next seven characters are a case-sensitive match for the string "\[CDATA\[" \([^()]+\), then consume those characters and switch to the CDATA section state\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => '[CDATA[',
           value => [
             {type => 'switch', state => 'CDATA section state',
              if => 'in-foreign', break => 1},
             {type => 'SAME-AS-ELSE'},
           ]};
    } elsif ($action =~ s/^Consume those characters\.\s*If there is an adjusted current node and it is not an element in the HTML namespace, then switch to the CDATA section state\.//) {
      push @action,
         {type => 'switch', state => 'CDATA section state',
          if => 'in-foreign', break => 1};
    } elsif ($action =~ s/^If there is an adjusted current node and it is not an element in the HTML namespace, then consume those characters and switch to the CDATA section state. Otherwise, act as described in the "anything else" entry below\.//) {
      push @action,
          {type => 'switch', state => 'CDATA section state',
           if => 'in-foreign', break => 1},
          {type => 'SAME-AS-ELSE'};
    } elsif ($action =~ s/^Otherwise, if the next seven characters are a case-sensitive match for the string "\[CDATA\[" \([^()]+\), then consume those characters and switch to the CDATA section state\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => '[CDATA[',
           value => [
             {type => 'switch', state => 'CDATA section state'},
           ]};
    } elsif ($action =~ s/^Otherwise, if the next seven characters are an? (?:exact|case-sensitive) match for the (?:string |word |)"\[CDATA\["(?: \([^()]+\)|), then: if the stack of open elements is empty, parse error; consume those characters; and switch to the (.+? state)\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => '[CDATA[',
           value => [
             {type => 'parse error', if => 'OE is empty'},
             {type => 'switch', state => $1},
           ]};
    } elsif ($action =~ s/^Otherwise, switch to the DOCTYPE bogus comment state\.//) {
      push @action, {type => 'switch', state => 'DOCTYPE bogus comment state'};

    } elsif ($action =~ s/^\QThis section defines how to consume a character reference, optionally with an additional allowed character, which, if specified where the algorithm is invoked, adds a character to the list of characters that cause there to not be a character reference.\E// or
             $action =~ s/^\QThis definition is used when parsing character references in text and in attributes.\E// or
             $action =~ s/^\QThe behavior depends on the identity of the next character (the one immediately after the U+0026 AMPERSAND character), as follows:\E//) {
      #
    } elsif ($action =~ s/^\QNot a character reference. No characters are consumed, and nothing is returned. (This is not an error, either.)\E//) {
      push @action, {type => 'RETURN-NOTHING'};
    } elsif ($action =~ s/^\QConsume the U+0023 NUMBER SIGN.\E// or
             $action =~ s/^\QConsume the X.\E//) {
      push @action, {type => 'append-to-temp'};
    } elsif ($action =~ s/^\QThe behavior further depends on the character after the U+0023 NUMBER SIGN:\E// or
             $action =~ s/^\QWhen it comes to interpreting the number, interpret it as a hexadecimal number.\E// or
             $action =~ s/^\QWhen it comes to interpreting the number, interpret it as a decimal number.\E//) {
      #
    } elsif ($action =~ s/^Follow the steps below, but using ASCII hex digits\.//) {
      push @action, {type => 'SET-CHARREF-MODE', value => 'ASCII hex digits'};
    } elsif ($action =~ s/^\QFollow the steps below, but using ASCII digits.\E//) {
      push @action, {type => 'SET-CHARREF-MODE', value => 'ASCII digits'};
    } elsif ($action =~ s/^\QConsume as many characters as match the range of characters given above (ASCII hex digits or ASCII digits).\E//) {
      push @action, {type => 'CONSUME-DIGITS'};
    } elsif ($action =~ s/^\QIf no characters match the range, then don't consume any characters (and unconsume the U+0023 NUMBER SIGN character and, if appropriate, the X character). This is a parse error; nothing is returned.\E//) {
      push @action, {type => 'ERROR-RETURN-NOTHING-UNLESS-DIGITS'};
    } elsif ($action =~ s/^\QOtherwise, if the next character is a U+003B SEMICOLON, consume that too. If it isn't, there is a parse error.\E//) {
      push @action, {type => 'SEMICOLON-OR-ERROR'};
    } elsif ($action =~ s/^\QIf one or more characters match the range, then take them all and interpret the string of characters as a number (either hexadecimal or decimal as appropriate).\E// or
             $action =~ s/^Number Unicode character 0x00.+//) {
      #
    } elsif ($action =~ s/^\QIf that number is one of the numbers in the first column of the following table, then this is a parse error. Find the row with that number in the first column, and return a character token for the Unicode character given in the second column of that row.\E//) {
      push @action, {type => 'EMIT-BY-TABLE-IF-C1'};
    } elsif ($action =~ s/^\QOtherwise, if the number is in the range 0xD800 to 0xDFFF or is greater than 0x10FFFF, then this is a parse error. Return a U+FFFD REPLACEMENT CHARACTER character token.\E//) {
      push @action, {type => 'EMIT-REPLACEMENT-IF-NOT-UNICODE'};
    } elsif ($action =~ s/^Otherwise, return a character token for the Unicode character whose code point is that number\.//) {
      push @action, {type => 'EMIT-BY-DIGITS'};
    } elsif ($action =~ s/^Additionally, if the number is in the range 0x0001 to 0x0008, 0x000D to 0x001F, 0x007F to 0x009F, 0xFDD0 to 0xFDEF, or is one of 0x[0-9A-F]+(?:, (?:or |)0x[0-9A-F]+)+, then this is a parse error\.//) {
      push @action, {type => 'ERROR-IF-IN-RANGE'};
    } elsif ($action =~ s/^\QConsume the maximum number of characters possible, with the consumed characters matching one of the identifiers in the first column of the named character references table (in a case-sensitive manner).\E//) {
      push @action, {type => 'CONSUME-BY-TABLE'};
    } elsif ($action =~ s/^\QIf no match can be made, then no characters are consumed, and nothing is returned. In this case, if the characters after the U+0026 AMPERSAND character (&) consist of a sequence of one or more alphanumeric ASCII characters followed by a U+003B SEMICOLON character (;), then this is a parse error.\E//) {
      push @action, {type => 'SEMICOLON-THEN-ERROR-AND-RETURN-NOTHING-UNLESS-MATCH'};
    } elsif ($action =~ s/^\QIf the character reference is being consumed as part of an attribute, and the last character matched is not a U+003B SEMICOLON character (;), and the next character is either a U+003D EQUALS SIGN character (=) or an alphanumeric ASCII character, then, for historical reasons, all the characters that were matched after the U+0026 AMPERSAND character (&) must be unconsumed, and nothing is returned. However, if this next character is in fact a U+003D EQUALS SIGN character (=), then this is a parse error, because some legacy user agents will misinterpret the markup in those cases.\E//) {
      push @action, {type => 'UNCONSUME-UNLESS-SEMICOLON-AND-EQUAL-ERROR'};
    } elsif ($action =~ s/^\QOtherwise, a character reference is parsed. If the last character matched is not a U+003B SEMICOLON character (;), there is a parse error.\E//) {
      push @action, {type => 'ERROR-UNLESS-SEMICOLON'};
    } elsif ($action =~ s/^\QReturn one or two character tokens for the character(s) corresponding to the character reference name (as given by the second column of the named character references table).\E//) {
      push @action, {type => 'RETURN-CHARS'};

    } elsif ($action =~ s/^Switch back to the original state\.//) {
      push @action, {type => 'SWITCH-BACK'};
    } elsif ($action =~ s/^Process the temporary buffer as a decimal reference\.//) {
      push @action, {type => 'process-temp-as-decimal'};
    } elsif ($action =~ s/^Process the temporary buffer as a hexadecimal reference\.//) {
      push @action, {type => 'process-temp-as-hexadecimal'};
    } elsif ($action =~ s/^Process the temporary buffer as a named reference\.//) {
      push @action, {type => 'process-temp-as-named'};
    } elsif ($action =~ s/^Process the temporary buffer as a named reference with before equals flag set\.//) {
      push @action, {type => 'process-temp-as-named', before_equals => 1};
    } elsif ($action =~ s/^Validate an entity reference name\.//) {
      push @action, {type => 'validate-temp-as-entref'};
    } elsif ($action =~ s/^Process the parameter entity reference in DTD\.//) {
      push @action, {type => 'process-temp-as-peref-dtd'};
    } elsif ($action =~ s/^Process the parameter entity reference in an entity value\.//) {
      push @action, {type => 'process-temp-as-peref-entity-value'};
    } elsif ($action =~ s/^Process the parameter entity reference in a markup declaration\.//) {
      push @action, {type => 'process-temp-as-peref-md'};

    } elsif ($action =~ s/^Flush the temporary buffer\.//) {
      push @action, {type => 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR', field => 'value'};
    } elsif ($action =~ s/^Unset the additional allowed character\.//) {
      push @action, {type => 'SET-ALLOWED-CHAR', value => undef};
    } elsif ($action =~ s/^Set the original state to (?:the |)(.+? state)\.//) {
      push @action, {type => 'set-original-state',
                     state => $1 eq 'current state' ? $state_name : $1};
      $action[-1]->{external_state} = $action[-1]->{state} . ' - before text declaration in markup declaration state';
    } elsif ($action =~ s/^Process the temporary buffer as a text declaration\.//) {
      push @action, {type => 'process-xml-declaration-in-temp'};
    } elsif ($action =~ s/^Process the temporary buffer as a text declaration, or if it failed, parse error \(offset=1\) and switch to the (bogus markup declaration state)\.//) {
      push @action, {type => 'process-xml-declaration-in-temp',
                     false_actions => [{type => 'parse error-and-switch',
                                        name => 'before-text-declaration-003c',
                                        index_offset => 1,
                                        state => $1}]};
    } elsif ($action =~ s/^Set the in literal flag\.//) {
      push @action, {type => 'set-in-literal'};
    } elsif ($action =~ s/^Unset the in literal flag\.//) {
      push @action, {type => 'unset-in-literal'};

    } elsif ($action =~ s/^([^.]+\.+)\s*//) {
      push @action, {type => 'misc', desc => $1};
    } else {
      last;
    }
  } # while 1
  push @action, {type => 'misc', desc => $action} if length $action;

  my @act;
  for (@action) {
    if ($_->{type} eq 'switch' and $state_name eq 'attribute name state') {
      push @act, {type => 'set-attr'};
    }
    push @act, $_;
  }

  return (\@act);
} # parse_action

sub parse_switch ($);
sub parse_switch ($) {
  my $node = shift;
  my $switch_conds = [];
  my $was_dd;
  my $conds = {};
  for my $n (@{$node->children}) {
    my $ln = $n->local_name;
    if ($ln eq 'dt') {
      my $cond = _n $n->text_content;
      if ($cond eq 'EOF') {
        #
      } elsif ($cond eq 'Anything else') {
        $cond = 'ELSE';
      } elsif ($cond eq 'ASCII upper alpha' or
               $cond eq 'Uppercase ASCII letter') {
        $cond = 'UPPER';
      } elsif ($cond eq 'ASCII lower alpha' or
               $cond eq 'Lowercase ASCII letter') {
        $cond = 'LOWER';
      } elsif ($cond eq 'ASCII alpha' or
               $cond eq 'ASCII letter') {
        $cond = 'LETTER';
      } elsif ($cond eq 'ASCII digit') {
        $cond = 'DIGIT';
      } elsif ($cond eq 'ASCII hex digit') {
        $cond = 'HEXDIGIT';
      } elsif ($cond =~ /^U\+([0-9A-F]+)\s+[0-9A-Z-\s]+(?:\((?:[^()\s]+|[()])\)|)$/) {
        $cond = sprintf 'CHAR:%04X', hex $1;
      } elsif ($cond =~ /^U\+([0-9A-F]+)\s+[0-9A-Z-\s]+ character$/) {
        $cond = sprintf 'CHAR:%04X', hex $1;
      } elsif ($cond =~ /^u?U\+([0-9A-F]+)(?:\s+\([^()+]\)|):?\s*$/) { # xml5
        $cond = 'CHAR:' . $1;
      } elsif ($cond =~ /^U\+([0-9A-F]+)\s+\(.\)$/) {
        $cond = sprintf 'CHAR:%04X', hex $1;
      } elsif ($cond =~ /^The additional allowed character, if there is one$/) {
        $cond = 'ALLOWED_CHAR';
      } elsif ($cond =~ /^If the (.+) is empty$/) {
        my $n = {
          'stack of open content model groups' => 'cm-group',
        }->{$1} or die "Unknown cond |$1|";
        $cond = 'IF-EMPTY:' . $n;
      } elsif ($cond eq 'Otherwise') {
        $cond = 'ELSE';
      } elsif ($cond eq 'ASCII alphanumeric') {
        $conds->{'LETTER'} = $conds->{'DIGIT'} ||= {};
        $switch_conds = [] if $was_dd;
        push @$switch_conds, 'LETTER', 'DIGIT';
        $was_dd = 0;
        next;
      } else {
        $cond = 'MISC:' . $cond;
      }
      $conds->{$cond} ||= {};
      $switch_conds = [] if $was_dd;
      push @$switch_conds, $cond;
      $was_dd = 0;
    } elsif ($ln eq 'dd') {
      my $fc = $n->first_element_child;
      my $switches = join ' ', '', (sort { $a cmp $b } @$switch_conds), '';
      $switches =~ s/ CHAR:0009 CHAR:000A CHAR:000C CHAR:0020 / WS:HTML /;
      $switches =~ s/ CHAR:0009 CHAR:000A CHAR:0020 / WS:XML /;
      delete $conds->{$_} for @$switch_conds;
      $switch_conds = [grep { length } split / /, $switches];
      my @node;
      if (defined $fc and ($fc->local_name eq 'p' or
                           $fc->local_name eq 'dl')) {
        push @node, @{$n->children};
      } else {
        push @node, $n;
      }
      for my $n (@node) {
        next if $n->class_list->contains ('note');
        next if $n->class_list->contains ('example');
        my $actions = [];
        if ($n->local_name eq 'dl' and $n->class_list->contains ('switch')) {
          my $conds = parse_switch $n;
          if (2 == keys %$conds and defined $conds->{ELSE}) {
            my $cond_true = [grep { $_ ne 'ELSE' } sort { $a cmp $b } keys %$conds]->[0];
            if ($cond_true =~ /^IF-EMPTY:(.+)/) {
              push @$actions, {type => 'if-empty', list => $1,
                               actions => $conds->{$cond_true}->{actions},
                               false_actions => $conds->{ELSE}->{actions}};
            } else {
              push @$actions, {type => 'CONSUME-CONDS', value => $conds};
            }
          } else {
            push @$actions, {type => 'CONSUME-CONDS', value => $conds};
          }
        } else {
          ($actions) = parse_action _n $n->text_content;
        }
        for (@$switch_conds) {
          push @{$conds->{$_}->{actions} ||= []}, map { +{%$_} } @$actions;
        }
      } # @node
      $was_dd = 1;
    }
  }
  return $conds;
} # parse_switch

my $switch_mode = '';
my @node = @{$doc->body->child_nodes};
while (@node) {
  check_loop 'document.body';
  my $node = shift @node;
  if ($node->node_type == $node->ELEMENT_NODE) {
    my $ln = $node->local_name;
    if ($ln =~ /^h[1-6]$/ or $ln eq 'dt') {
      my $tc = _n $node->text_content;
      if ($tc =~ /^[0-9.]+ Parse state$/) {
        #
      } elsif ($tc =~ /^[0-9.]+\s+(.+state)\s*$/) {
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
        if ($switch_mode eq 'if-keyword') {
          my $current;
          for my $cn ($node->children->to_list) {
            if ($cn->local_name eq 'dt') {
              my $cond = _n $cn->text_content;
              $current = {type => 'IF-KEYWORD', value => []};
              if ($cond =~ /^Two U\+002D HYPHEN-MINUS characters \(-\)$/) {
                $current->{keyword} = '--';
              } elsif ($cond =~ /^ASCII case-insensitive match for the word "([^"]+)"$/) {
                $current->{keyword} = $1;
                $current->{case_insensitive} = 1;
              } elsif ($cond =~ /^Case-sensitive match for the string "([^"]+)" \([^()]+\)$/) {
                $current->{keyword} = $1;
              } elsif ($cond =~ /^\QThe string "[CDATA[" (the five uppercase letters "CDATA" with a U+005B LEFT SQUARE BRACKET character before and after)\E$/) {
                $current->{keyword} = '[CDATA[';
              } elsif ($cond =~ /^Anything else$/) {
                $current = undef;
              } else {
                die "Bad condition |$cond|";
              }
              push @{$Data->{states}->{$state_name}->{conds}->{ELSE}->{actions} ||= []}, $current
                  if defined $current;
            } elsif ($cn->local_name eq 'dd') {
              my $tc = _n $cn->text_content;
              $tc =~ s/^Consume those (?:two |)characters(?:, | and )//;
              my ($actions) = parse_action $tc;
              if (defined $current) {
                push @{$current->{value}}, @$actions;
              } else {
                push @{$Data->{states}->{$state_name}->{conds}->{ELSE}->{actions} ||= []}, @$actions;
              }
            } else {
              die "Bad element |@{[$cn->local_name]}| in switch";
            }
          } # $cn
        } else {
          my $conds = parse_switch $node;
          for (sort { $a cmp $b } keys %$conds) {
            $Data->{states}->{$state_name}->{conds}->{$_} = $conds->{$_};
          }
        }
      } else { # not .switch
        unshift @node, $node->child_nodes->to_list;
      }
    } elsif ($ln eq 'p') {
      next if $node->class_list->contains ('note');
      next if $node->class_list->contains ('example');
      my $tc = _n $node->text_content;
      next unless defined $state_name;
      if ($tc =~ /^Consume the next input character:$/) {
        $switch_mode = '';
      } elsif ($tc =~ /^If the next few characters are:$/) {
        $switch_mode = 'if-keyword';
      } else {
        my ($actions) = parse_action $tc;
        push @{$Data->{states}->{$state_name}->{conds}->{ELSE}->{actions} ||= []}, @$actions;
      }
    } else { # $ln
      next if $node->class_list->contains ('note');
      next if $node->class_list->contains ('example');
      unshift @node, $node->child_nodes->to_list;
    } # $ln
  } # $node->node_type
}

sub modify_actions (&) {
  my $code = shift;
  for my $state (sort { $a cmp $b } keys %{$Data->{states}}) {
    for my $cond (sort { $a cmp $b } keys %{$Data->{states}->{$state}->{conds} or {}}) {
      for my $key (qw(actions false_actions)) {
        my $acts = $Data->{states}->{$state}->{conds}->{$cond}->{$key};
        if (defined $acts) {
          my $new_acts = [];
          $code->($acts => $new_acts, $state, $cond);
          @$acts = @$new_acts;

          for my $act (@$acts) {
            for my $key (qw(actions false_actions value)) {
              if (defined $act->{$key} and ref $act->{$key} eq 'ARRAY') {
                my $new_acts = [];
                $code->($act->{$key} => $new_acts, $state, $cond);
                @{$act->{$key}} = @$new_acts;
              }
            }
          }
        }
      }
    }
  }
} # modify_actions

## Also in |xml-syntax.pl|.
sub error_name ($$) {
  my $name = my $name_orig = shift;
  my $cond = shift;
  $name =~ s/^.+ state - ((?:before |)text declaration in markup declaration state)/$1/;
  $name =~ s/ state$//;
  $name .= '-' . $cond;
  $name =~ s/CHAR://;
  $name =~ s/WS:[A-Z]+/WS/;
  $name = lc $name;
  $name =~ s/([^a-z0-9]+)/-/g;
  $name = 'EOF' if $name =~ /-eof$/ and not $name_orig =~ /before ATTLIST attribute default state/;
  $name = 'NULL' if $name =~ /-0000$/;
  return $name;
} # error_name

{
  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    for (@$acts) {
      if ($_->{type} eq 'parse error') {
        $_->{name} = error_name $state, $cond;
      } elsif ($_->{type} eq 'parse error-and-switch') {
        $_->{name} = error_name $state, $cond . '-' . ($_->{if} // '');
      }
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    for (@$acts) {
      if ($_->{type} eq 'switch') {
        if ($_->{state} eq 'markup declaration open state' or
            $_->{state} eq 'DOCTYPE markup declaration open state') {
          push @$new_acts,
              {type => 'set-empty-to-temp'},
              {%$_};
        } else {
          push @$new_acts, {%$_};
        }
      } else {
        push @$new_acts, {%$_};
      }
    }
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    if (@$acts and $acts->[-1]->{type} eq 'RECONSUME-IF-EOF') {
      pop @$acts;
      $Data->{states}->{$state}->{conds}->{EOF}->{actions} = [
        grep {
          not $_->{type} eq 'APPEND-UNTIL' and
          not $_->{type} eq 'IF-KEYWORD' and
          not $_->{type} eq 'emit-char';
        } @$acts, {type => 'reconsume'},
      ];
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    if (@$acts >= 2 and
        $acts->[0]->{type} eq 'switch' and
        $acts->[1]->{type} eq 'IF-KEYWORD' and
        @{$acts->[1]->{value}} and
        $acts->[1]->{value}->[0]->{type} eq 'SWITCH') {
      $acts->[1]->{value}->[0]->{type} = 'switch';
      $acts->[1]->{value}->[0]->{state} = $acts->[0]->{state};
      shift @$acts;
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    for (0..$#$acts) {
      if ($acts->[$_]->{type} eq 'APPEND-UNTIL' and
          1 == length $acts->[$_]->{value}) {
        $Data->{states}->{$state}->{conds}->{sprintf 'CHAR:%04X', ord $acts->[$_]->{value}}->{actions} = [@$acts[0..($_-1)], @$acts[($_+1)..$#$acts]];
        if ($acts->[$_]->{replace_null}) {
          $Data->{states}->{$state}->{conds}->{sprintf 'CHAR:%04X', 0x0000}->{actions} = [@$acts[0..($_-1)], {type => 'append', field => $acts->[$_]->{field}, value => "\x{FFFD}"}];
        }
        $acts = [@$acts[0..($_-1)], {type => 'append', field => $acts->[$_]->{field}}];
        last;
      }
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    if ($cond eq 'ELSE') {
      while (@$acts and $acts->[0]->{type} eq 'IF-KEYWORD') {
        check_loop 'IF-KEYWORD';
        my $act = shift @$acts;
        my $old_state = $state;
        my $new_state = $state . ' -- ';
        my $cs = '';
        my $save = {type => 'append-to-temp'};
        my $suffix = defined $act->{if} ? ':' . $act->{if} : '';
        my $kwd = $act->{keyword};
        my $else_value = $act->{else_value} || [];
        my $has_reconsume = 0;
        my $else_acts = [map {
          if ($_->{type} eq 'set-empty') {
            ($_, {type => 'append-temp', field => $_->{field}});
          } elsif ($_->{type} eq 'reconsume') {
            $has_reconsume = 1;
            $_;
          } else {
            $_;
          }
        } @$acts];
        my $eof_acts = [@$else_acts];
        push @$eof_acts, {type => 'reconsume'} unless $has_reconsume;
        while (length $act->{keyword}) {
          my $c = substr $act->{keyword}, 0, 1;
          $cs .= $c;
          $new_state .= $c;
          (substr $act->{keyword}, 0, 1) = '';
          if (0 == length $act->{keyword}) { ## Last character
            $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord $c}->{actions} = $act->{value};
            if ($act->{case_insensitive}) {
              if ($act->{case_insensitive} eq 'error') {
                my $chk = [{type => 'append-to-temp'},
                           {if => 'temp-wrong-case', type => 'parse error',
                            name => 'keyword-wrong-case',
                            index_offset => (length $kwd) - 1,
                            expected_keyword => $kwd}];
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord lc $c}->{actions} = [@$chk, @{$act->{value}}];
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord uc $c}->{actions} = [@$chk, @{$act->{value}}];
              } else {
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord lc $c}->{actions} = $act->{value};
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord uc $c}->{actions} = $act->{value};
              }
            }
          } else {
            if ($old_state eq $state) {
              $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X'.$suffix, ord $c}->{actions} = [{type => 'set-to-temp'}, {type => 'switch', state => $new_state}];
              if ($act->{case_insensitive}) {
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X'.$suffix, ord lc $c}->{actions} = [{type => 'set-to-temp'}, {type => 'switch', state => $new_state}];
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X'.$suffix, ord uc $c}->{actions} = [{type => 'set-to-temp'}, {type => 'switch', state => $new_state}];
              }
            } else {
              $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord $c}->{actions} = [$save, {type => 'switch', state => $new_state}];
              if ($act->{case_insensitive}) {
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord lc $c}->{actions} = [$save, {type => 'switch', state => $new_state}];
                $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord uc $c}->{actions} = [$save, {type => 'switch', state => $new_state}];
              }
            }
            $Data->{states}->{$new_state}->{conds}->{ELSE}->{actions} = [grep {
              not $_->{type} eq 'IF-KEYWORD' or $_->{keyword} =~ /^\Q$cs\E/;
            } @$else_value, {type => 'switch', state => $state}, @$else_acts];
            $Data->{states}->{$new_state}->{conds}->{EOF}->{actions} = [grep {
              not $_->{type} eq 'IF-KEYWORD' or $_->{keyword} =~ /^\Q$cs\E/;
            } @$else_value, {type => 'switch', state => $state}, @$eof_acts];
            if ($act->{not_anchored} and $cs eq $c . $c) { # ]]>
              my $slide = {type => 'emit-char', index_offset => 2};
              $Data->{states}->{$new_state}->{conds}->{sprintf 'CHAR:%04X', ord $c}->{actions} = [$slide];
              if ($act->{case_insensitive}) {
                $Data->{states}->{$new_state}->{conds}->{sprintf 'CHAR:%04X', ord lc $c}->{actions} = [$slide];
                $Data->{states}->{$new_state}->{conds}->{sprintf 'CHAR:%04X', ord uc $c}->{actions} = [$slide];
              }
            }
          }
          $old_state = $new_state;
        }
      }
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    if (@$acts and $acts->[-1]->{type} eq 'SAME-AS-ELSE') {
      pop @$acts;
      push @$acts, @{$Data->{states}->{$state}->{conds}->{ELSE}->{actions}};
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    if (@$acts) {
      push @$new_acts, {%{shift @$acts}};
      for (@$acts) {
        if ({
          'emit-char' => 1,
          'append' => 1,
        }->{$_->{type}}) {
          if (
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
        } else {
          push @$new_acts, {%$_};
        }
      }
    }
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    for (@$acts) {
      if ($_->{type} eq 'switch') {
        if ($PreserveStateBeforeSwitching->{$_->{state}}) {
          push @$new_acts,
              {type => 'set-original-state', state => $state},
              {%$_};
        } else {
          push @$new_acts, {%$_};
        }
      } else {
        push @$new_acts, {%$_};
      }
    }
  };

  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    for (@$acts) {
      if (($_->{type} eq 'emit-char' or
           $_->{type} eq 'append' or
           $_->{type} eq 'append-char' or
           $_->{type} eq 'set-to-temp' or
           $_->{type} eq 'emit-char-if-nothing' or
           $_->{type} eq 'append-to-attr-if-nothing') and
          defined $_->{value}) {
        if ($state eq 'CDATA section end state' and
            $cond eq 'CHAR:005D') {
          $_->{index_offset} ||= 2;
        } elsif ($cond =~ /^CHAR:([0-9A-F]+)$/ and
            (substr $_->{value}, -1) eq chr hex $1) {
          $_->{index_offset} ||= (length $_->{value}) - 1;
        } elsif ($cond eq 'CHAR:0000' and
                 (substr $_->{value}, -1) eq "\x{FFFD}") {
          $_->{index_offset} ||= (length $_->{value}) - 1;
        } else {
          $_->{index_offset} ||= length $_->{value};
        }
        push @$new_acts, {%$_};
      } else {
        push @$new_acts, {%$_};
      }
    }
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    if (@$acts >= 2 and
        $acts->[-2]->{type} eq 'reconsume' and
        {'emit' => 1,
         'emit-char' => 1}->{$acts->[-1]->{type}}) { ## HTML spec seems buggy...
      @$new_acts = @$acts[0..($#$acts-2), ($#$acts), ($#$acts-1)];
    } else {
      @$new_acts = @$acts;
    }
  };
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
