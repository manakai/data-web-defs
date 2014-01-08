use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $Data = file2perl file (__FILE__)->dir->parent->file ('src', 'microdata-dv.json');

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'microdata-vocabs.txt');
  my $itemtype;
  my $itemprop;
  my $subitemprop;
  my $key;
  my $subkey;
  for (($f->slurp)) {
    if (/^\*\s*(\S+)$/) {
      $itemtype = $1;
      $Data->{$itemtype} ||= {};
    } elsif (/^([^\s=:]+)=(.*)$/) {
      $Data->{$itemtype}->{$1} = $2;
    } elsif (/^([^\s=:]+)$/) {
      $itemprop = $1;
      $Data->{$itemtype}->{props}->{$itemprop} ||= {};
    } elsif (/^  ([0-9]+)\.\.([0-9]+|inf)$/) {
      $Data->{$itemtype}->{props}->{$itemprop}->{min} = 0+$1;
      $Data->{$itemtype}->{props}->{$itemprop}->{max} = 0+$2;
    } elsif (/^  ([^\s=:]+)=(.*)$/) {
      $Data->{$itemtype}->{props}->{$itemprop}->{$1} = $2;
    } elsif (/^  ([^\s=:]+)$/) {
      $Data->{$itemtype}->{props}->{$itemprop}->{$1} = 1;
    } elsif (/^  ([^\s=:]+):$/) {
      $key = $1;
      $Data->{$itemtype}->{props}->{$itemprop}->{$key} ||= {};
    } elsif (/^    ([^\s=:]+)=(.*)$/) {
      if ($1 eq 'type') {
        $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{types}->{$2} = 1;
      } else {
        $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{$1} = $2;
      }
    } elsif (/^    ([^\s=:]+)$/) {
      $subitemprop = $1;
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop} ||= {};
    } elsif (/^      ([0-9]+)\.\.([0-9]+|inf)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{min} = 0+$1;
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{max} = 0+$2;
    } elsif (/^      ([^\s=:]+)=(.*)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$1} = $2;
    } elsif (/^      ([^\s=:]+)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$1} = 1;
    } elsif (/^      ([^\s=:]+):$/) {
      $subkey = $1;
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey} ||= {};
    } elsif (/^        ([^\s=:]+)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey}->{$1} ||= {};
    } elsif (/\S/) {
      die "Broken line: |$_|";
    }
  }
}

for my $itemtype (keys %$Data) {
  if (($Data->{$itemtype}->{spec} // '') eq 'HTML') {
    my $id = $Data->{$itemtype}->{id};
    if (defined $id) {
      $Data->{$itemtype}->{id} = 'md-' . $id;
    }
    for my $itemprop (keys %{$Data->{$itemtype}->{props}}) {
      $Data->{$itemtype}->{props}->{$itemprop}->{spec} ||= 'HTML';
      $Data->{$itemtype}->{props}->{$itemprop}->{id} ||= 'md-' . $id . '-' . $itemprop;
      if ($Data->{$itemtype}->{props}->{$itemprop}->{enum} and
          not $itemtype eq 'http://microformats.org/profile/hcalendar#vevent') {
        for my $keyword (keys %{$Data->{$itemtype}->{props}->{$itemprop}->{enum} || {}}) {
          $Data->{$itemtype}->{props}->{$itemprop}->{enum}->{$keyword}->{spec} ||= 'HTML';
          $Data->{$itemtype}->{props}->{$itemprop}->{enum}->{$keyword}->{id} ||= 'md-' . $id . '-' . $itemprop . '-' . $keyword;
        }
      }
      if ($Data->{$itemtype}->{props}->{$itemprop}->{item}) {
        for my $subitemprop (keys %{$Data->{$itemtype}->{props}->{$itemprop}->{item}->{props} || {}}) {
          $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{spec} ||= 'HTML';
          $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{id} ||= 'md-' . $id . '-' . $itemprop . '-' . $subitemprop;
          if ($Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{enum}) {
            for my $subkeyword (keys %{$Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{enum} || {}}) {
              $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{enum}->{$subkeyword}->{spec} ||= 'HTML';
              if ($itemprop eq 'related' and $subitemprop eq 'rel') {
                $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{enum}->{$subkeyword}->{id} ||= 'md-' . $id . '-' . $subitemprop . '-' . $subkeyword;
              } else {
                $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props}->{$subitemprop}->{enum}->{$subkeyword}->{id} ||= 'md-' . $id . '-' . $subitemprop . '-' . $itemprop . '-' . $subkeyword;
              }
            }
          }
        }
      }
    }
  }
}

{
  my $f = file (__FILE__)->dir->parent->file ('local', 'schemaorg.json');
  my $schema = file2perl $f;
  for my $id (keys %$schema) {
    if ($schema->{$id}->{types}->{'http://schema.org/Type'}) {
      $Data->{$id}->{use_itemid} = 1;
      $Data->{$id}->{spec} = 'SCHEMAORG';
      $Data->{$id}->{subclass_of} = {%{$schema->{$id}->{subclass_of}}};
      $Data->{$id}->{superclass_of} = {%{$schema->{$id}->{superclass_of}}};
      delete $Data->{$id}->{subclass_of}->{$id};
      delete $Data->{$id}->{superclass_of}->{$id};
      delete $Data->{$id}->{subclass_of} unless keys %{$Data->{$id}->{subclass_of}};
      delete $Data->{$id}->{superclass_of} unless keys %{$Data->{$id}->{superclass_of}};
    }
  }
  for my $id (keys %$schema) {
    if ($schema->{$id}->{types}->{'http://schema.org/Property'}) {
      my $prop = $id;
      $prop =~ s{^http://schema.org/}{};
      my $def = {};
      #$def->{spec} = 'SCHEMAORG';
      if ($schema->{$id}->{range}->{'http://schema.org/Text'}) {
        $def->{value} = 'text';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Integer'}) {
        $def->{value} = 'integer';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Number'}) {
        $def->{value} = 'floating-point number';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/DateTime'}) {
        $def->{value} = 'global or local date and time string';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Date'}) {
        $def->{value} = 'date string';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Time'}) {
        $def->{value} = 'time string';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/URL'} or
               $schema->{$id}->{range}->{'http://schema.org/Boolean'}) {
        $def->{is_url} = 1;
      }
      for my $range (keys %{$schema->{$id}->{range} or {}}) {
        if (defined $schema->{$range}->{subclass_of}->{'http://schema.org/Thing'}) {
          $def->{item}->{types}->{$range} = 1
              if $schema->{$id}->{range}->{$range} == 1;
          $def->{is_url} = 1;
        } elsif (defined $schema->{$range}->{subclass_of}->{'http://schema.org/DataType'}) {
          #
        } elsif (defined $schema->{$range}->{subclass_of}->{'http://schema.org/Type'}) {
          #
        } else {
          warn "Unknown type of range: |$range|";
        }
      }
      for my $type (keys %{$schema->{$id}->{domain} or {}}) {
        $Data->{$type}->{props}->{$prop} = $def
            if $schema->{$id}->{domain}->{$type} == 1;
      }
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
