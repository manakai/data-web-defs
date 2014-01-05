use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record);
use Encode;
use Web::DOM::Document;
use Web::HTML::Microdata;

my $Data = {};

sub min ($$) {
  return $_[1] if not defined $_[0];
  return $_[1] < $_[0] ? $_[1] : $_[0];
} # min

my $f = file (__FILE__)->dir->parent->file ('local', 'schemaorg.html');
my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
$doc->inner_html (decode 'utf-8', scalar $f->slurp);
$doc->inner_html ($doc->body->text_content);
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

for my $id (keys %$Data) {
  my @super = keys %{$Data->{$id}->{subclass_of} or {}};
  while (@super) {
    my $super = shift @super;
    for (keys %{$Data->{$super}->{subclass_of} or {}}) {
      next if $Data->{$id}->{subclass_of}->{$_};
      $Data->{$id}->{subclass_of}->{$_}
          = min ($Data->{$id}->{subclass_of}->{$_}, $Data->{$id}->{subclass_of}->{$super} + $Data->{$super}->{subclass_of}->{$_});
      push @super, $_;
    }
  }
  $Data->{$id}->{subclass_of}->{$id} = 0;

  my @sub = keys %{$Data->{$id}->{superclass_of} or {}};
  while (@sub) {
    my $sub = shift @sub;
    for (keys %{$Data->{$sub}->{superclass_of} or {}}) {
      next if $Data->{$id}->{superclass_of}->{$_};
      $Data->{$id}->{superclass_of}->{$_}
          = min ($Data->{$id}->{superclass_of}->{$_}, $Data->{$id}->{superclass_of}->{$sub} + $Data->{$sub}->{superclass_of}->{$_});
      push @sub, $_;
    }
  }
  $Data->{$id}->{superclass_of}->{$id} = 0;
}

for my $id (keys %$Data) {
  for my $key (qw(types)) {
    for my $type (keys %{$Data->{$id}->{$key} or {}}) {
      $Data->{$id}->{$key}->{$_}
          = min ($Data->{$id}->{$key}->{$_}, 1 + $Data->{$type}->{subclass_of}->{$_})
              for keys %{$Data->{$type}->{subclass_of} or {}};
    }
  }
  for my $key (qw(domain range)) {
    for my $type (keys %{$Data->{$id}->{$key} or {}}) {
      $Data->{$id}->{$key}->{$_}
          = min ($Data->{$id}->{$key}->{$_}, 1 + $Data->{$type}->{superclass_of}->{$_})
              for keys %{$Data->{$type}->{superclass_of} or {}};
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
