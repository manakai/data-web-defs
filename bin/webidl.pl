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
  callback interface partial dictionary enum typedef includes mixin const
  null true false -Infinity Infinity NaN getter stringifier namespace
  static attribute inherit readonly setter deleter
  iterable optional async
  ByteString Date
  DOMString RegExp any boolean byte double float long octet or object
  sequence short unsigned void unrestricted required maplike setlike
  Promise ArrayBuffer Int8Array Int16Array
  Int32Array Uint8Array Uint16Array Uint32Array Uint8ClampedArray
  Float32Array Float64Array DataView USVString
  FrozenArray

  record

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

## <https://heycam.github.io/webidl/#prod-ArgumentNameKeyword>
$Data->{keyword_tokens}->{$_}->{argument_name} = 1 for qw(
  attribute callback const deleter dictionary enum
  getter includes inherit interface namespace iterable
  maplike partial setlike setter static
  stringifier typedef unrestricted required
  async

  record
);
$Data->{keyword_tokens}->{$_}->{attribute_name} = 1 for qw(
  required
  async
);
$Data->{keyword_tokens}->{$_}->{operation_name} = 1 for qw(
  includes
);

for (
  [interface => 'interface', 'interface definition'],
  [partial_interface => 'interface', 'partial interface definition'],
  [interface_mixin => 'interface', 'interface mixin definition'],
  [partial_interface_mixin => 'interface', 'partial interface mixin definition'],
  [callback_interface => 'interface', 'callback interface definition'],
  [namespace => 'namespace', 'namespace definition'],
  [partial_namespace => 'namespace', 'partial namespace definition'],
  [dictionary => 'dictionary', 'dictionary definition'],
  [partial_dictionary => 'dictionary', 'partial dictionary definition'],
  [enum => 'enum', 'enumeration'],
  [callback => 'callback', 'callback function'],
  [typedef => 'typedef', 'typedef'],
  [includes => 'includes', 'includes statement'],
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
  [iterable => 'iterable', 'iterable declaration'],
  [async_iterable => 'iterable', 'asynchronously iterable declaration'],
  [maplike => 'maplike', 'maplike declaration'],
  [setlike => 'setlike', 'setlike declaration'],
) {
  $Data->{constructs}->{$_->[0]}->{interface_member} = 1;
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
    LegacyArrayClass => 1,
    Constructor => 1, Exposed => 1, Global => 1,
    NamedConstructor => 1,
    NoInterfaceObject => 1, OverrideBuiltins => 1,
    LegacyUnenumerableNamedProperties => 1,
    SecureContext => 1, HTMLConstructor => 1,
    Serializable => 1,
    Transferable => 1,
    LegacyWindowAlias => 1,
  },
  callback_interface => {
    Exposed => 1,
    SecureContext => 1,
  },
  partial_interface => {
    Exposed => 1, Global => 1, OverrideBuiltins => 1,
    SecureContext => 1,
    Serializable => 1,
    Transferable => 1,
  },
  interface_mixin => {
    Exposed => 1,
    SecureContext => 1,
  },
  partial_interface_mixin => {
    Exposed => 1,
    SecureContext => 1,
  },
  namespace => {
    Exposed => 1,
    SecureContext => 1,
  },
  partial_namespace => {
    Exposed => 1,
    SecureContext => 1,
  },
  const => {
    Exposed => 1,
    SecureContext => 1,
  },
  attribute => {
    Exposed => 1,
    SameObject => 1,
    LenientThis => 1, PutForwards => 1, Replaceable => 1, LenientSetter => 1,
    Unscopable => 1,
    SecureContext => 1, CEReactions => 1,
    Unforgeable => 1,
  },
  static_attribute => {
    Exposed => 1,
    SameObject => 1,
    SecureContext => 1,
  },
  operation => {
    Exposed => 1, NewObject => 1,
    Unscopable => 1,
    SecureContext => 1, CEReactions => 1,
    Unforgeable => 1,
    Default => 1,
  },
  static_operation => {
    Exposed => 1, NewObject => 1,
    SecureContext => 1,
  },
  argument => {},
  iterable => {
    Exposed => 1,
    SecureContext => 1,
  },
  async_iterable => {
    Exposed => 1,
    SecureContext => 1,
  },
  maplike => {
    SecureContext => 1,
  },
  setlike => {
    SecureContext => 1,
  },
  dictionary => {},
  partial_dictionary => {},
  dictionary_member => {},
  enum => {},
  callback => {
    TreatNonObjectAsNull => 1,
  },
  typedef => {},
  includes => {},
};

for my $key (keys %$XAttrAllowed) {
  for my $name (keys %{$XAttrAllowed->{$key}}) {
    $Data->{constructs}->{$key}->{allowed_extended_attributes}->{$name} = 1;
  }
}

