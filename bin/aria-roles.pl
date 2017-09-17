use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

my $in_path = path (__FILE__)->parent->parent->child ('src/aria-roles.txt');
my $role;
my $spec;
for (split /\x0D?\x0A/, $in_path->slurp_utf8) {
  if (/^\s*#/) {
    #
  } elsif (/^\*\s*(\S+)$/) {
    $role = $1;
    $Data->{roles}->{$role} ||= {};
    $Data->{roles}->{$role}->{spec} = $spec if defined $spec;
  } elsif (/^spec\s+(\S+)$/) {
    $Data->{roles}->{$role}->{url} = $1;
  } elsif (/^name\s+from\s+(author)$/) {
    $Data->{roles}->{$role}->{name_from}->{$1} = 1;
  } elsif (/^name\s+from\s+(author\s+contents?|contents?\s+author)$/) {
    $Data->{roles}->{$role}->{name_from}->{author} = 1;
    $Data->{roles}->{$role}->{name_from}->{contents} = 1;
  } elsif (/^implicit\s+([^\s=]+)=(.*)$/) {
    $Data->{roles}->{$role}->{attr_default}->{$1} = $2;
  } elsif (/^accessible\s+name\s+required\s+(true)$/) {
    $Data->{roles}->{$role}->{accessible_name_required} = 1;
  } elsif (/^accessible\s+name\s+required\s+(false)$/) {
    #
  } elsif (/^children\s+presentational\s+(true)$/) {
    $Data->{roles}->{$role}->{children_presentational} = 1;
  } elsif (/^children\s+presentational\s+(false)$/) {
    #
  } elsif (/^superclass\s+(\S+)$/) {
    $Data->{roles}->{$role}->{subclass_of}->{$1} = 1;
  } elsif (/^required\s+owned\s+elements\s+(\S+)$/) {
    $Data->{roles}->{$role}->{must_contain}->{$1} = 1;
  } elsif (/^required\s+owned\s+elements\s+(\S+)\s+(\S+)$/) {
    $Data->{roles}->{$role}->{must_contain}->{$1} = 1;
    $Data->{roles}->{$role}->{must_contain}->{$2} = 1;
  } elsif (/^required\s+context\s+role\s+(\S+)$/) {
    $Data->{roles}->{$role}->{scope}->{$1} = 1;
  } elsif (/^abstract$/) {
    $Data->{roles}->{$role}->{abstract} = 1;
  } elsif (/^(MUST|SHOULD)\s+(aria-\S+)$/) {
    $Data->{roles}->{$role}->{attrs}->{$2}->{lc $1} = 1;

  } elsif (/^\@spec\s+(\S+)$/) {
    $spec = $1;
  } elsif (/^\@spec$/) {
    $spec = undef;
  } elsif (/\S/) {
    die "Bad line |$_|";
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
