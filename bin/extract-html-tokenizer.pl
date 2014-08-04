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

$Data->{char_sets}->{'WS:HTML'}->{$_} = 1
    for 0x0009, 0x000A, 0x000C, 0x0020;
$Data->{char_sets}->{'WS:XML'}->{$_} = 1
    for 0x0009, 0x000A, 0x0020;
$Data->{char_sets}->{'UPPER'}->{$_} = 1
    for (ord 'A')..(ord 'Z');
$Data->{char_sets}->{'LOWER'}->{$_} = 1
    for (ord 'a')..(ord 'z');
$Data->{char_sets}->{'DIGIT'}->{$_} = 1
    for (ord '0')..(ord '9');
$Data->{char_sets}->{'HEXDIGIT'}->{$_} = 1
    for (ord '0')..(ord '9'), (ord 'A')..(ord 'F'), (ord 'a')..(ord 'f');

my $state_name;
my $PreserveStateBeforeSwitching = {};

sub parse_action ($) {
  my $action = shift;
  my @action;
  while (1) {
    $action =~ s/^\s+//;
    if ($action =~ s/^Otherwise, this is a parse error. Switch to the bogus comment state. The next character that is consumed, if any, is the first character that will be in the comment\.//) {
      push @action,
          {type => 'parse error'},
          {type => 'append-temp', field => 'data'},
          {type => 'switch', state => 'bogus comment state'};
    } elsif ($action =~ s/^Parse error\.\s*// or
             $action =~ s/^Otherwise, this is a parse error\.\s*//) {
      push @action, {type => 'parse error'};
    } elsif ($action =~ s/^(?:S|s|Finally, s|Then s)witch to the ([A-Za-z0-9 ._()-]+ state)(?:\.\s*|\s*$)//) {
      push @action, {type => 'switch', state => $1};
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
              } elsif ($action =~ s/^Set a U\+([0-9A-F]+) [A-Z0-9 _-]+ character (?:\([^()]+\) |)to the temporary buffer\.//) {
                push @action, {type => 'set-to-temp', value => chr hex $1};
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
                push @action, {type => 'IF-KEYWORD',
                               keyword => 'PUBLIC',
                               case_insensitive => 1,
                               value => [
                                 {type => 'switch',
                                  'state' => 'after DOCTYPE public keyword state'},
                               ]};
              } elsif ($action =~ s/Otherwise, if the six characters starting from the current input character are an ASCII case-insensitive match for the word "SYSTEM", then consume those characters and switch to the after DOCTYPE system keyword state\.\s*//) {
                push @action, {type => 'IF-KEYWORD',
                               keyword => 'SYSTEM',
                               case_insensitive => 1,
                               value => [
                                 {type => 'switch',
                                  'state' => 'after DOCTYPE system keyword state'},
                               ]};
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
    } elsif ($action =~ s/^Consume every character up to and including the first U\+003E GREATER-THAN SIGN character \(>\) or the end of the file \(EOF\), whichever comes first\. Emit a comment token whose data is the concatenation of all the characters starting from and including the character that caused the state machine to switch into the bogus comment state, up to and including the character immediately before the last consumed character \(i\.e\. up to the character just before the U\+003E or EOF character\), but with any U\+0000 NULL characters replaced by U\+FFFD REPLACEMENT CHARACTER characters\. \(.+\)//) {
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
    } elsif ($action =~ s/^When the user agent leaves the attribute name state \(and before emitting the tag token, if appropriate\), the complete attribute's name must be compared to the other attributes on the same token; if there is already an attribute on the token with the exact same name, then this is a parse error and the new attribute must be removed from the token\.// or
             $action =~ s/^When the user agent leaves this state \(and before emitting the tag token, if appropriate\), the complete attribute's name must be compared to the other attributes on the same token; if there is already an attribute on the token with the exact same name, then this is a parse error and the new attribute must be dropped, along with the value that gets associated with it \(if any\)\.//) {
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
    } elsif ($action =~ s/^If the next two characters are both U\+002D HYPHEN-MINUS characters \(-\), consume those two characters, create a comment token whose data is the empty string, and switch to the (comment start state)\.// or
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
    } elsif ($action =~ s/^Otherwise, if the next seven characters are an exact match for "\[CDATA\[", then consume those characters and switch to the CDATA state\.//) {
      push @action,
          {type => 'IF-KEYWORD',
           keyword => '[CDATA[',
           value => [
             {type => 'switch', state => 'CDATA state'},
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
    } elsif ($action =~ s/^Flush the temporary buffer\.//) {
      push @action, {type => 'EMIT-TEMP-OR-APPEND-TEMP-TO-ATTR', field => 'value'};
    } elsif ($action =~ s/^Unset the additional allowed character\.//) {
      push @action, {type => 'SET-ALLOWED-CHAR', value => undef};
    } elsif ($action =~ s/^Set the original state to (.+ state)\.//) {
      push @action, {type => 'set-original-state', state => $1};

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
    if ($_->{type} eq 'switch' and $_->{state} eq 'bogus comment state') {
      my @a;
      if (@act and $act[-1]->{type} eq 'append-temp') {
        push @a, pop @act;
      }
      push @act,
          {type => 'create', token => 'comment token'},
          {type => 'set-empty', field => 'data'},
          @a,
          $_,
          {type => 'reconsume'};
    } else {
      push @act, $_;
    }
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
      } elsif ($cond eq 'Uppercase ASCII letter') {
        $cond = 'UPPER';
      } elsif ($cond eq 'Lowercase ASCII letter') {
        $cond = 'LOWER';
      } elsif ($cond eq 'ASCII digit') {
        $cond = 'DIGIT';
      } elsif ($cond eq 'ASCII hex digit') {
        $cond = 'HEXDIGIT';
      } elsif ($cond =~ /^U\+([0-9A-F]+)\s+[0-9A-Z-\s]+(?:\([^()\s]+\)|)$/) {
        $cond = sprintf 'CHAR:%04X', hex $1;
      } elsif ($cond =~ /^u?U\+([0-9A-F]+)(?:\s+\([^()+]\)|):?\s*$/) { # xml5
        $cond = 'CHAR:' . $1;
      } elsif ($cond =~ /^The additional allowed character, if there is one$/) {
        $cond = 'ALLOWED_CHAR';
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
      if (defined $fc and $fc->local_name eq 'p') {
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
          push @$actions, {type => 'CONSUME-CONDS', value => $conds};
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

my @node = @{$doc->body->child_nodes};
while (@node) {
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
        my $conds = parse_switch $node;
        for (keys %$conds) {
          $Data->{states}->{$state_name}->{conds}->{$_} = $conds->{$_};
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
        #
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
  for my $state (keys %{$Data->{states}}) {
    for my $cond (keys %{$Data->{states}->{$state}->{conds} or {}}) {
      my $acts = $Data->{states}->{$state}->{conds}->{$cond}->{actions} or next;
      my $new_acts = [];
      $code->($acts => $new_acts, $state, $cond);
      @$acts = @$new_acts;
    }
  }
} # modify_actions

{
  modify_actions {
    my ($acts => $new_acts, $state, $cond) = @_;
    for (@$acts) {
      if ($_->{type} eq 'parse error') {
        my $name = $state;
        $name =~ s/ state$//;
        $name .= '-' . $cond;
        $name =~ s/CHAR://;
        $name =~ s/WS:[A-Z]+/WS/;
        $name = lc $name;
        $name =~ s/([^a-z0-9]+)/-/g;
        $name = 'EOF' if $name =~ /-eof$/;
        $name = 'NULL' if $name =~ /-0000$/;
        $_->{name} = $name;
      }
    }
    @$new_acts = @$acts;
  };

  modify_actions {
    my ($acts => $new_acts, $state) = @_;
    for (@$acts) {
      if ($_->{type} eq 'switch') {
        if ($_->{state} eq 'markup declaration open state') {
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
        my $act = shift @$acts;
        my $old_state = $state;
        my $new_state = $state . ' -- ';
        my $cs = '';
        my $save = {type => 'append-to-temp'};
        my $suffix = defined $act->{if} ? ':' . $act->{if} : '';
        while (length $act->{keyword}) {
          my $c = substr $act->{keyword}, 0, 1;
          $cs .= $c;
          $new_state .= $c;
          (substr $act->{keyword}, 0, 1) = '';
          if (0 == length $act->{keyword}) {
            $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord $c}->{actions} = $act->{value};
            if ($act->{case_insensitive}) {
              $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord lc $c}->{actions} = $act->{value};
              $Data->{states}->{$old_state}->{conds}->{sprintf 'CHAR:%04X', ord uc $c}->{actions} = $act->{value};
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
            } @{$act->{else_value} || []}, {type => 'switch', state => $state}, @$acts];
            $Data->{states}->{$new_state}->{conds}->{EOF}->{actions} = [grep {
              not $_->{type} eq 'IF-KEYWORD' or $_->{keyword} =~ /^\Q$cs\E/;
            } @{$act->{else_value} || []}, {type => 'switch', state => $state}, {type => 'reconsume'}];
            if ($act->{not_anchored} and $cs eq $c . $c) { # ]]>
              my $slide = {type => 'emit-char'}; # XXX index offset => -1
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
    my ($acts => $new_acts) = @_;
    if (@$acts) {
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
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