my $XAttrArgs = {
  LegacyArrayClass => {no => 1},
  Clamp => {no => 1},
  Constructor => {no => 1, args => 1},
  EnforceRange => {no => 1},
  LenientThis => {no => 1},
  NewObject => {no => 1},
  NoInterfaceObject => {no => 1},
  OverrideBuiltins => {no => 1},
  PutForwards => {id => 1},
  Replaceable => {no => 1},
  SameObject => {no => 1},
  TreatNonObjectAsNull => {no => 1}, # No MUST in spec
  TreatNullAs => {id => 1},
  Global => {no => 1, id => 1, id_list => 1}, # 'id' not allowed in spec
  Exposed => {id => 1, id_list => 1},
  NamedConstructor => {id => 1, named_args => 1},
  Unscopable => {no => 1},
  LegacyUnenumerableNamedProperties => {no => 1},
  SecureContext => {no => 1},
  LenientSetter => {no => 1},
  CEReactions => {no => 1},
  HTMLConstructor => {no => 1},
  Serializable => {no => 1},
  Transferable => {no => 1},
  AllowShared => {no => 1},
  Unforgeable => {no => 1},
  LegacyWindowAlias => {id => 1, id_list => 1},
  Default => {no => 1},
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
  ['HTMLConstructor', 'Constructor'],
  ['HTMLConstructor', 'NoInterfaceObject'],
  ['LegacyWindowAlias', 'NoInterfaceObject'],
  ['OverrideBuiltins', 'Global'],
  ['PutForwards', 'Replaceable'],
  ['LenientSetter', 'PutForwards'],
  ['LenientSetter', 'Replaceable'],
  ['Global', 'Constructor'],
  ['Global', 'NamedConstructor'],
];

for (@$XAttrDisallowedCombinations) {
  $Data->{extended_attributes}->{$_->[0]}->{disallowed_extended_attributes}->{$_->[1]} = 1;
  $Data->{extended_attributes}->{$_->[1]}->{disallowed_extended_attributes}->{$_->[0]} = 1;
}

## <https://heycam.github.io/webidl/#dfn-reserved-identifier>
my $ReservedIdentifiers = {
  constructor => 1, iterator => 1, toString => 1,
};
my $Reserved = {
  const => {prototype => 1},
  attribute => {prototype => 1},
  static_attribute => {prototype => 1},
  operation => {prototype => 1},
  static_operation => {prototype => 1},
};

for my $name (keys %$ReservedIdentifiers) {
  $Data->{constructs}->{$_}->{reserved}->{$name} = 1
      for qw(interface partial_interface callback_interface
             interface_mixin partial_interface_mixin
             dictionary partial_dictionary
             enum callback typedef const attribute
             static_attribute dictionary_member
             operation static_operation argument
             );
}
for (keys %$Reserved) {
  for my $name (keys %{$Reserved->{$_}}) {
    $Data->{constructs}->{$_}->{reserved}->{$name} = 1;
  }
}

## <https://heycam.github.io/webidl/#idl-types>.
$Data->{types}->{$_}->{integer_type} = 1,
$Data->{types}->{$_}->{numeric_type} = 1,
$Data->{types}->{$_}->{primitive_type} = 1
    for qw(byte octet short long), 'unsigned short', 'unsigned long',
        'long long', 'unsigned long long';
$Data->{types}->{$_}->{numeric_type} = 1,
$Data->{types}->{$_}->{primitive_type} = 1
    for 'boolean';
$Data->{types}->{$_}->{string_type} = 1
    for qw(DOMString ByteString USVString);
$Data->{constructs}->{enum}->{string_type} = 1;
$Data->{types}->{$_}->{exception_type} = 1,
$Data->{types}->{$_}->{object_type} = 1
    for qw(DOMException);
$Data->{types}->{$_}->{typed_array_type} = 1,
$Data->{types}->{$_}->{buffer_source_type} = 1
    for qw(Int8Array Int16Array Int32Array Uint8Array Uint16Array
           Uint32Array Uint8ClampedArray Float32Array Float64Array);
$Data->{types}->{$_}->{buffer_source_type} = 1
    for qw(ArrayBuffer DataView);
$Data->{types}->{$_}->{object_type} = 1
    for qw(object);
$Data->{constructs}->{interface}->{object_type} = 1;
$Data->{constructs}->{callback_interface}->{object_type} = 1;
#partial_interface

$Data->{types}->{$_}->{allowed_extended_attributes}->{Clamp} = 1,
$Data->{types}->{$_}->{allowed_extended_attributes}->{EnforceRange} = 1
    for grep { $Data->{types}->{$_}->{integer_type} } keys %{$Data->{types}};
$Data->{types}->{DOMString}->{allowed_extended_attributes}->{TreatNullAs} = 1;
$Data->{types}->{$_}->{allowed_extended_attributes}->{AllowShared} = 1
    for grep { $Data->{types}->{$_}->{buffer_source_type} } keys %{$Data->{types}};

print perl2json_bytes_for_record $Data;

## License: Public Domain.
