use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib')->stringify;
use JSON::PS;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::RDF::XML::Parser;

my $Data = {};

sub _v ($) {
  return defined $_[0]->{url} ? $_[0]->{url} :
         defined $_[0]->{lexical} ? $_[0]->{lexical} : $_[0];
} # _v

my $Triples = [];
{
  my $f = path (__FILE__)->parent->parent->child ('local/aria.rdf');
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_char_string ($f->slurp_utf8 => $doc);
  my $rdfparser = Web::RDF::XML::Parser->new;
  $rdfparser->ontriple (sub {
    my %args = @_;
    push @$Triples, [_v $args{subject}, _v $args{predicate}, _v $args{object}];
  });
  $rdfparser->convert_document ($doc);
}

my $subClassOf = "http://www.w3.org/2000/01/rdf-schema#subClassOf";

## <http://w3c.github.io/aria/aria/aria.html#text>
push @$Triples, ['text', $subClassOf, 'structure'];

## <http://w3c.github.io/aria/aria/aria.html#searchbox>
push @$Triples, ['searchbox', $subClassOf, 'textbox'];

## <http://w3c.github.io/aria/aria/aria.html#switch>
push @$Triples, ['switch', $subClassOf, 'checkbox'];

## <https://github.com/w3c/aria/commit/ad45423151fb13accd8776c1a04d911e6ee81623>
@$Triples = grep {
  not ($_->[0] =~ /#(?:section|alert|grid|landmark|list|log|status|tabpanel|article)$/ and
       $_->[1] eq $subClassOf);
} @$Triples;
push @$Triples, ['section', $subClassOf, 'structure'];
push @$Triples, ['alert', $subClassOf, 'section'];
push @$Triples, ['grid', $subClassOf, 'composite'];
push @$Triples, ['grid', $subClassOf, 'section'];
push @$Triples, ['landmark', $subClassOf, 'section'];
push @$Triples, ['list', $subClassOf, 'section'];
push @$Triples, ['log', $subClassOf, 'section'];
push @$Triples, ['status', $subClassOf, 'section'];
push @$Triples, ['tabpanel', $subClassOf, 'section'];
push @$Triples, ['article', $subClassOf, 'document'];

$Data->{roles}->{roletype} = {};
while (1) {
  my $new;
  for my $triple (@$Triples) {
    my $super;
    if ($triple->[1] eq $subClassOf and
        do {
          $super = $triple->[2];
          $super =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
          !!$Data->{roles}->{$super};
        }) {
      my $role = $triple->[0];
      $role =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};

      ## <http://rawgit.com/w3c/aria/master/spec/aria.html#h2_changelog>
      next if $role eq 'radio' and $super eq 'option';

      $new = 1 unless $Data->{roles}->{$role};
      $Data->{roles}->{$role}->{subclass_of}->{$super} = 1;
      $Data->{roles}->{$role}->{subclass_of}->{$_} = $Data->{roles}->{$super}->{subclass_of}->{$_} + 1
          for sort { $a cmp $b } keys %{$Data->{roles}->{$super}->{subclass_of}};
    }
  }
  last unless $new;
}

## <https://w3c.github.io/aria/aria/aria.html#abstract_roles>
$Data->{roles}->{$_}->{abstract} = 1
    for qw(command composite input landmark range roletype section
           sectionhead select structure widget window);

for my $triple (@$Triples) {
  if ($triple->[1] eq "http://www.w3.org/1999/xhtml/vocab#supportedState") {
    my $role = $triple->[0];
    $role =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    my $state = $triple->[2];
    $state =~ s{^\Qhttp://www.w3.org/2005/07/aaa#\E}{};
    $Data->{roles}->{$role}->{attrs}->{$state} ||= {};
    $Data->{attrs}->{$state} ||= {};
  } elsif ($triple->[1] eq "http://www.w3.org/1999/xhtml/vocab#requiredState") {
    my $role = $triple->[0];
    $role =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    my $state = $triple->[2];
    $state =~ s{^\Qhttp://www.w3.org/2005/07/aaa#\E}{};
    $Data->{roles}->{$role}->{attrs}->{$state}->{must} = 1;
    $Data->{attrs}->{$state} ||= {};
  } elsif ($triple->[1] eq 'http://www.w3.org/1999/xhtml/vocab#mustContain') {
    my $role = $triple->[0];
    $role =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    my $role2 = $triple->[2];
    $role2 =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    $Data->{roles}->{$role}->{must_contain}->{$role2} = 1;
  } elsif ($triple->[1] eq 'http://www.w3.org/1999/xhtml/vocab#scope') {
    my $role = $triple->[0];
    $role =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    my $role2 = $triple->[2];
    $role2 =~ s{^\Qhttp://www.w3.org/WAI/ARIA/Schemata/aria-1#\E}{};
    $Data->{roles}->{$role}->{scope}->{$role2} = 1;
  }
}

## <http://rawgit.com/w3c/aria/master/spec/aria.html#h2_changelog>
$Data->{roles}->{radio}->{attrs}->{'aria-posinset'} ||= {};
$Data->{roles}->{radio}->{attrs}->{'aria-setsize'} ||= {};
$Data->{roles}->{tab}->{attrs}->{'aria-posinset'} ||= {};
$Data->{roles}->{tab}->{attrs}->{'aria-setsize'} ||= {};

## <http://w3c.github.io/aria/aria/aria.html#aria-modal>
$Data->{roles}->{window}->{attrs}->{'aria-modal'} ||= {};

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
$Data->{roles}->{scrollbar}->{attrs}->{'aria-controls'}->{must} = 1;

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

## <https://www.w3.org/WAI/PF/aria/complete#index_state_prop>
$Data->{attrs}->{$_}->{is_state} = 1
    for qw(aria-busy aria-checked aria-disabled aria-expanded
           aria-grabbed aria-hidden aria-invalid aria-pressed aria-selected);

## <https://w3c.github.io/aria/aria/aria.html#aria-current>
$Data->{attrs}->{$_}->{is_state} = 1,
$Data->{roles}->{roletype}->{attrs}->{$_} ||= {},
    for qw(aria-current);

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
    aria-haspopup true/false
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

## <http://w3c.github.io/aria/aria/aria.html#aria-current>
$Data->{attrs}->{'aria-current'}->{tokens}->{$_} = {}
    for qw(page step location date time true false);
$Data->{attrs}->{'aria-current'}->{default} = 'false';

## <http://rawgit.com/w3c/aria/master/spec/aria.html#aria-orientation>
#$Data->{attrs}->{'aria-orientation'}->{default} = 'horizontal'; # 1.0
$Data->{attrs}->{'aria-orientation'}->{default} = 'undefined'; # 1.1

$Data->{attrs}->{'aria-describedat'}->{preferred} = {type => 'html_element', name => 'a'};

## <http://w3c.github.io/aria/aria/aria.html#aria-modal>
$Data->{attrs}->{'aria-modal'}->{preferred} = {type => 'html_element', name => 'dialog'};

## <http://rawgit.com/w3c/aria/master/spec/aria.html#h2_changelog>
$Data->{roles}->{none} = $Data->{roles}->{presentation};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
