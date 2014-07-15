use strict;
use warnings;
use JSON::PS;

my $Data = do {
  local $/ = undef;
  my $data = json_bytes2perl scalar <>;
  $data;
};
delete $Data->{tokenizer};
delete $Data->{$_} for grep { /^adjusted_/ } keys %$Data;

sub for_actions (&$);
sub for_actions (&$) {
  my ($code, $acts) = @_;
  for my $act (@$acts) {
    for (qw(actions false_actions between_actions)) {
      $act->{$_} = &for_actions ($code, $act->{$_}) if defined $act->{$_};
    }
  }
  return $code->($acts);
} # for_actions

for my $step_name (keys %{$Data->{tree_steps}}) {
  $Data->{tree_steps}->{$step_name}->{actions} = for_actions {
    my $acts = shift;
    my $new_acts = [];

    for my $act (@$acts) {
      if (1 == keys %$act and $Data->{tree_steps}->{$act->{type}}) {
        push @$new_acts, @{$Data->{tree_steps}->{$act->{type}}->{actions}};
      } else {
        push @$new_acts, $act;
      }
    }

    return $new_acts;
  } $Data->{tree_steps}->{$step_name}->{actions};
}

for my $im (keys %{$Data->{ims}}) {
  for my $cond (keys %{$Data->{ims}->{$im}->{conds}}) {
    my $def = $Data->{ims}->{$im}->{conds}->{$cond};
    $def->{actions} = for_actions {
      my $acts = shift;
      my $new_acts = [];

      for my $act (@$acts) {
        if (1 == keys %$act and $Data->{tree_steps}->{$act->{type}}) {
          push @$new_acts, @{$Data->{tree_steps}->{$act->{type}}->{actions}};
        } else {
          push @$new_acts, $act;
        }
      }

      return $new_acts;
    } $def->{actions};
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

