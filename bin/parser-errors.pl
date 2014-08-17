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
    } elsif (defined $last_lang) {
      ($Data->{errors}->{$error_type}->{$key_by_lang->{$last_lang}}->{$last_lang} //= '') .= "\x0A" . $_;
    } elsif (defined $error_type and /^(name)=(\S+)$/) {
      my $error_name = $2;
      if (defined $Data->{parser_error_name_to_error_type}->{$error_name}) {
        die "Duplicate error type mapping for |$error_name|";
      }
      $Data->{errors}->{$error_type}->{parser_error_names}->{$error_name} = 1;
      $Data->{parser_error_name_to_error_type}->{$error_name} = $error_type;
    } elsif (defined $error_type and /^(value|layer)=(\S+)$/) {
      $Data->{errors}->{$error_type}->{$1} = $2;
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
      if (defined $value->{type} and $value->{type} eq 'parse error') {
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
} # $error_type

{
  my $json = json_bytes2perl path (__FILE__)->parent->parent->child
      ('data/html-syntax.json')->slurp_utf8;
  my $tokenize_errors = extract_parse_error_names $json->{tokenizer}->{states};
  my $tree_errors = extract_parse_error_names $json->{ims};
  for (@$tokenize_errors, @$tree_errors) {
    $Data->{parser_error_name_to_error_type}->{$_} //= undef;
  }

  for (grep { defined } map { $Data->{parser_error_name_to_error_type}->{$_} } @$tokenize_errors) {
    $Data->{errors}->{$_}->{modules}->{'Web::HTML::Parser::tokenizer'} //= 1;
    $Data->{errors}->{$_}->{layer} //= 'tokenization';
  }
  for (grep { defined } map { $Data->{parser_error_name_to_error_type}->{$_} } @$tree_errors) {
    $Data->{errors}->{$_}->{modules}->{'Web::HTML::Parser::tree_constructor'} //= 1;
    $Data->{errors}->{$_}->{layer} //= 'tree-construction';
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
