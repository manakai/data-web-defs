use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Web::DOM::Document;

my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # _n

my $Data = {};

sub parse ($$) {
  my $state_name;
  for (split /\x0D?\x0A/, $_[0]) {
    if (/^\*(.+)$/) {
      $state_name = _n $1;
      next;
    } elsif (/^\#/) {
      next;
    } elsif (/^\s*$/) {
      next;
    } elsif (not defined $state_name) {
      die "Broken line: |$_|";
    }

    if (/^\s*(\S+)\s+->\s*(.*)$/) {
      my $left = $1;
      my $right = $2;
      $_[1]->{$state_name}->{$left} = $right;
    } elsif (/^\s*(\S+)\s+(!?)\[([^\[\]]+)\]\s+->\s*(.*)$/) {
      my $left = $1;
      $_[1]->{$state_name}->{$left}->{$3}->{$2} = $4;
    } else {
      die "Broken line: |$_|";
    }
  }
} # parse

for (@ARGV) {
  parse path ($_)->slurp_utf8 => $Data;
}

$doc->inner_html (q{<!DOCTYPE html><title>XML tokenizer</title>});
my $body = $doc->body;

sub _current ($) {
  return {
    '' => 'current token',
    "attr's " => 'current attribute definition',
    "token's " => 'current allowed token',
    "cm group's " => 'current content model group',
    "cm element's " => 'current content model element',
  }->{$_[0]} // die "Unknown item |$_[0]|";
} # _current

my $OriginalStates = {};
my $CurrentState;

