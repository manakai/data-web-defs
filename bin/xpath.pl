use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $funcs_path = path (__FILE__)->parent->parent->child ('src/xpath-functions.txt');
  for (split /\x0D?\x0A/, $funcs_path->slurp_utf8) {
    if (/^\s*#/) {
      #
    } elsif (/^(node-set|number|string|boolean)\s+([^\s(]+)\(([^()]*)\)$/) {
      my $return_type = $1;
      my $name = $2;
      my $args = $3;
      for ($Data->{functions}->{''}->{$name} ||= {}) {
        $_->{context}->{core} = 1;
        $_->{spec} = 'XPATH';
        $_->{id} = 'function-' . $name;
        $_->{return_type} = $return_type;
        $_->{args} = [map { s/\?$//; $_ } split /,/, $args];
        $_->{args_min} = length join '', map { /\?$/ ? '' : '1' } split /,/, $args;
        $_->{args_max} = @{$_->{args}};
        if ($name eq 'concat') {
          $_->{args_max} = 'Infinity';
        }
      }
    } elsif (/\S/) {
      die "Broken line: |$_|";
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
