use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib')->stringify;
use JSON::PS;

my $Data = {};

for (qw(
  local/ariardf-parsed.json
  local/aria-roles.json
)) {
  my $path = path (__FILE__)->parent->parent->child ($_);
  my $data = json_bytes2perl $path->slurp;
  for my $name (sort { $a cmp $b } keys %{$data->{roles}}) {
    for my $key (sort { $a cmp $b } keys %{$data->{roles}->{$name}}) {
      if ($key eq 'attrs') {
        for my $aname (sort { $a cmp $b } keys %{$data->{roles}->{$name}->{$key}}) {
          $Data->{roles}->{$name}->{$key}->{$aname} ||= {};
          for my $akey (sort { $a cmp $b } keys %{$data->{roles}->{$name}->{$key}->{$aname}}) {
            $Data->{roles}->{$name}->{$key}->{$aname}->{$akey}
                = $data->{roles}->{$name}->{$key}->{$aname}->{$akey};
          }
        }
      } else {
        $Data->{roles}->{$name}->{$key} = $data->{roles}->{$name}->{$key};
      }
    }
  }
  for my $name (sort { $a cmp $b } keys %{$data->{attrs}}) {
    for my $key (sort { $a cmp $b } keys %{$data->{attrs}->{$name}}) {
      $Data->{attrs}->{$name}->{$key} = $data->{attrs}->{$name}->{$key};
    }
  }
}

{
  my $has_new = 0;
  for my $role (sort { $a cmp $b } keys %{$Data->{roles}}) {
    for my $super (sort { $a cmp $b } keys %{$Data->{roles}->{$role}->{subclass_of} or {}}) {
      my $v = $Data->{roles}->{$role}->{subclass_of}->{$super};
      next unless $v == 1;
      for (sort { $a cmp $b } keys %{$Data->{roles}->{$super}->{subclass_of} or {}}) {
        my $old = $Data->{roles}->{$role}->{subclass_of}->{$_};
        my $new = $Data->{roles}->{$super}->{subclass_of}->{$_} + 1;
        if (not defined $old or $old < $new) {
          $Data->{roles}->{$role}->{subclass_of}->{$_} = $new;
          $has_new = 1;
        }
      }
    }
  } # $role
  redo if $has_new;
}

for my $role (sort { $a cmp $b } keys %{$Data->{roles}}) {
  for my $super (sort { $a cmp $b } keys %{$Data->{roles}->{$role}->{subclass_of} or {}}) {
    unless ($super eq 'roletype') { # global
      for my $state (sort { $a cmp $b } keys %{$Data->{roles}->{$super}->{attrs} or {}}) {
        $Data->{roles}->{$role}->{attrs}->{$state} ||= $Data->{roles}->{$super}->{attrs}->{$state};
      }
    }
    for my $role2 (sort { $a cmp $b } keys %{$Data->{roles}->{$super}->{must_contain} or {}}) {
      $Data->{roles}->{$role}->{must_contain}->{$role2} ||= $Data->{roles}->{$super}->{must_contain}->{$role2};
    }
  }
}

for my $sub_role (sort { $a cmp $b } keys %{$Data->{roles}}) {
  for my $super_role (sort { $a cmp $b } keys %{$Data->{roles}->{$sub_role}->{subclass_of} or {}}) {
    $Data->{roles}->{$super_role}->{superclass_of}->{$sub_role} = $Data->{roles}->{$sub_role}->{subclass_of}->{$super_role};
  }
}
for my $role (sort { $a cmp $b } keys %{$Data->{roles}}) {
  for my $role2 (sort { $a cmp $b } keys %{$Data->{roles}->{$role}->{scope} or {}}) {
    for my $sub (sort { $a cmp $b } keys %{$Data->{roles}->{$role2}->{superclass_of} or {}}) {
      $Data->{roles}->{$role}->{scope}->{$sub} ||= $Data->{roles}->{$role}->{scope}->{$role2} + $Data->{roles}->{$role2}->{superclass_of}->{$sub};
    }
  }
}

## |aria-*| attributes
## <https://www.w3.org/WAI/PF/aria/complete#states_and_properties>.

