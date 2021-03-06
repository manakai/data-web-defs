use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;

my $Data = {};

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # _n

sub parse_file ($) {
  my $error_type;
  my $last_lang;
  my $key_by_lang;
  my $in_test;
  for (split /\x0D?\x0A/, path ($_[0])->slurp_utf8) {
    if (/^\s*\#/) {
      #
    } elsif (/^\*\s*(.+)$/) {
      my $name = _n $1;
      die "Duplicate error type |$name|" if defined $Data->{errors}->{$name};
      $Data->{errors}->{$name} ||= {};
      $error_type = $name;
      $last_lang = undef;
      $key_by_lang = {};
      $in_test = undef;
    } elsif (defined $error_type and /^\@(\w+)$/) {
      my $lang = $1;
      if (defined $Data->{errors}->{$error_type}->{message}->{$lang}) {
        if (defined $Data->{errors}->{$error_type}->{desc}->{$lang}) {
          die "There are three texts for language |$lang|";
        } else {
          $key_by_lang->{$lang} = 'desc';
        }
      } else {
        $key_by_lang->{$lang} = 'message';
      }
      $last_lang = $lang;
    } elsif (defined $error_type and /^!!!$/) {
      $in_test = 1;
      $last_lang = undef;
      push @{$Data->{errors}->{$error_type}->{parser_tests} ||= []},
          {input => '', lang => 'HTML'};
    } elsif (defined $error_type and /^!!!(\w+)$/) {
      $in_test = 1;
      $last_lang = undef;
      push @{$Data->{errors}->{$error_type}->{parser_tests} ||= []},
          {input => '', lang => $1};
    } elsif (defined $last_lang) {
      ($Data->{errors}->{$error_type}->{$key_by_lang->{$last_lang}}->{$last_lang} //= '') .= "\x0A" . $_;
    } elsif ($in_test) {
      if (/^!(\w+)=(.*)$/) {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{$1} = $2;
      } elsif (/^!(\w+)$/) {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{$1} = 1;
      } else {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{input} .= "\x0A" . $_;
      }
    } elsif (defined $error_type and /^(name)=(\S+)$/) {
      my $error_name = $2;
      if (defined $Data->{parser_error_name_to_error_type}->{$error_name}) {
        die "Duplicate error type mapping for |$error_name|";
      }
      $Data->{errors}->{$error_type}->{parser_error_names}->{$error_name} = 1;
      $Data->{parser_error_name_to_error_type}->{$error_name} = $error_type;
    } elsif (defined $error_type and /^(value|text)=current node\.(\S+)$/) {
      my ($n, $v) = ($1, $2);
      $v =~ tr/-_/  /;
      $Data->{errors}->{$error_type}->{$n} = ['oe[-1]', $v];
    } elsif (defined $error_type and /^(value|text)=(\S+)$/) {
      my ($n, $v) = ($1, $2);
      $v =~ tr/-_/  /;
      $Data->{errors}->{$error_type}->{$n} = ['token', $v];
    } elsif (defined $error_type and /^(layer)=(character-set|tokenization|tree-construction|entity|dtd|namespaces)$/) {
      $Data->{errors}->{$error_type}->{$1} = $2;
    } elsif (defined $error_type and /^(default_level)=(m|s|w)$/) {
      $Data->{errors}->{$error_type}->{$1} = $2;
    } elsif (defined $error_type and /^(module)=(\S+)$/) {
      $Data->{errors}->{$error_type}->{$1.'s'}->{$2} = 1;
    } elsif (/\S/) {
      die "Broken line |$_|";
    }
  }
} # parse_file

sub extract_parse_error_names ($) {
  my @name;
  my @value = ($_[0]);
  while (@value) {
    my $value = shift @value;
    next unless defined $value;
    if (ref $value eq 'HASH') {
      if (defined $value->{type} and
          ($value->{type} eq 'parse error' or
           $value->{type} eq 'parse error-and-switch')) {
        if (defined $value->{name}) {
          push @name, $value->{name};
        }
      } else {
        unshift @value, values %$value;
      }
    } elsif (ref $value eq 'ARRAY') {
      unshift @value, @$value;
    }
  }
  return \@name;
} # extract_parse_error_names

parse_file $_ for @ARGV;

my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
my $el = $doc->create_element ('div');
for my $error_type (keys %{$Data->{errors}}) {
  for my $key (qw(message desc)) {
    for my $lang (keys %{$Data->{errors}->{$error_type}->{$key}}) {
      my $text = $Data->{errors}->{$error_type}->{$key}->{$lang};
      $text =~ s/^\s+//;
      $text =~ s/\s+$//;
      $el->inner_html ($text);
      $Data->{errors}->{$error_type}->{$key}->{$lang} = $el->inner_html;
    }
  }

  for my $test (@{$Data->{errors}->{$error_type}->{parser_tests} or []}) {
    $test->{input} =~ s/^\s+//;
    $test->{input} =~ s/\s+$//;
    my $input = [map { s/\\u([0-9A-F]{4})/chr hex $1/ge; $_ } split /\$\$/, $test->{input}, 2];
    $test->{index} = length $input->[0];
    $test->{input} = $input->[0] . ($input->[1] // '');
  }

  $Data->{errors}->{$error_type}->{default_level} //= 'm';
} # $error_type

for (
  ['data/html-syntax.json', 'Web::HTML::Parser'],
  ['data/xml-syntax.json', 'Web::XML::Parser'],
) {
  my ($file_name, $module) = @$_;
  my $json = json_bytes2perl path (__FILE__)->parent->parent->child
      ($file_name)->slurp;
  my $tokenize_errors = extract_parse_error_names $json->{tokenizer}->{states};
  my $tree_errors = [
    @{extract_parse_error_names $json->{ims}},
    @{extract_parse_error_names $json->{tree_steps}},
  ];
  for (@$tokenize_errors, @$tree_errors) {
    $Data->{parser_error_name_to_error_type}->{$_} //= undef;
  }

  for (grep { defined } map { $Data->{parser_error_name_to_error_type}->{$_} } @$tokenize_errors) {
    $Data->{errors}->{$_}->{modules}->{$module.'::tokenizer'} //= 1;
    $Data->{errors}->{$_}->{layer} //= 'tokenization';
  }
  for (grep { defined } map { $Data->{parser_error_name_to_error_type}->{$_} } @$tree_errors) {
    $Data->{errors}->{$_}->{modules}->{$module.'::tree_constructor'} //= 1;
    $Data->{errors}->{$_}->{layer} //= 'tree-construction';
  }
}

for my $error_type (keys %{$Data->{errors}}) {
  warn "|$error_type| has no layer"
      if not defined $Data->{errors}->{$error_type}->{layer};
  warn "|$error_type| has no module"
      unless keys %{$Data->{errors}->{$error_type}->{modules} or {}};
} # $error_type

print perl2json_bytes_for_record $Data;

## License: Public Domain.
