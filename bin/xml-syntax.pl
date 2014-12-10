use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;
use Web::HTML::Parser;

my $Data = {};

## Public identifiers for XHTML named character references DTD
## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-documents>
for (
  '-//W3C//DTD XHTML 1.0 Transitional//EN',
  '-//W3C//DTD XHTML 1.1//EN',
  '-//W3C//DTD XHTML 1.0 Strict//EN',
  '-//W3C//DTD XHTML 1.0 Frameset//EN',
  '-//W3C//DTD XHTML Basic 1.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN',
  '-//W3C//DTD XHTML 1.1 plus MathML 2.0 plus SVG 1.1//EN',
  '-//W3C//DTD MathML 2.0//EN',
  '-//WAPFORUM//DTD XHTML Mobile 1.0//EN',
) {
  $Data->{charrefs_pubids}->{$_} = 1;
}

{
  for ('local/html-tokenizer.json',
       'local/html-tokenizer-charrefs-jump.json',
       'local/html-tokenizer-charrefs.json',
       'local/xml-tokenizer-only.json',
       'local/xml-tokenizer-only2.json',
       'local/xml-tokenizer-replace.json') {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child ($_)->slurp;
    for (keys %{$tokenizer->{char_sets} or {}}) {
      $Data->{tokenizer}->{char_sets}->{$_} = $tokenizer->{char_sets}->{$_};
    }
    for (keys %{$tokenizer->{states}}) {
      $Data->{tokenizer}->{states}->{$_} = $tokenizer->{states}->{$_};
    }
  }

  {
    my $tokenizer = json_bytes2perl path (__FILE__)->parent->parent->child
        ('local/xml-tokenizer-delta.json')->slurp;
    for my $state (keys %{$tokenizer->{states}}) {
      for my $cond (keys %{$tokenizer->{states}->{$state}->{conds}}) {
        $Data->{tokenizer}->{states}->{$state}->{conds}->{$cond}
            = $tokenizer->{states}->{$state}->{conds}->{$cond};
      }
    }
  }

  ## GCing
  {
    my $referenced = {};
    my @action_list;
    my $visit_state = sub {
      my $s = shift;
      unless ($referenced->{$s}) {
        for (values %{$Data->{tokenizer}->{states}}) {
          for (values %{$Data->{tokenizer}->{states}->{$s}->{conds}}) {
            push @action_list, $_->{actions};
          }
        }
      }
      $referenced->{$s} = 1;
    };
    $visit_state->('data state');
    while (@action_list) {
      my $acts = shift @action_list;
      for (@{$acts or []}) {
        $visit_state->($_->{state}) if defined $_->{state};
        push @action_list, $_->{actions} if defined $_->{actions};
      }
    }
    my @state = sort { $a cmp $b } keys %{$Data->{tokenizer}->{states}};
    for (@state) {
      unless ($referenced->{$_}) {
        warn "GC: $_ is not referenced\n";
        delete $Data->{tokenizer}->{states}->{$_};
      }
    }
  } ## GCing
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
