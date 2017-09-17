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
  for my $name (keys %{$data->{roles}}) {
    for my $key (keys %{$data->{roles}->{$name}}) {
      $Data->{roles}->{$name}->{$key} = $data->{roles}->{$name}->{$key};
    }
  }
  for my $name (keys %{$data->{attrs}}) {
    for my $key (keys %{$data->{attrs}->{$name}}) {
      $Data->{attrs}->{$name}->{$key} = $data->{attrs}->{$name}->{$key};
    }
  }
}

## <https://w3c.github.io/aria/aria/aria.html#abstract_roles>
$Data->{roles}->{$_}->{abstract} = 1
    for qw(command composite input landmark range roletype section
           sectionhead select structure widget window);

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

{
  my $path = path (__FILE__)->parent->parent->child ('local/altmap-aria.json');
  my $data = json_bytes2perl $path->slurp;
  for my $role (keys %{$data->{roles}}) {
    my $preferred = $data->{roles}->{$role}->{preferred};
    $Data->{roles}->{$role}->{preferred} = $preferred if defined $preferred;
  }
}

$Data->{roles}->{alertdialog}->{attrs}->{'aria-describedby'}->{should} = 1;
$Data->{roles}->{definition}->{attrs}->{'aria-labelledby'}->{should} = 1;
$Data->{roles}->{form}->{attrs}->{'aria-labelledby'}->{should} = 1;

## <https://w3c.github.io/aria/aria/aria.html#scrollbar>
$Data->{roles}->{scrollbar}->{attrs}->{$_}->{must} = 1
    for qw(
      aria-controls aria-valuemin aria-valuemax aria-valuenow
    );

## <https://w3c.github.io/aria/aria/aria.html#slider>
$Data->{roles}->{slider}->{attrs}->{$_}->{must} = 1
    for qw(
      aria-valuemin aria-valuemax aria-valuenow
    );

## <https://w3c.github.io/aria/aria/aria.html#spinbutton>
$Data->{roles}->{spinbutton}->{attrs}->{'aria-valuenow'}->{must} = 1;

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

$Data->{attrs}->{$_}->{is_state} = 1
    for qw(aria-busy aria-checked aria-disabled aria-expanded
           aria-grabbed aria-hidden aria-invalid aria-pressed aria-selected
           aria-current);

{
  my @type = qw(
    role token_list
    aria-activedescendant ID_reference
    aria-atomic true/false
    aria-autocomplete token
    aria-busy true/false
    aria-checked true/false/mixed/undefined
    aria-controls ID_reference_list
    aria-describedby ID_reference_list
    aria-disabled true/false
    aria-dropeffect token_list
    aria-expanded true/false/undefined
    aria-flowto ID_reference_list
    aria-grabbed true/false/undefined
    aria-haspopup token
    aria-hidden true/false
    aria-invalid token
    aria-label string
    aria-labelledby ID_reference_list
    aria-level positive_integer
    aria-live token
    aria-multiline true/false
    aria-multiselectable true/false
    aria-orientation token
    aria-owns ID_reference_list
    aria-posinset positive_integer
    aria-pressed true/false/mixed/undefined
    aria-readonly true/false
    aria-relevant token_list
    aria-required true/false
    aria-selected true/false/undefined
    aria-setsize integer
    aria-sort token
    aria-valuemax number
    aria-valuemin number
    aria-valuenow number
    aria-valuetext string
    aria-describedat URI

    aria-modal true/false
    aria-current token
    aria-colcount integer
    aria-colindex integer
    aria-colspan positive_integer
    aria-details ID_reference
    aria-errormessage ID_reference
    aria-keyshortcuts string
    aria-placeholder string
    aria-roledescription string
    aria-rowcount integer
    aria-rowindex integer
    aria-rowspan positive_integer
  );
  while (@type) {
    my $name = shift @type;
    my $type = shift @type;
    $type =~ tr/_/ /;
    $Data->{attrs}->{$name}->{value_type} = $ARIAValueTypes->{$type};
    $Data->{attrs}->{$name}->{item_type} = 'idref',
    $Data->{attrs}->{$name}->{id_type} = 'any'
        if $type eq 'ID reference list';
    $Data->{attrs}->{$name}->{id_type} = 'any' if $type eq 'ID reference';
    if ($type eq 'true/false') {
      $Data->{attrs}->{$name}->{tokens}->{$_} = {}
          for qw(true false);
      $Data->{attrs}->{$name}->{default} = 'false';
    } elsif ($type eq 'true/false/undefined') {
      $Data->{attrs}->{$name}->{tokens}->{$_} = {}
          for qw(true false undefined);
      $Data->{attrs}->{$name}->{default} = 'undefined';
    } elsif ($type eq 'tristate') {
      $Data->{attrs}->{$name}->{tokens}->{$_} = {}
          for qw(true false mixed);
      $Data->{attrs}->{$name}->{default} = 'false';
    } elsif ($type eq 'true/false/mixed/undefined') {
      $Data->{attrs}->{$name}->{tokens}->{$_} = {}
          for qw(true false mixed undefined);
      $Data->{attrs}->{$name}->{default} = 'undefined';
    }
  }
}

