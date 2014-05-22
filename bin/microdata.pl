use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = json_bytes2perl path (__FILE__)->parent->parent->child ('src/microdata-dv.json')->slurp;

for my $itemtype (keys %$Data) {
  $Data->{$itemtype}->{vocab} ||= 'http://data-vocabulary.org/';
}

sub n ($) {
  return $_[0] eq 'inf' ? 'Infinity' :
         $_[0] eq '-inf' ? '-Infinity' :
         $_[0] eq 'nan' ? 'NaN' : 0+$_[0];
} # n

{
  my $path = path (__FILE__)->parent->parent->child ('src/microdata-vocabs.txt');
  my $itemtype;
  my $itemprop;
  my $subitemprop;
  my $key;
  my $subkey;
  my $subsubkey;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^\*\s*(\S+)$/) {
      $itemtype = $1;
      $Data->{$itemtype} ||= {};
      $Data->{$itemtype}->{vocab} = 'http://data-vocabulary.org/';
    } elsif (/^([^\s=:]+)=(.*)$/) {
      $Data->{$itemtype}->{$1} = $2;
    } elsif (/^([^\s=:]+)$/) {
      $itemprop = $1;
      $Data->{$itemtype}->{props}->{$itemprop} ||= {};
    } elsif (/^  ([0-9]+)\.\.([0-9]+|inf)$/) {
      $Data->{$itemtype}->{props}->{$itemprop}->{min} = n ($1);
      $Data->{$itemtype}->{props}->{$itemprop}->{max} = n ($2);
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
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{min} = n ($1);
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{max} = n ($2);
    } elsif (/^      ([^\s=:]+)=(.*)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$1} = $2;
    } elsif (/^      ([^\s=:]+)$/) {
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$1} = 1;
    } elsif (/^      ([^\s=:]+):$/) {
      $subkey = $1;
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey} ||= {};
    } elsif (/^        ([^\s=:]+)$/) {
      $subsubkey = $1;
      ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey}->{$1} ||= {};
    } elsif (/^          ([^\s=:]+)=(.*)$/) {
      if ($1 eq 'type') {
        ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey}->{$subsubkey}->{types}->{$2} = 1;
      } else {
        ($key eq 'item' ? $Data->{$itemtype}->{props}->{$itemprop}->{$key}->{props} : $Data->{$itemtype}->{props}->{$itemprop}->{$key})->{$subitemprop}->{$subkey}->{$subsubkey}->{$1} = $2;
      }
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
        $Data->{$itemtype}->{props}->{$itemprop}->{item}->{vocab} ||= $Data->{$itemtype}->{vocab}
            if $Data->{$itemtype}->{props}->{$itemprop}->{item}->{props};
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
  my $wsa_list = json_bytes2perl path (__FILE__)->parent->parent->child ('local/schemaorg-wsa.json')->slurp;

  my $cc_list = [split / /, path (__FILE__)->parent->parent->child ('intermediate/rec20-common-codes.txt')->slurp_utf8];

  my $path = path (__FILE__)->parent->parent->child ('local/schemaorg.json');
  my $schema = json_bytes2perl $path->slurp;
  for my $id (keys %$schema) {
    if ($schema->{$id}->{types}->{'http://schema.org/Type'}) {
      $Data->{$id}->{vocab} = 'http://schema.org/';
      $Data->{$id}->{use_itemid} = 1;
      $Data->{$id}->{spec} = 'SCHEMAORG';
      $Data->{$id}->{subclass_of} = {%{$schema->{$id}->{subclass_of}}};
      $Data->{$id}->{superclass_of} = {%{$schema->{$id}->{superclass_of}}};
      $Data->{$id}->{desc} = $schema->{$id}->{desc}
          if defined $schema->{$id}->{desc};
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
        $def->{value} = 'schema.org datetime';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Date'}) {
        $def->{value} = 'schema.org date';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/Time'}) {
        $def->{value} = 'schema.org time';
      } elsif ($schema->{$id}->{range}->{'http://schema.org/URL'} or
               $schema->{$id}->{range}->{'http://schema.org/Boolean'}) {
        $def->{is_url} = 1;
      }
      if (not $schema->{$id}->{range}->{'http://schema.org/Quantity'}) {
        if ($schema->{$id}->{range}->{'http://schema.org/Duration'}) {
          $def->{value} = 'schema.org duration';
        } elsif ($schema->{$id}->{range}->{'http://schema.org/Distance'}) {
          $def->{value} = 'schema.org distance';
        } elsif ($schema->{$id}->{range}->{'http://schema.org/Energy'}) {
          $def->{value} = 'schema.org energy';
        } elsif ($schema->{$id}->{range}->{'http://schema.org/Mass'}) {
          $def->{value} = 'schema.org mass';
        }
      }
      for my $range (keys %{$schema->{$id}->{range} or {}}) {
        if (defined $schema->{$range}->{subclass_of}->{'http://schema.org/Quantity'}) {
          #
        } elsif (defined $schema->{$range}->{subclass_of}->{'http://schema.org/Thing'}) {
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
      my $desc = $schema->{$id}->{desc};
      if (defined $desc) {
        if ($desc =~ /Acceptable\s+values\s+are\s+('[^']+'(?:,\s*(?:or\s*)?'[^']+')+)\.\s*$/) {
          my $v = $1;
          while ($v =~ /'([^']+)'/g) {
            $def->{enum}->{$1}->{spec} = 'SCHEMAORG';
          }
        }
        if ($desc =~ s/\s*\(WebSchemas wiki lists possible values\)(\.?)\s*$/$1/) {
          my $name = $prop;
          $name =~ s{^http://schema.org/}{};
          if ($wsa_list->{$name}) {
            $def->{enum}->{$_}->{spec} = 'WEBSCHEMAS'
                for keys %{$wsa_list->{$name}->{values}};
          }
        }
        if ($desc =~ /\(legacy spelling; see singular form, .+\)/) {
          $def->{discouraged} = 1;
        }
        if ($desc =~ /please use one of the language codes from the IETF BCP 47 standard\.\s*/) {
          $def->{value} = 'language tag';
        }
        if ($desc =~ m{using the UN/CEFACT Common Code \(3 characters\).\s*}) {
          $def->{enum}->{$_}->{spec} = 'UNCEFACTREC20'
              for @$cc_list;
        }
        if ($desc =~ /^The ISO 3166-1 \(ISO 3166-1 alpha-2\) or ISO 3166-2 code, or the GeoShape/) {
          $def->{value} = 'schema.org region code';
        }
        if ($desc =~ / can be specified as a weekly time range, starting with days, then times per day\./) {
          $def->{value} = 'weekly time range';
        }
        if ($desc =~ /^The currency \(in 3-letter ISO 4217 format\)/ or
            $desc =~ m{^The currency \(coded using ISO 4217, } or
            $desc =~ /\(in ISO 4217 currency format\)\.?\s*$/) {
          $def->{value} = 'currency';
        }
        if ($desc =~ /^MIME format of /) {
          $def->{value} = 'MIME type';
        }
        if ($desc =~ /^The (GTIN-(?:13|14|8)) code of/) {
          $def->{value} = $1;
        }
        if ($desc =~ /^The Global Location Number /) {
          $def->{value} = 'GLN';
        }
        if ($desc =~ /^A count of a specific user interactions with this item/) {
          $def->{value} = 'schema.org user interaction count';
        }
        if ($desc =~ /^The International Standard of Industrial Classification of All Economic Activities \(ISIC\), Revision 4 code /) {
          $def->{value} = 'ISIC';
        }
        if ($desc =~ /^The Dun & Bradstreet DUNS number/) {
          $def->{value} = 'DUNS number';
        }
        if ($desc =~ /^The North American Industry Classification System \(NAICS\) code /) {
          $def->{value} = 'NAICS';
        }
        $def->{desc} = $desc;
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