sub add_cond ($$$);
sub add_cond ($$$) {
  my ($conds, $exprs, $dl) = @_;
  for my $cond (@$conds) {
    my $dt = ref $cond ? $cond : $doc->create_element ('dt');
    $dt->text_content ($cond) if not ref $cond;
    $dl->append_child ($dt);
  }
  my $dd = $doc->create_element ('dd');
  while (@$exprs) {
    if (@$exprs == 1) {
      if (ref $exprs->[0] eq 'HASH' and 1 == keys %{$exprs->[0]}) {
        my $key = each %{$exprs->[0]};
        my $true = $exprs->[0]->{$key}->{''};
        my $false = $exprs->[0]->{$key}->{'!'};
        shift @$exprs;
        my $_dl = $doc->create_element ('dl');
        $_dl->class_name ('switch');
        my $dt = $doc->create_element ('dt');
        $dt->inner_html ('If the <span></span> is empty');
        $dt->first_element_child->text_content ({
          'cm group' => 'stack of open content model groups',
        }->{$key} // $key);
        add_cond ([$dt], [$true] => $_dl);
        add_cond (['Otherwise'], [$false] => $_dl);
        $dd->append_child ($_dl);
        next;
      }

      if (defined $dd->first_element_child) {
        if ($exprs->[0] =~ /^error; marked section; ([^;]+? state); reconsume$/) {
          shift @$exprs;
          my $p = $doc->create_element ('p');
          $p->inner_html ('Otherwise, this is a <span>parse error</span>.  Create a marked section whose status is <i>IGNORE</i> and push it onto the <span>stack of open marked sections</span>.  Switch to the <span></span>.  Reconsume the <span>current input character</span>.');
          $p->children->[-2]->text_content ($1);
          $dd->append_child ($p);
          next;
        } elsif ($exprs->[0] =~ /^error; ([^;]+? state)$/) {
          shift @$exprs;
          my $p = $doc->create_element ('p');
          $p->inner_html ('Otherwise, this is a <span>parse error</span>.  Switch to the <span></span>.');
          $p->last_element_child->text_content ($1);
          $dd->append_child ($p);
          next;
        } elsif ($exprs->[0] =~ /^([^;]+? state)$/) {
          shift @$exprs;
          my $p = $doc->create_element ('p');
          $p->inner_html ('Otherwise, switch to the <span></span>.');
          $p->last_element_child->text_content ($1);
          $dd->append_child ($p);
          next;
        } else {
          die $exprs->[0];
          my $p = $doc->create_element ('p');
          $p->text_content ('Otherwise:');
          $dd->append_child ($p);
        }
      }
      my @expr = split /\s*;\s*/, _n shift @$exprs;
      @expr = ('ignore') unless @expr;
      for my $expr (map { _n $_ } @expr) {
        my $html = {
          error => q{<span>Parse error</span>.},
          'error(-1)' => q{<span>Parse error</span> <ins>(offset=1)</ins>.},
          'error(-2)' => q{<span>Parse error</span> <ins>(offset=2)</ins>.},
          emit => q{Emit the current token.},
          reconsume => q{Reconsume the <span>current input character</span>.},
          q{is parameter entity} => q{Set the <i>is parameter entity</i> flag of the current token.},
          ignore => q{Ignore the character.},
          'create(ELEMENT)' => q{Create a new ELEMENT token.},
          'create(ATTLIST)' => q{Create a new ATTLIST token.},
          'create(NOTATION)' => q{Create a new NOTATION token.},
          'create(ENTITY)' => q{Create a new ENTITY token.},
          attr => q{Create an attribute definition and append it to the list of attribute definitions of the current token.},
          'close attribute definition' => q{},
          token => q{Create an allowed token and append it to the list of allowed tokens of the current attribute definition.},
          'cm group' => q{Create a new content model group.},
          "set token's cm group" => q{Set the current token's <span>content model group</span> to the content model group.  Set the <span>stack of the open content model groups</span> to a stack that contains only the content model group.},
          'append cm group' => q{Append the content model group to the <span>current content model group</span>.  Push the content model group to the <span>stack of open content model groups</span>.},
          'close cm group' => q{Pop the <span>current content model group</span> off the <span>stack of open content model groups</span>.},
          'cm element' => q{Create a content model element and append it to the <span>current content model group</span>.},
          'cm separator' => q{Append the <span>current input character</span> as a <span>content model separator</span> to the <span>current content model group</span>.},
          'marked section(INCLUDE)' => q{Create a marked section whose status is <i>INCLUDE</i> and push it onto the <span>stack of open marked sections</span>.},
          'marked section' => q{Create a marked section whose status is <i>IGNORE</i> and push it onto the <span>stack of open marked sections</span>.},
          'close marked section and reset' => q{Pop the <span>current marked section</span> off the <span>stack of open marked sections</span> and reset the state.},
          'parameter entity reference in DTD' => q{<span>Process the parameter entity reference in DTD</span>.},
          'parameter entity reference in entity value' => q{<span>Process the parameter entity reference in an entity value</span>.},
          'parameter entity reference in markup declaration' => q{<span>Process the parameter entity reference in a markup declaration</span>.},
          'text declaration in value' => q{<span>Process the text declaration in the <span>current token</span>'s <i>value</i>, if any</span>.},
          'temp as text declaration' => q{<span>Process the temporary buffer as a text declaration</span>.},
        }->{$expr};
        if (defined $html) {
          my $p = $doc->create_element ('p');
          $p->inner_html ($html);
          $dd->append_child ($p);
        } elsif ($expr eq 'parameter entity name in markup declaration state') {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set a U+0025 PERCENT SIGN character (%) to the <span>temporary buffer</span>.  Set the <span>original state</span> to the current state.  Switch to the <span>parameter entity name in markup declaration state</span>.});
          $OriginalStates->{$CurrentState} = 1;
          $dd->append_child ($p);
        } elsif ($expr =~ /^parameter entity name in markup declaration state \((.+? state)\)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set a U+0025 PERCENT SIGN character (%) to the <span>temporary buffer</span>.  Set the <span>original state</span> to <span></span>.  Switch to the <span>parameter entity name in markup declaration state</span>.});
          $p->children->[-2]->text_content ($1);
          $OriginalStates->{$1} = 1;
          $dd->append_child ($p);
        } elsif ($expr =~ / state$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Switch to the <span></span>.});
          $p->first_element_child->text_content ($expr);
          $dd->append_child ($p);
        } elsif ($expr =~ /^append to temp$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append the <span>current input character</span> to the <span>temporary buffer</span>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^append to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append the <span>current input character</span> to the <span></span>'s <i></i>.});
          $p->children->[-2]->text_content (_current $1);
          $p->children->[-1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^append U\+FFFD to temp$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append a U+FFFD REPLACEMENT CHARACTER character to the <span>temporary buffer</span>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^append U\+FFFD to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append a U+FFFD REPLACEMENT CHARACTER character to the <span></span>'s <i></i>.});
          $p->children->[-2]->text_content (_current $1);
          $p->children->[-1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^append U\+0020 to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append a U+0020 SPACE character to the <span></span>'s <i></i>.});
          $p->children->[-2]->text_content (_current $1);
          $p->children->[-1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^append temp to value$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append the <span>temporary buffer</span>'s value to the current token's <i>value</i>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^set to temp$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set the <span>current input character</span> to the <span>temporary buffer</span>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^set to (.+?'s |)(.+?)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set the <span></span>'s <i></i> to the <span>current input character</span>.});
          $p->children->[0]->text_content (_current $1);
          $p->children->[1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^set U\+FFFD to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set the <span></span>'s <i></i> to a U+FFFD REPLACEMENT CHARACTER character.});
          $p->children->[0]->text_content (_current $1);
          $p->children->[1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^set empty to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set the <span></span>'s <i></i> to the empty string.});
          $p->children->[0]->text_content (_current $1);
          $p->children->[1]->text_content ($2);
          $dd->append_child ($p);
        } elsif ($expr =~ /^set U\+0025 to temp$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set a U+0025 PERCENT SIGN character (%) to the <span>temporary buffer</span>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^set U\+0026 to temp$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Set a U+0026 AMPERSAND character (&amp;) to the <span>temporary buffer</span>.});
          $dd->append_child ($p);
        } elsif ($expr =~ /^end$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Switch to the <span>data state</span>.  Reconsume the <span>current input character</span>.});
          $dd->append_child ($p);
        } else {
          die "Unknown expr |$expr|";
        }
      }
    } else {
      my $kwd = shift @$exprs;
      my $expr = shift @$exprs;
      $kwd = $1 if $kwd =~ /^"(.+)"$/;

      my $p1 = $doc->create_element ('p');
      my $p2 = $doc->create_element ('p');
      $p1->inner_html (q{
        Otherwise, if the next several characters are a
        <span>case-sensitive</span> match for the string
        "<code></code>", then consume those characters and switch to
        the <span></span>.
      });
      $p2->inner_html (q{
        Otherwise, if the next several characters are an <span>ASCII
        case-insensitive</span> match for the word "<code></code>",
        then this is a parse error; consume those characters and
        switch to the <span></span>.
      });
      $p1->children->[1]->text_content ($kwd);
      $p2->children->[1]->text_content ($kwd);
      $p1->children->[2]->text_content ($expr);
      $p2->children->[2]->text_content ($expr);

      $dd->append_child ($p1);
      $dd->append_child ($p2);
    }
  }
  my $p0 = $dd->first_element_child;
  if (defined $p0 and $p0->local_name eq 'p') {
    my $text = $p0->text_content;
    $text =~ s/^\s*Otherwise, if/If/;
    $p0->text_content ($text);
  }
  $dl->append_child ($dd);
} # add_cond