$Data->{attrs}->{'aria-autocomplete'}->{tokens}->{$_} = {}
    for qw(inline list both none);
$Data->{attrs}->{'aria-autocomplete'}->{default} = 'none';
$Data->{attrs}->{'aria-dropeffect'}->{tokens}->{$_} = {}
    for qw(copy move link execute popup none);
$Data->{attrs}->{'aria-dropeffect'}->{default} = 'none';
$Data->{attrs}->{'aria-hidden'}->{preferred} = {type => 'html_attr', name => 'hidden'};
$Data->{attrs}->{'aria-invalid'}->{tokens}->{$_} = {}
    for qw(grammer false spelling true);
$Data->{attrs}->{'aria-invalid'}->{default} = 'false';
$Data->{attrs}->{'aria-live'}->{tokens}->{$_} = {}
    for qw(off polite assertive);
$Data->{attrs}->{'aria-live'}->{default} = 'off';
$Data->{attrs}->{'aria-orientation'}->{tokens}->{$_} = {}
    for qw(vertical horizontal
           undefined);
$Data->{attrs}->{'aria-relevant'}->{tokens}->{$_} = {}
    for qw(additions removals text all);
$Data->{attrs}->{'aria-relevant'}->{default} = 'additions text';
$Data->{attrs}->{'aria-sort'}->{tokens}->{$_} = {}
    for qw(ascending descending none other);
$Data->{attrs}->{'aria-sort'}->{default} = 'none';

## <https://w3c.github.io/aria/aria/aria.html#aria-haspopup>
$Data->{attrs}->{'aria-haspopup'}->{tokens}->{$_} = {}
    for qw(false true menu listbox tree grid dialog);
$Data->{attrs}->{'aria-haspopup'}->{default} = 'false';

## <https://w3c.github.io/aria/aria/aria.html#aria-dropeffect>
$Data->{attrs}->{'aria-dropeffect'}->{deprecated} = 1;

## <https://w3c.github.io/aria/aria/aria.html#aria-grabbed>
$Data->{attrs}->{'aria-grabbed'}->{deprecated} = 1;

## <http://w3c.github.io/aria/aria/aria.html#aria-current>
$Data->{attrs}->{'aria-current'}->{tokens}->{$_} = {}
    for qw(page step location date time true false);
$Data->{attrs}->{'aria-current'}->{default} = 'false';

## <https://w3c.github.io/aria/aria/aria.html#aria-orientation>
#$Data->{attrs}->{'aria-orientation'}->{default} = 'horizontal'; # 1.0
$Data->{attrs}->{'aria-orientation'}->{default} = 'undefined'; # 1.1

## The aria-keyshortcuts attribute has complex value constraints not
## formalized here:
## <https://w3c.github.io/aria/aria/aria.html#aria-keyshortcuts>.

print perl2json_bytes_for_record $Data;

## License: Public Domain.
