use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use Encode;
use JSON::PS;
use Web::DOM::Document;

my $Data = {};

sub min ($$) {
  return $_[1] if not defined $_[0];
  return $_[1] < $_[0] ? $_[1] : $_[0];
} # min

if (1) {
  my $path = path (__FILE__)->parent->parent->child ('local/schemaorg.rdfa');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $path->slurp);

  for (@{$doc->query_selector_all ('div[resource]')}) {
    my $url = $_->get_attribute ('resource');

    my $type = $_->get_attribute ('typeof');
    if (defined $type) {
      $type = {'rdfs:Class' => 'http://schema.org/Type',
               'rdf:Property' => 'http://schema.org/Property'}->{$type} // $type;
      next if $type eq 'http://schema.org/Organization';
      $Data->{$url}->{types} = {$type => 1};
    }

    for (@{$_->query_selector_all ('[property]')}) {
      my $prop = $_->get_attribute ('property');
      my $value = $_->get_attribute ('href') // $_->text_content;
      if ($prop eq 'rdfs:subClassOf') {
        $Data->{$url}->{subclass_of}->{$value} = 1;
        $Data->{$value}->{superclass_of}->{$url} = 1;
      } elsif ($prop eq 'http://schema.org/domainIncludes') {
        $Data->{$url}->{domain}->{$value} = 1;
      } elsif ($prop eq 'http://schema.org/rangeIncludes') {
        $Data->{$url}->{range}->{$value} = 1;
      } elsif ($prop eq 'rdfs:comment') {
        my $el = $doc->create_element ('div');
        $el->inner_html ($value);
        my $r = $el->query_selector
            (':-manakai-contains("Related actions"), :-manakai-contains("Related to ")');
        $r->parent_node->remove_child ($r->next_sibling)
            if defined $r and $r->next_sibling;
        $r->parent_node->remove_child ($r) if defined $r;
        $Data->{$url}->{desc} = $el->text_content;
      }
    }
  }
}

if (0) {
  my $path = path (__FILE__)->parent->parent->child ('local/schemaorg.html');
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $path->slurp);
  $doc->inner_html ($doc->body->text_content);
  require Web::HTML::Microdata;
  my $md = Web::HTML::Microdata->new;
  my $items = $md->get_top_level_items ($doc);
  for my $item (@$items) {
    $Data->{$item->{id}}->{types} = $item->{types};
    for (@{$item->{props}->{subClassOf}}) {
      $Data->{$item->{id}}->{subclass_of}->{$_->{text}} = 1;
      $Data->{$_->{text}}->{superclass_of}->{$item->{id}} = 1;
    }
    for (@{$item->{props}->{domain}}) {
      $Data->{$item->{id}}->{domain}->{$_->{text}} = 1;
    }
    for (@{$item->{props}->{range}}) {
      $Data->{$item->{id}}->{range}->{$_->{text}} = 1;
    }
  }
}

for my $id (sort { $a cmp $b } keys %$Data) {
  my @super = sort { $a cmp $b } keys %{$Data->{$id}->{subclass_of} or {}};
  while (@super) {
    my $super = shift @super;
    for (sort { $a cmp $b } keys %{$Data->{$super}->{subclass_of} or {}}) {
      next if $Data->{$id}->{subclass_of}->{$_};
      $Data->{$id}->{subclass_of}->{$_}
          = min ($Data->{$id}->{subclass_of}->{$_}, $Data->{$id}->{subclass_of}->{$super} + $Data->{$super}->{subclass_of}->{$_});
      push @super, $_;
    }
  }
  $Data->{$id}->{subclass_of}->{$id} = 0;

  my @sub = sort { $a cmp $b } keys %{$Data->{$id}->{superclass_of} or {}};
  while (@sub) {
    my $sub = shift @sub;
    for (sort { $a cmp $b } keys %{$Data->{$sub}->{superclass_of} or {}}) {
      next if $Data->{$id}->{superclass_of}->{$_};
      $Data->{$id}->{superclass_of}->{$_}
          = min ($Data->{$id}->{superclass_of}->{$_}, $Data->{$id}->{superclass_of}->{$sub} + $Data->{$sub}->{superclass_of}->{$_});
      push @sub, $_;
    }
  }
  $Data->{$id}->{superclass_of}->{$id} = 0;
}

for my $id (sort { $a cmp $b } keys %$Data) {
  for my $key (qw(types)) {
    for my $type (sort { $a cmp $b } keys %{$Data->{$id}->{$key} or {}}) {
      $Data->{$id}->{$key}->{$_}
          = min ($Data->{$id}->{$key}->{$_}, 1 + $Data->{$type}->{subclass_of}->{$_})
              for sort { $a cmp $b } keys %{$Data->{$type}->{subclass_of} or {}};
    }
  }
  for my $key (qw(domain range)) {
    for my $type (sort { $a cmp $b } keys %{$Data->{$id}->{$key} or {}}) {
      $Data->{$id}->{$key}->{$_}
          = min ($Data->{$id}->{$key}->{$_}, 1 + $Data->{$type}->{superclass_of}->{$_})
              for sort { $a cmp $b } keys %{$Data->{$type}->{superclass_of} or {}};
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
