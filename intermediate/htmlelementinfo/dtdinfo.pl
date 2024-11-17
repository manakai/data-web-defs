use strict;
use warnings;
use JSON::PS;

my $Data = {};

sub parse_dtd ($$) {
  my $bytes = shift;
  my $states = shift;

  while ($bytes =~ m{<!([^<>]+)}g) {
    my $value = $1;

    if ($value =~ m{^--}) {
      next if $value =~ m{--$};
      $bytes =~ m{-->}g;
      next;
    }

    $value =~ s{(%([\w.-]+);?)}{$states->{params}->{$2} // $1}ge;

    if ($value =~ m{^!ignore\s+([^<>\s]+)$}) {
      $states->{params}->{$1} = 'IGNORE';
      next;
    }

    if ($value =~ m{^\[\s*INCLUDE\s*\[}) {
      next;
    } elsif ($value =~ m{^\[}) {
      my $nest_level = 1;
      while ($bytes =~ m{(<!\[|\]\]>)}g) {
        if ($1 eq '<![') {
          $nest_level++;
        } else {
          $nest_level--;
          last if $nest_level < 1;
        }
      }
      next;
    }

    if ($value =~ m{^ELEMENT\s+([\w.-]+)\s}) {
      $Data->{elements}->{lc $1}->{ELEMENT} = 1;
    } elsif ($value =~ m{^ELEMENT\s+\(([\w.\s|-]+)\)\s}) {
      my $v = $1;
      $v =~ s/^\s+//;
      $v =~ s/\s+$//;
      $Data->{elements}->{lc $_}->{ELEMENT} = 1 for split /\s*\|\s*/, $v;
    } elsif ($value =~ m{^ATTLIST\s+([\w.-]+)\s}) {
      $Data->{elements}->{lc $1}->{ATTLIST} = 1;
    } elsif ($value =~ m{^ATTLIST\s+\(([\w.\s|-]+)\)\s}) {
      my $v = $1;
      $v =~ s/^\s+//;
      $v =~ s/\s+$//;
      $Data->{elements}->{lc $_}->{ATTLIST} = 1 for split /\s*\|\s*/, $v;
    } elsif ($value =~ m{^ENTITY\s+%\s+([\w.-]+)\s+"([^"]*)"}) {
      my $name = $1;
      my $value = $2;
      $value =~ s{(%([\w.-]+);?)}{$states->{params}->{$2} // $1}ge;
      $states->{params}->{$name} //= $value;
    }

  }
  
  
} # parse_dtd

{
  local $/ = undef;
  my $bytes = <>;

  parse_dtd $bytes, {};
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