{
  my @name = split /\n/, require 'unicore/Name.pl';
  my %name;
  for (@name) {
    if (/^([0-9A-F]+)\s+([^\t]+)/) {
      $name{hex $1} = $2;
    }
  }
  sub charname ($) {
    $_[0] < 0x0020 ? '<control>' :
    $_[0] < 0x007F ? $name{$_[0]} :
    $_[0] < 0x00A0 ? '<control>' :
    $name{$_[0]} ? $name{$_[0]} :
    $_[0] < 0x00A0 ? '<control>' :
    $_[0] < 0x3400 ? '' :
    $_[0] < 0xA000 ? '<cjk>' :
    $_[0] < 0xE000 ? '<hangul>' :
    $_[0] < 0xF900 ? '<private>' :
    '';
  } # charname
}

sub convert ($$) {
  my ($state_name, $data) = @_;
  my $h1 = $doc->create_element ('h1');
  $h1->inner_html (q{<dfn></dfn>});
  $h1->first_child->text_content ($state_name);
  $body->append_child ($h1);
  $CurrentState = $state_name;

  my $intro = $doc->create_element ('p');
  $intro->inner_html (q{Consume the <span>next input character</span>:});
  $body->append_child ($intro);

  my $dl = $doc->create_element ('dl');
  $dl->set_attribute (class => 'switch');

  my @kwd_cond;
  for my $cond (sort { $a cmp $b } keys %$data) {
    my $conds = [];
    if ($cond =~ /^".+"$/) {
      push @kwd_cond, $cond;
      next;
    } elsif ($cond eq 'WS') {
      $conds = ['U+0009 CHARACTER TABULATION (tab)',
                'U+000A LINE FEED (LF)',
                'U+000C FORM FEED (FF)',
                'U+0020 SPACE'];
    } elsif ($cond eq 'NULL') {
      $conds = ['U+0000 NULL'];
    } elsif ($cond eq 'EOF') {
      $conds = [$cond];
    } elsif ($cond eq 'ELSE') {
      next;
    } else {
      $conds = [map {
        sprintf 'U+%04X %s (%s)',
            (ord $_), (charname ord $_), $_;
      } split //, $cond];
    }
    add_cond $conds, [$data->{$cond}] => $dl;
  }

  if (defined $data->{ELSE}) {
    if (@kwd_cond) {
      add_cond ['Anything else'], [
        (map { $_ => $data->{$_} } @kwd_cond),
        $data->{ELSE},
      ] => $dl;
    } else {
      add_cond ['Anything else'], [$data->{ELSE}] => $dl;
    }
  }

  $body->append_child ($dl);
} # convert

for my $state_name (sort { $a cmp $b } keys %$Data) {
  convert $state_name, $Data->{$state_name};
}

my $template = q{
* @@ - before text declaration in markup declaration state

<    -> set to temp; @@ - text declaration in markup declaration state
ELSE -> @@; reconsume

* @@ - text declaration in markup declaration state

>    -> @@; temp as text declaration
%&!< -> error; bogus markup declaration state
EOF  -> error; bogus markup declaration state; reconsume
NULL -> append U+FFFD to temp
ELSE -> append to temp
};

for my $orig_state_name (sort { $a cmp $b } keys %$OriginalStates) {
  my $def = $template;
  $def =~ s/\@\@/$orig_state_name/g;
  parse $def => my $parsed = {};
  for my $state_name (sort { $a cmp $b } keys %$parsed) {
    convert $state_name, $parsed->{$state_name};
  }
}

binmode STDOUT, qw(:encoding(utf-8));
print $doc->inner_html;
