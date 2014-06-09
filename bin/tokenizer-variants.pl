use strict;
use warnings;
use JSON::PS;

local $/ = undef;
my $Data = {tokenizer => (json_bytes2perl <>)->{tokenizer}};

{
  my $chars = {};
  my $char_to_cond_in_state = {};
  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for (keys %{$Data->{tokenizer}->{states}->{$state}->{conds}}) {
      if ($_ eq 'EOF' or $_ eq 'ELSE') {
        #
      } elsif ($_ =~ /^CHAR:([0-9A-F]+)/) {
        $char_to_cond_in_state->{$state, hex $1} = $_;
        $chars->{hex $1} = 1;
      } else {
        for my $c (keys %{$Data->{tokenizer}->{char_sets}->{$_}}) {
          $char_to_cond_in_state->{$state, $c} = $_;
          $chars->{$c} = 1;
        }
      }
    }
  }

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for my $c (keys %$chars) {
      $chars->{$c} .= $; . ($char_to_cond_in_state->{$state, $c} || 'ELSE');
    }
  }

  my %map;
  for my $c (keys %$chars) {
    $map{$chars->{$c}}->{$c} = 1;
  }

  my $char_to_class = {};
  for (values %map) {
    my $name = join ',', map { sprintf '%04X', $_ } sort { $a <=> $b } keys %$_;
    $Data->{tokenizer}->{char_classes}->{$name} = $_;
    $char_to_class->{$_} = $name for keys %$_;
  }

  for my $state (keys %{$Data->{tokenizer}->{states}}) {
    for my $c (keys %$chars) {
      $Data->{tokenizer}->{states}->{$state}->{char_class_to_cond}->{$char_to_class->{$c}} = $char_to_cond_in_state->{$state, $c} || 'ELSE';
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
