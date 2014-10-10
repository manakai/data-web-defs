use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $Data = {};

{
  my $path = path (__FILE__)->parent->parent->child ('local/webidl.json');
  my $data = json_bytes2perl $path->slurp;

  for my $error_name (keys %{$data->{error_names}}) {
    my $def = $data->{error_names}->{$error_name};
    $Data->{dom_errors}->{$error_name}->{name} = $error_name;
    #$Data->{dom_errors}->{$error_name}->{desc} = $def->{desc};
    $Data->{dom_errors}->{$error_name}->{const_name} = $def->{const_name}
        if defined $def->{const_name};
    $Data->{dom_errors}->{$error_name}->{const_value} = 0+$def->{const_value}
        if defined $def->{const_value};
    $Data->{dom_errors}->{$error_name}->{spec} = 'WEBIDL';
    $Data->{dom_errors}->{$error_name}->{id} = lc $error_name;
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('intermediate/dom-error-types.json');
  my $data = json_bytes2perl $path->slurp;
  for my $error_name (keys %{$data->{error_names}}) {
    my $def = $data->{error_names}->{$error_name};
    $Data->{dom_errors}->{$error_name}->{desc} = $def->{desc}
        if defined $Data->{dom_errors}->{$error_name};
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
