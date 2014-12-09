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

for (@ARGV) {
  my $state_name;
  for (split /\x0D?\x0A/, path ($_)->slurp_utf8) {
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
      $Data->{$state_name}->{$left} = $right;
    } else {
      die "Broken line: |$_|";
    }
  }
}

$doc->inner_html (q{<!DOCTYPE html><title>XML tokenizer</title>});
my $body = $doc->body;

sub _current ($) {
  return {
    '' => 'current token',
    "attr's " => 'current attribute definition',
    "token's " => 'current allowed token',
  }->{$_[0]};
} # _current

sub add_cond ($$$) {
  my ($conds, $exprs, $dl) = @_;
  for my $cond (@$conds) {
    my $dt = $doc->create_element ('dt');
    $dt->text_content ($cond);
    $dl->append_child ($dt);
  }
  my $dd = $doc->create_element ('dd');
  while (@$exprs) {
    if (@$exprs == 1) {
      if (defined $dd->first_element_child) {
        my $p = $doc->create_element ('p');
        $p->text_content ('Otherwise:');
        $dd->append_child ($p);
      }
      my @expr = split /\s*;\s*/, _n shift @$exprs;
      @expr = ('ignore') unless @expr;
      for my $expr (map { _n $_ } @expr) {
        my $html = {
          error => q{<span>Parse error</span>.},
          emit => q{Emit the current token.},
          reconsume => q{Reconsume the <span>current input character</span>.},
          q{is parameter entity} => q{Set the <i>is parameter entity</i> flag of the current token.},
          ignore => q{Ignore the character.},
          attr => q{Create an attribute definition and append it to the list of attribute definitions of the current token.},
          token => q{Create an allowed token and append it to the list of allowed tokens of the current attribute definition.},
        }->{$expr};
        if (defined $html) {
          my $p = $doc->create_element ('p');
          $p->inner_html ($html);
          $dd->append_child ($p);
        } elsif ($expr =~ / state$/) {
          my $p = $doc->create_element ('p');
          # XXX original state for entity ref states
          $p->inner_html (q{Switch to the <span></span>.});
          $p->first_element_child->text_content ($expr);
          $dd->append_child ($p);
        } elsif ($expr =~ /(.+? state) \((.+ state)\)$/) {
          my $p = $doc->create_element ('p');
          # XXX original state for entity ref states
          $p->inner_html (q{Switch to the <span></span>.});
          $p->first_element_child->text_content ($1);
          $dd->append_child ($p);
        } elsif ($expr =~ /^append to (.+?'s |)(.+)$/) {
          my $p = $doc->create_element ('p');
          $p->inner_html (q{Append the <span>current input character</span> to the <span></span>'s <i></i>.});
          $p->children->[-2]->text_content (_current $1);
          $p->children->[-1]->text_content ($2);
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
        } elsif ($expr =~ /^set to (.+?'s |)(.+)$/) {
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
  my $text = $p0->text_content;
  $text =~ s/^\s*Otherwise, if/If/;
  $p0->text_content ($text);
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

for my $state_name (sort { $a cmp $b } keys %$Data) {
  my $h1 = $doc->create_element ('h1');
  $h1->inner_html (q{<dfn></dfn>});
  $h1->first_child->text_content ($state_name);
  $body->append_child ($h1);

  my $intro = $doc->create_element ('p');
  $intro->inner_html (q{Consume the <span>next input character</span>:});
  $body->append_child ($intro);

  my $dl = $doc->create_element ('dl');
  $dl->set_attribute (class => 'switch');

  my @kwd_cond;
  for my $cond (sort { $a cmp $b } keys %{$Data->{$state_name}}) {
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
    add_cond $conds, [$Data->{$state_name}->{$cond}] => $dl;
  }

  if ($Data->{$state_name}->{ELSE}) {
    if (@kwd_cond) {
      add_cond ['Anything else'], [
        (map { $_ => $Data->{$state_name}->{$_} } @kwd_cond),
        $Data->{$state_name}->{ELSE},
      ] => $dl;
    } else {
      add_cond ['Anything else'], [$Data->{$state_name}->{ELSE}] => $dl;
    }
  }

  $body->append_child ($dl);
}

binmode STDOUT, qw(:encoding(utf-8));
print $doc->inner_html;
