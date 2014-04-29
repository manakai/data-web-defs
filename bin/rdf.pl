use strict;
use warnings;
use JSON::PS;

my $Data = {};

## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#section-Namespace>
$Data->{rdf_vocab}->{$_}->{type} = 'syntax'
    for qw(RDF Description ID about parseType resource li nodeID datatype);
$Data->{rdf_vocab}->{$_}->{type} = 'class'
    for qw(Seq Bag Alt Statement Property XMLLiteral List);
$Data->{rdf_vocab}->{$_}->{type} = 'property'
    for qw(subject predicate object type value first rest); # _n
$Data->{rdf_vocab}->{$_}->{type} = 'resource'
    for qw(nil);

## <http://www.w3.org/TR/rdf11-concepts/#dfn-rdf-html>
$Data->{rdf_vocab}->{$_}->{type} = 'class'
    for qw(HTML);

## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#oldTerms>
$Data->{rdf_vocab}->{$_}->{type} = 'obsolete'
    for qw(aboutEach aboutEachPrefix bagID);

## <http://www.w3.org/TR/rdf-plain-literal/>
$Data->{rdf_vocab}->{$_}->{type} = 'obsolete'
    for qw(PlainLiteral);

print perl2json_bytes_for_record $Data;

## License: Public Domain.
