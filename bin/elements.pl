use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $Data = {};

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'html-extracted.json');
  my $json = file2perl $f;
  for my $el_name (keys %{$json->{elements}}) {
    my $in = $json->{elements}->{$el_name};
    my $prop = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} ||= {};
    $prop->{conforming} = 1;
    for (qw(desc start_tag end_tag id)) {
      $prop->{$_} = $in->{$_} if defined $in->{$_};
    }
    if ($in->{content_model}) {
      if (not $in->{content_model}->{_complex} and
          1 == keys %{$in->{content_model}}) {
        $prop->{content_model} = each %{$in->{content_model}};
      }
    }
    for (keys %{$in->{categories} or {}}) {
      next if $_ eq '_complex';
      $Data->{categories}->{$_}->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el_name} = 1;
    }
    for my $attr_name (keys %{$in->{attrs} or {}}) {
      my $i = $in->{attrs}->{$attr_name};
      my $p = $prop->{attrs}->{''}->{$attr_name} ||= {};
      $p->{conforming} = 1;
      $p->{desc} = $i->{desc} if defined $i->{desc};
      $p->{id} = $i->{id} if defined $i->{id};
    }
  }
  for my $attr_name (keys %{$json->{global_attrs} or {}}) {
    my $prop = $json->{global_attrs}->{$attr_name};
    my $p = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{'*'}->{attrs}->{''}->{$attr_name} ||= {};
    $p->{conforming} = 1;
    $p->{desc} = $prop->{desc} if defined $prop->{desc};
    $p->{id} = $prop->{id} if defined $prop->{id};
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'element-interfaces.txt');
  my $ns = '';
  my $ln = '*';
  for (($f->slurp)) {
    if (/^\@ns (\S+)$/) {
      $ns = $1;
    } elsif (/^(\S+)\s(\S+)$/) {
      $ln = $1;
      $Data->{elements}->{$ns}->{$ln}->{interface} = $2;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'elements.txt');
  for (($f->slurp)) {
    if (/^([^=]+)=(.+)$/) {
      my $value = $2;
      my @path = split /\|/, $1, -1;
      my $name = pop @path;
      my $data = $Data;
      for (@path) {
        $data = $data->{$_} ||= {};
      }
      $data->{$name} = $value;
    } elsif (/\S/) {
      die "Broken data |$_|";
    }
  }
}

use Encode;
use Web::DOM::Document;
use Web::XML::Parser;
my $statuses = {};
{
  my $doc = Web::DOM::Document->new;
  {
    my $f = file (__FILE__)->dir->parent->file ('local', 'html-status.xml');
    Web::XML::Parser->new->parse_char_string
        ((decode 'utf-8', scalar $f->slurp) => $doc);
  }
  for (@{$doc->query_selector_all ('annotations > entry[section][status]')}) {
    $statuses->{$_->get_attribute ('section')} = $_->get_attribute ('status');
  }
}

for my $ns (keys %{$Data->{elements}}) {
  for my $ln (keys %{$Data->{elements}->{$ns}}) {
    my $v = $Data->{elements}->{$ns}->{$ln};
    if ($v->{id} and $statuses->{$v->{id}}) {
      $v->{status} ||= $statuses->{$v->{id}};
      delete $v->{status} if $v->{status} eq 'UNKNOWN';
    }

    for my $ans (keys %{$v->{attrs} || {}}) {
      for my $aln (keys %{$v->{attrs}->{$ans}}) {
        my $w = $v->{attrs}->{$ans}->{$aln};
        if ($w->{id} and $statuses->{$w->{id}}) {
          $w->{status} ||= $statuses->{$w->{id}};
          delete $w->{status} if $w->{status} eq 'UNKNOWN';
        }
      }
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
