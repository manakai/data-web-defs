use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

my $all_roles = {};
{
  my $f = path (__FILE__)->parent->parent->child ('data/aria.json');
  my $json = json_bytes2perl $f->slurp;

  $all_roles->{$_} = 1 for grep { not $json->{roles}->{$_}->{abstract} } keys %{$json->{roles}};
}

{
  my $f = path (__FILE__)->parent->parent->child ('src/element-aria.txt');
  my $key;
  my $elns;
  my $elname;
  my $cond;
  for (split /\x0D?\x0A/, $f->slurp_utf8) {
    if (/^([0-9A-Za-z_-]+)$/) {
      $key = 'elements';
      $elname = $1;
      $cond = '';
      die "Duplicate element |$elname|"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond};
    } elsif (/^([0-9A-Za-z_-]+):([0-9A-Za-z_-]+)$/) {
      $key = 'elements';
      $elname = $1;
      $cond = $2;
      die "Duplicate element |$elname|:$cond"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond};
    } elsif (/^\*:([0-9A-Za-z_-]+)$/) {
      $key = 'elements';
      $elname = '*';
      $cond = $1;
      die "Duplicate :$cond"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond};
    } elsif (/^input:type=([a-z-]+)$/) {
      $key = 'input';
      $elname = $1;
      $cond = '';
      die "Duplicate input type |$elname|"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond};
    } elsif (/^input:type=([a-z-]+):([0-9A-Za-z_-]+)$/) {
      $key = 'input';
      $elname = $1;
      $cond = $2;
      die "Duplicate input type |$elname| :$cond"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond};
    } elsif (/^  role=([a-z-]+|#norole|#textbox-or-combobox) !$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role};
      if ($1 eq '#norole') {
        #
      } elsif ($1 eq '#textbox-or-combobox') {
        $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role} = $1;
      } else {
        $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role} = $1;
      }
      $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{strong_role} = 1;
    } elsif (/^  role=([a-z-]+|#norole) or ([a-z- ]+)$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role};
      my $default_role = $1;
      my $more_roles = {map { $_ => 1 } split / /, $2};
      if ($default_role eq '#norole') {
        $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{allowed_roles} = $more_roles;
      } else {
        $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role} = $default_role;
        $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{allowed_roles} = $more_roles;
      }
    } elsif (/^  role=([a-z-]+) or #any$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role};
      $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{default_role} = $1;
      $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{allowed_roles} = {%$all_roles};
      delete $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{allowed_roles}->{$1};
    } elsif (/^  (aria-[0-9a-z]+)=(true|false)( !)?$/) {
      my $v = $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{attrs}->{$1}
          = {value_type => $2, strong => $3 ? 1 : 0};
      delete $v->{strong} unless $v->{strong};
    } elsif (/^  (aria-[0-9a-z]+)=#(outlinedepth|maximum|minimum|value-if-number|list-if-combobox|maximum-if-determinate|value-if-determinate|0-if-determinate|selected)( !)?$/) {
      my $v = $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{attrs}->{$1}
          = {value_type => $2, strong => $3 ? 1 : 0};
      delete $v->{strong} unless $v->{strong};
    } elsif (m{^  (aria-[0-9a-z]+)=(true/missing|true/false/mixed|true/false|missing/true)\[(?:([a-z]+)\.|)([a-z]+)\]( !)?$}) {
      my $v = $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{attrs}->{$1}
          = {value_type => $2, attr => $4, attr_of_parent => $3,
             strong => $5 ? 1 : 0};
      delete $v->{attr_of_parent} unless defined $v->{attr_of_parent};
      delete $v->{strong} unless $v->{strong};
    } elsif (m{^  (aria-[0-9a-z]+)=(true/missing|true/false/mixed|true/false|missing/true)(:checked|:indeterminate:checked|:invalid)( !)?$}) {
      my $v = $Data->{$key}->{$elns}->{$elname}->{conds}->{$cond}->{attrs}->{$1}
          = {value_type => $2, state => $3, strong => $4 ? 1 : 0};
      delete $v->{strong} unless $v->{strong};
    } elsif (m{^  aria-hidden only$}) {
      $Data->{$key}->{$elns}->{$elname}->{aria_hidden_only} = 1;
    } elsif (m{^  no aria-\*$}) {
      $Data->{$key}->{$elns}->{$elname}->{aria_disallowed} = 1;
    } elsif (m{^attr\s+(\S+)\s+(aria-\w+)=(\S+)$}) {
      push @{$Data->{attr_rules} ||= []}, [$1, $2, $3];
    } elsif (/^\@ns\s+(\S+)$/) {
      $elns = $1;
    } elsif (/^\s*#/) {
      #
    } elsif (/\S/) {
      die "Broken line |$_|";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
