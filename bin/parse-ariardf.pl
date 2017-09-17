use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib')->stringify;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::RDF::XML::Parser;
use JSON::PS;

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
my $ARIAPrefix = q<http://www.w3.org/WAI/ARIA/Schemata/aria-1#>;

# XXX equivalent
push @$Triples, [$ARIAPrefix.'none', $subClassOf, $ARIAPrefix.'presentation'];

for my $triple (@$Triples) {
  if ($triple->[1] eq $subClassOf) {
    my $role = $triple->[0];
    $role =~ s{^\Q$ARIAPrefix\E}{}o or next;
    my $super = $triple->[2];
    $super =~ s{^\Q$ARIAPrefix\E}{}o or next;
    $Data->{roles}->{$role}->{subclass_of}->{$super} = 1;
  } elsif ($triple->[1] eq "http://www.w3.org/1999/xhtml/vocab#supportedState") {
    my $role = $triple->[0];
    $role =~ s{^\Q$ARIAPrefix\E}{}o or next;
    my $state = $triple->[2];
    $state =~ s{^\Qhttp://www.w3.org/2005/07/aaa#\E}{};
    $Data->{roles}->{$role}->{attrs}->{$state} ||= {};
    $Data->{attrs}->{$state} ||= {};
  } elsif ($triple->[1] eq "http://www.w3.org/1999/xhtml/vocab#requiredState") {
    my $role = $triple->[0];
    $role =~ s{^\Q$ARIAPrefix\E}{}o or next;
    my $state = $triple->[2];
    $state =~ s{^\Qhttp://www.w3.org/2005/07/aaa#\E}{};
    $Data->{roles}->{$role}->{attrs}->{$state}->{must} = 1;
    $Data->{attrs}->{$state} ||= {};
  } elsif ($triple->[1] eq 'http://www.w3.org/1999/xhtml/vocab#mustContain') {
    my $role = $triple->[0];
    $role =~ s{^\Q$ARIAPrefix\E}{}o or next;
    my $role2 = $triple->[2];
    $role2 =~ s{^\Q$ARIAPrefix\E}{}o or next;
    $Data->{roles}->{$role}->{must_contain}->{$role2} = 1;
  } elsif ($triple->[1] eq 'http://www.w3.org/1999/xhtml/vocab#scope') {
    my $role = $triple->[0];
    $role =~ s{^\Q$ARIAPrefix\E}{}o or next;
    my $role2 = $triple->[2];
    $role2 =~ s{^\Q$ARIAPrefix\E}{}o or next;
    $Data->{roles}->{$role}->{scope}->{$role2} = 1;
  }
} # $triple

print perl2json_bytes_for_record $Data;

## License: Public Domain.