## <https://www.w3.org/WAI/PF/aria/complete#propcharacteristic_value>,
## <https://www.w3.org/WAI/PF/aria/complete#typemapping>.
my $ARIAValueTypes = {
  'true/false' => 'enumerated',
  'tristate' => 'enumerated',
  'true/false/undefined' => 'enumerated',
  'true/false/mixed/undefined' => 'enumerated', ## Not in spec
  'ID reference' => 'idref',
  'ID reference list' => 'ordered set of unique space-separated tokens', ## Spec is vaguer
  'integer' => 'non-negative integer',
  'positive integer' => 'non-negative integer greater than zero', ## Not in spec
  'number' => 'floating-point number',
  'string' => 'any',
  'token' => 'enumerated',
  'token list' => 'unordered set of unique space-separated tokens', ## Spec is vaguer
  'URI' => 'URL',
};

{
  my $path = path (__FILE__)->parent->parent->child ('src/aria-attrs.txt');
  my $aname;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^\s*#/) {
      #
    } elsif (/^\*\s*(\S+)$/) {
      $aname = $1;
      $Data->{attrs}->{$aname} ||= {};
    } elsif (/^spec\s+(\S+)$/) {
      $Data->{attrs}->{$aname}->{url} = $1;
    } elsif (/^value\s+(.+?\|.+)$/) {
      $Data->{attrs}->{$aname}->{tokens}->{$_} ||= {} for split /\|/, $1;
      $Data->{attrs}->{$aname}->{value_type} = $ARIAValueTypes->{token};
    } elsif (/^value\+\s+(.+?\|.+)$/) {
      $Data->{attrs}->{$aname}->{tokens}->{$_} ||= {} for split /\|/, $1;
      $Data->{attrs}->{$aname}->{value_type} = $ARIAValueTypes->{'token list'};
    } elsif (/^value\s+(.+)$/) {
      my $type = $1;
      die "Bad type |$type|" unless defined $ARIAValueTypes->{$type};
      $Data->{attrs}->{$aname}->{value_type} = $ARIAValueTypes->{$type};
      if ($type eq 'ID reference list') {
        $Data->{attrs}->{$aname}->{item_type} = 'idref';
        $Data->{attrs}->{$aname}->{id_type} = 'any';
      } elsif ($type eq 'ID reference') {
        $Data->{attrs}->{$aname}->{id_type} = 'any';
      } elsif ($type eq 'true/false') {
        $Data->{attrs}->{$aname}->{tokens}->{$_} = {}
            for qw(true false);
        $Data->{attrs}->{$aname}->{default} = 'false';
      } elsif ($type eq 'true/false/undefined') {
        $Data->{attrs}->{$aname}->{tokens}->{$_} = {}
            for qw(true false undefined);
        $Data->{attrs}->{$aname}->{default} = 'undefined';
      } elsif ($type eq 'tristate') {
        $Data->{attrs}->{$aname}->{tokens}->{$_} = {}
            for qw(true false mixed);
        $Data->{attrs}->{$aname}->{default} = 'false';
      } elsif ($type eq 'true/false/mixed/undefined') {
        $Data->{attrs}->{$aname}->{tokens}->{$_} = {}
            for qw(true false mixed undefined);
        $Data->{attrs}->{$aname}->{default} = 'undefined';
      }
    } elsif (/^default\s+(.*)$/) {
      $Data->{attrs}->{$aname}->{default} = $1;
    } elsif (/^state$/) {
      $Data->{attrs}->{$aname}->{is_state} = 1;
    } elsif (/^(deprecated|obsolete)$/) {
      $Data->{attrs}->{$aname}->{$1} = 1;
    } elsif (/\S+/) {
      die "Bad line |$_|";
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/altmap-aria.json');
  my $data = json_bytes2perl $path->slurp;
  for my $role (sort { $a cmp $b } keys %{$data->{roles}}) {
    my $preferred = $data->{roles}->{$role}->{preferred};
    $Data->{roles}->{$role}->{preferred} = $preferred if defined $preferred;
  }
  for my $name (sort { $a cmp $b } keys %{$data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}}) {
    my $preferred = $data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$name}->{preferred};
    $Data->{attrs}->{$name}->{preferred} = $preferred if defined $preferred;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
