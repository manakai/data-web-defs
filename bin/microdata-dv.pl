use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::PS;
use Encode;
use Web::DOM::Document;
use Web::HTML::Microdata;

my $Data = {};

for (qw(itemtype itemprop Event Geo Address Organization Person
        Product Review Review-aggregate Breadcrumb
        Offer Offer-aggregate Recipe)) {
  my $src = {type => "http://data-vocabulary.org/$_",
             url => "http://www.data-vocabulary.org/$_/",
             file_name => "$_.html"};
  my $f = file (__FILE__)->dir->parent->file ('local', 'data-vocabulary', $src->{file_name});
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $f->slurp);
  my $md = Web::HTML::Microdata->new;
  my $vocab = $Data->{$src->{type}} ||= {};
  $vocab->{url} = $src->{url};
  $vocab->{spec} = 'DATAVOCAB';
  for my $item (@{$md->get_top_level_items ($doc)}) {
    if ($item->{types}->{'http://data-vocabulary.org/itemtype'}) {
      $vocab->{spec} = 'DATAVOCAB';
      $vocab->{id} = $item->{id};
      for my $propitem (@{$item->{props}->{itemprop} or []}) {
        my $name = $propitem->{props}->{name}->[0]->{text};
        $name =~ s/\s+\([^()]+\)\s*$//g;
        my $propdef = $vocab->{props}->{$name} ||= {};
        $propdef->{spec} = 'DATAVOCAB';
        $propdef->{id} = $propitem->{id};

        if (($propitem->{props}->{description}->[0]->{text} // '') =~ /^\s*Required\./) {
          $propdef->{min} = 1;
        }
      }
    } elsif ($item->{types}->{'http://data-vocabulary.org/itemprop'}) {
      my $propdef = $vocab->{props}->{$item->{props}->{name}->[0]->{text}} ||= {};
      $propdef->{spec} = 'DATAVOCAB';
      $propdef->{id} = $item->{id};
    }
  }
}

## "ISO date" in the spec is replaced by "date string or global date and time string".
## "ISO duration" in the spec is replaced by "vevent duration".
## |is_url| flag is set if the value is defined as a URL, image, or link.
$Data->{'http://data-vocabulary.org/itemtype'}->{use_itemid} = 1;
$Data->{'http://data-vocabulary.org/itemprop'}->{use_itemid} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{url}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{startDate}->{value} ||= 'date string or global date and time string';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{endDate}->{value} ||= 'date string or global date and time string';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{duration}->{value} ||= 'vevent duration';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{location}->{value} ||= 'text';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{location}->{item}->{types}->{'http://data-vocabulary.org/Organization'} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{location}->{item}->{types}->{'http://data-vocabulary.org/Address'} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{geo}->{item}->{types}->{'http://data-vocabulary.org/Geo'} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{tickets}->{spec} = 'DATAVOCAB';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{tickets}->{url} = 'https://support.google.com/webmasters/answer/164506?ref_topic=1088474';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{tickets}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{tickets}->{item}->{types}->{'http://data-vocabulary.org/Offer'} = 1;
$Data->{'http://data-vocabulary.org/Event'}->{props}->{ticketAggregate}->{spec} = 'DATAVOCAB';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{ticketAggregate}->{url} = 'https://support.google.com/webmasters/answer/164506?ref_topic=1088474';
$Data->{'http://data-vocabulary.org/Event'}->{props}->{ticketAggregate}->{item}->{types}->{'http://data-vocabulary.org/Offer-aggregate'} = 1;
$Data->{'http://data-vocabulary.org/Organization'}->{props}->{url}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Organization'}->{props}->{address}->{item}->{types}->{'http://data-vocabulary.org/Address'} = 1;
$Data->{'http://data-vocabulary.org/Organization'}->{props}->{geo}->{item}->{types}->{'http://data-vocabulary.org/Geo'} = 1;
$Data->{'http://data-vocabulary.org/Person'}->{props}->{address}->{item}->{types}->{'http://data-vocabulary.org/Address'} = 1;
$Data->{'http://data-vocabulary.org/Person'}->{props}->{photo}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Person'}->{props}->{url}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Product'}->{props}->{review}->{item}->{types}->{'http://data-vocabulary.org/Review'} = 1;
$Data->{'http://data-vocabulary.org/Product'}->{props}->{review}->{item}->{types}->{'http://data-vocabulary.org/Review-aggregate'} = 1;
$Data->{'http://data-vocabulary.org/Product'}->{props}->{offerdetails}->{item}->{types}->{'http://data-vocabulary.org/Offer'} = 1;
$Data->{'http://data-vocabulary.org/Product'}->{props}->{offerdetails}->{item}->{types}->{'http://data-vocabulary.org/Offer-aggregate'} = 1;
$Data->{'http://data-vocabulary.org/Review'}->{props}->{dtreviewed}->{value} ||= 'date string or global date and time string';
$Data->{'http://data-vocabulary.org/Review'}->{props}->{rating}->{value} ||= 'text';
$Data->{'http://data-vocabulary.org/Review'}->{props}->{rating}->{item}->{types}->{'http://data-vocabulary.org/Rating'} = 1;
$Data->{'http://data-vocabulary.org/Review-aggregate'}->{props}->{rating}->{value} ||= 'text';
$Data->{'http://data-vocabulary.org/Review-aggregate'}->{props}->{rating}->{item}->{types}->{'http://data-vocabulary.org/Rating'} = 1;
$Data->{'http://data-vocabulary.org/Breadcrumb'}->{props}->{url}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Breadcrumb'}->{props}->{child}->{item}->{types}->{'http://data-vocabulary.org/Breadcrumb'} = 1;
$Data->{'http://data-vocabulary.org/Offer'}->{props}->{price}->{value} ||= 'floating-point number';
$Data->{'http://data-vocabulary.org/Offer'}->{props}->{currency}->{value} ||= 'currency';
$Data->{'http://data-vocabulary.org/Offer'}->{props}->{priceValidUntil}->{value} ||= 'date string or global date and time string';
$Data->{'http://data-vocabulary.org/Offer'}->{props}->{seller}->{item}->{types}->{'http://data-vocabulary.org/Person'} = 1;
$Data->{'http://data-vocabulary.org/Offer'}->{props}->{seller}->{item}->{types}->{'http://data-vocabulary.org/Organization'} = 1;
$Data->{'http://data-vocabulary.org/Offer-aggregate'}->{props}->{lowPrice}->{value} ||= 'floating-point number';
$Data->{'http://data-vocabulary.org/Offer-aggregate'}->{props}->{highPrice}->{value} ||= 'floating-point number';
$Data->{'http://data-vocabulary.org/Offer-aggregate'}->{props}->{currency}->{value} ||= 'currency';
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{photo}->{is_url} = 1;
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{published}->{value} ||= 'date string or global date and time string';
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{review}->{item}->{types}->{'http://data-vocabulary.org/Review'} = 1;
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{review}->{item}->{types}->{'http://data-vocabulary.org/Review-aggregate'} = 1;
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{prepTime}->{value} ||= 'vevent duration';
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{cookTime}->{value} ||= 'vevent duration';
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{totalTime}->{value} ||= 'vevent duration';
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{author}->{item}->{types}->{'http://data-vocabulary.org/Person'} = 1;
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{nutrition}->{item}->{types}->{'http://data-vocabulary.org/Nutrition'} = 1;
$Data->{'http://data-vocabulary.org/Recipe'}->{props}->{ingredient}->{item}->{types}->{'http://data-vocabulary.org/RecipeIngredient'} = 1;

print perl2json_bytes_for_record $Data;

## License: Public Domain.
