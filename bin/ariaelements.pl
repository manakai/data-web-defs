use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib')->stringify;
use JSON::Functions::XS qw(perl2json_bytes_for_record file2perl);

my $Data = {};

my $all_roles = {};
my $expanded_roles = {};
{
  my $f = file (__FILE__)->dir->parent->file ('data', 'aria.json');
  my $json = file2perl $f;

  $all_roles->{$_} = 1 for grep { not $json->{roles}->{$_}->{abstract} } keys %{$json->{roles}};

  $expanded_roles->{$_} = 1
      for grep { $json->{roles}->{$_}->{attrs}->{'aria-expanded'} } keys %{$json->{roles}};
}

{
  my $f = file (__FILE__)->dir->parent->file ('src', 'element-aria.txt');
  my $key;
  my $elname;
  my $cond;
$elname='XXX';
  for (($f->slurp)) {
    if (/^([0-9A-Za-z_-]+)$/) {
      $key = 'html_elements';
      $elname = $1;
      $cond = '';
      die "Duplicate element |$elname|"
          if defined $Data->{$key}->{$elname}->{$cond};
    } elsif (/^([0-9A-Za-z_-]+):([0-9A-Za-z_-]+)$/) {
      $key = 'html_elements';
      $elname = $1;
      $cond = $2;
      die "Duplicate element |$elname|:$cond"
          if defined $Data->{$key}->{$elname}->{$cond};
    } elsif (/^:([0-9A-Za-z_-]+)$/) {
      $key = 'common';
      $elname = '';
      $cond = $1;
      die "Duplicate :$cond"
          if defined $Data->{$key}->{$elname}->{$cond};
    } elsif (/^input:type=([a-z-]+)$/) {
      $key = 'input';
      $elname = $1;
      $cond = '';
      die "Duplicate input type |$elname|"
          if defined $Data->{$key}->{$elname}->{$cond};
    } elsif (/^  role=([a-z]+|#norole|#textbox-or-combobox) !$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elname}->{$cond}->{default_role};
      if ($1 eq '#norole') {
        $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = {presentation => 1};
      } elsif ($1 eq '#textbox-or-combobox') {
        $Data->{$key}->{$elname}->{$cond}->{default_role} = $1;
        $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = {presentation => 1};
      } else {
        $Data->{$key}->{$elname}->{$cond}->{default_role} = $1;
        $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = {presentation => 1};
      }
      $Data->{$key}->{$elname}->{$cond}->{strong_role} = 1;
    } elsif (/^  role=([a-z]+|#norole) or ([a-z ]+)$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elname}->{$cond}->{default_role};
      my $default_role = $1;
      my $more_roles = {map { $_ => 1 } split / /, $2};
      if ($default_role eq '#norole') {
        $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = $more_roles;
      } else {
        $Data->{$key}->{$elname}->{$cond}->{default_role} = $default_role;
        $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = $more_roles;
      }
    } elsif (/^  role=([a-z]+) or #any$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elname}->{$cond}->{default_role};
      $Data->{$key}->{$elname}->{$cond}->{default_role} = $1;
      $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = {%$all_roles};
      delete $Data->{$key}->{$elname}->{$cond}->{allowed_roles}->{$1};
    } elsif (/^  role=([a-z]+) or #aria-expanded$/) {
      die "No element" unless defined $elname;
      die "Role for |$elname| already defined"
          if defined $Data->{$key}->{$elname}->{$cond}->{default_role};
      $Data->{$key}->{$elname}->{$cond}->{default_role} = $1;
      $Data->{$key}->{$elname}->{$cond}->{allowed_roles} = {%$expanded_roles, presentation => 1};
      delete $Data->{$key}->{$elname}->{$cond}->{allowed_roles}->{$1};
    } elsif (/^  (aria-[0-9a-z]+)=(true|false)( !)?$/) {
      $Data->{$key}->{$elname}->{$cond}->{attrs}->{$1} = {value_type => $2, strong => $3 ? 1 : 0};
    } elsif (/^  (aria-[0-9a-z]+)=#(outlinedepth|maximum|minimum|value-if-number|list-if-combobox|maximum-if-determinate|value-if-determinate|0-if-determinate|selected)( !)?$/) {
      $Data->{$key}->{$elname}->{$cond}->{attrs}->{$1} = {value_type => $2, strong => $3 ? 1 : 0};
    } elsif (m{^  (aria-[0-9a-z]+)=(true/missing|true/false/mixed|true/false|missing/true)\[([a-z]+)\]( !)?$}) {
      $Data->{$key}->{$elname}->{$cond}->{attrs}->{$1} = {value_type => $2, attr => $3, strong => $4 ? 1 : 0};
    } elsif (m{^  (aria-[0-9a-z]+)=(true/missing|true/false/mixed|true/false|missing/true)(:checked|:indeterminate:checked)( !)?$}) {
      $Data->{$key}->{$elname}->{$cond}->{attrs}->{$1} = {value_type => $2, state => $3, strong => $4 ? 1 : 0};
    } elsif (/^\s*#/) {
      #
    } elsif (/\S/) {
      die "Broken line |$_|";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
