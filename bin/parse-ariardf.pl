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

## <http://w3c.github.io/aria/aria/aria.html#searchbox>
push @$Triples, ['searchbox', $subClassOf, 'textbox'];

## <http://w3c.github.io/aria/aria/aria.html#switch>
push @$Triples, ['switch', $subClassOf, 'checkbox'];

# XXX equivalent
push @$Triples, ['none', $subClassOf, 'presentation'];

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

print perl2json_bytes_for_record $Data;

## License: Public Domain.
