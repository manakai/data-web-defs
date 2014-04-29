use strict;
use warnings;
use JSON::PS;

my $Data = {};

## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-concepts/index.html#h3_xsd-datatypes>
for (qw(
  xsd:string xsd:boolean xsd:decimal xsd:integer xsd:double xsd:float
  xsd:date xsd:time xsd:dateTime xsd:dateTimeStamp xsd:gYear
  xsd:gMonth xsd:gDay xsd:gYearMonth xsd:gMonthDay xsd:duration
  xsd:yearMonth xsd:dayTimeDuration xsd:byte xsd:short xsd:int
  xsd:long xsd:unsignedByte xsd:unsignedShort xsd:unsignedInt
  xsd:unsignedLong xsd:positiveInteger xsd:nonNegativeInteger
  xsd:negativeInteger xsd:nonPositiveInteger xsd:hexBinary
  xsd:base64Binary xsd:anyURI xsd:language xsd:normalizedString
  xsd:token xsd:NMTOKEN xsd:Name xsd:NCName
)) {
  my $s = $_;
  $s =~ s/^xsd://;
  $Data->{datatypes}->{"http://www.w3.org/2001/XMLSchema#$s"}->{rdf} = 'builtin';
}
for (qw(
  xsd:QName xsd:ENTITY xsd:ID xsd:IDREF xsd:NOTATION xsd:IDREFS
  xsd:ENTITIES xsd:NMTOKENS
)) {
  my $s = $_;
  $s =~ s/^xsd://;
  $Data->{datatypes}->{"http://www.w3.org/2001/XMLSchema#$s"}->{rdf} = 'unsuitable';
}
$Data->{datatypes}->{"http://www.w3.org/1999/02/22-rdf-syntax-ns#HTML"}->{rdf} = '1';
$Data->{datatypes}->{"http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral"}->{rdf} = '1';
$Data->{datatypes}->{"http://www.w3.org/1999/02/22-rdf-syntax-ns#langString"}->{rdf} = 'special';

## <http://www.w3.org/TR/rdf-plain-literal/>
$Data->{datatypes}->{"http://www.w3.org/1999/02/22-rdf-syntax-ns#PlainLiteral"}->{rdf} = 'special';

print perl2json_bytes_for_record $Data;

## License: Public Domain.
