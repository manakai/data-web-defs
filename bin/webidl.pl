use strict;
use warnings;
use JSON::PS;

my $Data = {};

for (
  [integer => '-?([1-9][0-9]*|0[Xx][0-9A-Fa-f]+|0[0-7]*)', 3],
  [float => '-?(([0-9]+\.[0-9]*|[0-9]*\.[0-9]+)([Ee][+-]?[0-9]+)?|[0-9]+[Ee][+-]?[0-9]+)', 4],
  [identifier => '_?[A-Za-z][0-9A-Z_a-z-]*', 2],
  [string => '"[^"]*"', 2],
  [whitespace => '[\x09\x0A\x0D\x20]+', 2],
  [comment => '//.*|/\*(?:.|\x0A)*?\*/', 2],
  [other => '[^\x09\x0A\x0D\x200-9A-Za-z]', 1],
) {
  $Data->{tokens}->{$_->[0]}->{pattern} = $_->[1];
  $Data->{tokens}->{$_->[0]}->{priority} = $_->[2];
}

for (qw(
  callback interface partial dictionary enum typedef implements const
  null true false -Infinity Infinity NaN serializer getter stringifier
  static attribute inherit readonly setter creator deleter
  legacycaller legacyiterable iterable optional ByteString Date
  DOMString RegExp any boolean byte double float long octet or
  sequence short unsigned void unrestricted required maplike setlike
  Promise Error DOMException ArrayBuffer Int8Array Int16Array
  Int32Array Uint8Array Uint16Array Uint32Array Uint8ClampedArray
  Float32Array Float64Array DataView

  class extends

  { } ( ) [ ] ; = : ... - . < > ?
), ',') {
  if ($_ =~ /\A_?[A-Za-z][0-9A-Z_a-z]*\z/) {
    $Data->{keyword_tokens}->{$_} = {};
  } elsif ($_ =~ /\A[^\x09\x0A\x0D\x200-9A-Za-z]\z/) {
    $Data->{other_tokens}->{$_} = 1;
  } else {
    $Data->{tokens}->{$_}->{value} = $_;
    $Data->{tokens}->{$_}->{priority} = 10 + length $_;
  }
}

## <http://heycam.github.io/webidl/#prod-ArgumentNameKeyword>
$Data->{keyword_tokens}->{$_}->{argument_name} = 1 for qw(
  attribute callback const creator deleter dictionary enum
  getter implements inherit interface iterable legacycaller
  legacyiterable maplike partial serializer setlike setter static
  stringifier typedef unrestricted required

  class extends
);
$Data->{keyword_tokens}->{$_}->{attribute_name} = 1 for qw(
  required
);

## "class" and "extends" are not in spec but extended at:
## <http://dom.spec.whatwg.org/#elements>,
## <https://www.w3.org/Bugs/Public/show_bug.cgi?id=23225>.

for (
  [interface => 'interface', 'interface'],
  [partial_interface => 'interface', 'partial interface definition'],
  [callback_interface => 'interface', 'callback interface'],
  [dictionary => 'dictionary', 'dictionary'],
  [partial_dictionary => 'dictionary', 'partial dictionary definition'],
  [exception => 'exception', 'exception'],
  [enum => 'enum', 'enumeration'],
  [callback => 'callback', 'callback function'],
  [typedef => 'typedef', 'typedef'],
  [implements => 'implements', 'implements statement'],
  [class => 'class', 'class'],
) {
  $Data->{constructs}->{$_->[0]}->{definition} = 1;
  $Data->{constructs}->{$_->[0]}->{keyword} = $_->[1];
  $Data->{constructs}->{$_->[0]}->{name} = $_->[2];
}

for (
  [const => 'const', 'constant'],
  [attribute => 'attribute', 'regular attribute'],
  [static_attribute => 'attribute', 'static attribute'],
  [operation => undef, 'operation'],
  [static_operation => undef, 'static operation'],
  [serializer => 'serializer', 'serializer'],
  [iterator => 'iterator', 'iterator'],
  [iterator_object => 'iterator', 'iterator object'],
) {
  $Data->{constructs}->{$_->[0]}->{interface_member} = 1;
  $Data->{constructs}->{$_->[0]}->{keyword} = $_->[1] if defined $_->[1];
}

for (
  [const => 'const', 'constant'],
  [field => undef, 'exception field'],
) {
  $Data->{constructs}->{$_->[0]}->{exception_member} = 1;
  $Data->{constructs}->{$_->[0]}->{keyword} = $_->[1] if defined $_->[1];
  $Data->{constructs}->{$_->[0]}->{name} = $_->[2];
}

for (
  [dictionary_member => undef, 'dictionary member'],
) {
  $Data->{constructs}->{$_->[0]}->{dictionary_member} = 1;
  $Data->{constructs}->{$_->[0]}->{name} = $_->[2];
}

for (
  [argument => undef, 'argument'],
  [extended_attribute => undef, 'extended attribute'],
) {
  $Data->{constructs}->{$_->[0]}->{name} = $_->[2];
}

my $XAttrAllowed = {
  interface => {
    ArrayClass => 1, Constructor => 1, Exposed => 1, Global => 1,
    ImplicitThis => 1, NamedConstructor => 1,
    NoInterfaceObject => 1, OverrideBuiltins => 1, PrimaryGlobal => 1,
    Unforgeable => 1,
  },
  callback_interface => {
    ArrayClass => 1, Exposed => 1, Global => 1,
    ImplicitThis => 1,
    NoInterfaceObject => 1, OverrideBuiltins => 1, PrimaryGlobal => 1,
    Unforgeable => 1,
  },
  partial_interface => {
    Exposed => 1, Global => 1, OverrideBuiltins => 1,
    PrimaryGlobal => 1, Unforgeable => 1,
  },
  const => {
    Exposed => 1,
  },
  attribute => {
    Clamp => 1, EnforceRange => 1, Exposed => 1,
    SameObject => 1, TreatNullAs => 1,
    LenientThis => 1, PutForwards => 1, Replaceable => 1,
    Unforgeable => 1, Unscopeable => 1,
  },
  static_attribute => {
    Clamp => 1, Exposed => 1,
    SameObject => 1, TreatNullAs => 1,
  },
  operation => {
    Exposed => 1, NewObject => 1, TreatNullAs => 1, Unforgeable => 1,
    Unscopeable => 1,
  },
  static_operation => {
    Exposed => 1, NewObject => 1, TreatNullAs => 1,
  },
  argument => {
    Clamp => 1, EnforceRange => 1, TreatNullAs => 1,
  },
  serializer => {},
  iterator => { # XXX
    Exposed => 1,
  },
  iterator_object => {}, # XXX
  dictionary => {
    Constructor => 1, Exposed => 1,
  },
  partial_dictionary => {},
  dictionary_member => {
    Clamp => 1, EnforceRange => 1,
  },
  exception => { # XXX
    NoInterfaceObject => 1,
  },
  field => {},
  enum => {},
  callback => {
    TreatNonObjectAsNull => 1,
    TreatNonCallableAsNull => 1,
  },
  typedef => {},
  implements => {},
};

for my $key (keys %$XAttrAllowed) {
  for my $name (keys %{$XAttrAllowed->{$key}}) {
    $Data->{constructs}->{$key}->{allowed_extended_attributes}->{$name} = 1;
  }
}

my $XAttrArgs = {
  ArrayClass => {no => 1},
  Clamp => {no => 1},
  Constructor => {no => 1, args => 1},
  EnforceRange => {no => 1},
  ImplicitThis => {no => 1},
  LenientThis => {no => 1},
  NewObject => {no => 1},
  NoInterfaceObject => {no => 1},
  OverrideBuiltins => {no => 1},
  PutForwards => {id => 1},
  Replaceable => {no => 1},
  SameObject => {no => 1},
  TreatNonObjectAsNull => {no => 1}, # No MUST in spec
  TreatNonCallableAsNull => {no => 1}, # No longer in spec
  TreatNullAs => {id => 1},
  Unforgeable => {no => 1},
  Global => {no => 1, id => 1, id_list => 1}, # 'id' not allowed in spec
  PrimaryGlobal => {no => 1, id => 1, id_list => 1}, # 'id' not allowed in spec
  Exposed => {id => 1, id_list => 1},
  NamedConstructor => {id => 1, named_args => 1},
  Unscopeable => {no => 1},
};

for my $name (keys %$XAttrArgs) {
  $Data->{extended_attributes}->{$name}->{args} = $XAttrArgs->{$name};
}

my $XAttrMultiple = {
  Constructor => 1,
  NamedConstructor => 1,
};

for my $name (keys %$XAttrMultiple) {
  $Data->{extended_attributes}->{$name}->{multiple} = 1 if $XAttrArgs->{$name};
}

my $XAttrDisallowedCombinations = [
  ['Clamp', 'EnforceRange'],
  ['Constructor', 'NoInterfaceObject'],
  ['OverrideBuiltins', 'Global'],
  ['OverrideBuiltins', 'PrimaryGlobal'],
  ['PutForwards', 'Replaceable'],
  ['Global', 'PrimaryGlobal'],
];

for (@$XAttrDisallowedCombinations) {
  $Data->{extended_attributes}->{$_->[0]}->{disallowed_extended_attributes}->{$_->[1]} = 1;
  $Data->{extended_attributes}->{$_->[1]}->{disallowed_extended_attributes}->{$_->[0]} = 1;
}

## <http://heycam.github.io/webidl/#dfn-reserved-identifier>
my $ReservedIdentifiers = {
  constructor => 1, iterator => 1, toString => 1, toJSON => 1,
};
my $Reserved = {
  const => {prototype => 1},
  attribute => {prototype => 1},
  static_attribute => {prototype => 1},
  operation => {prototype => 1},
  static_operation => {prototype => 1},
  exception => {Error => 1, EvalError => 1, RangeError => 1,
                ReferenceError => 1, SyntaxError => 1, TypeError => 1,
                URIError => 1},
  field => {name => 1, message => 1},
};

for my $name (keys %$ReservedIdentifiers) {
  $Data->{constructs}->{$_}->{reserved}->{$name} = 1
      for qw(interface partial_interface callback_interface
             dictionary partial_dictionary
             exception enum callback typedef const attribute
             static_attribute field dictionary_member
             operation static_operation argument
             class);
}
for (keys %$Reserved) {
  for my $name (keys %{$Reserved->{$_}}) {
    $Data->{constructs}->{$_}->{reserved}->{$name} = 1;
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
