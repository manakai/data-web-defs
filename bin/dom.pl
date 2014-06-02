use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::IDL::Parser;
use Web::IDL::Processor;
use Web::DOM::Document;

my $Data = {};

sub read_text ($$) {
  my ($file_name, $file_key) = @_;
  my $path = path (__FILE__)->parent->parent->child ('src', $file_name);
  my $key;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^(\S+)$/) {
      $key = $1;
      $Data->{$file_key}->{$key} ||= {};
    } elsif (/^  ([^=]+)=(.*)$/) {
      $Data->{$file_key}->{$key}->{$1} = $2;
    } elsif (/\S/) {
      die "$file_name: Broken data |$_|";
    }
  }
} # read_text

read_text 'dom-nodes.txt' => 'node_types';

## <http://dom.spec.whatwg.org/#dom-document-createevent>
$Data->{create_event}->{$_->[0]} = $_->[1]
    for
        [customevent => 'CustomEvent'],
        [event => 'Event'],
        [events => 'Event'],
        [htmlevents => 'Event'],
        [keyboardevent => 'KeyboardEvent'],
        [keyevents => 'KeyboardEvent'],
        [messageevent => 'MessageEvent'],
        [mouseevent => 'MouseEvent'],
        [mouseevents => 'MouseEvent'],
        [touchevent => 'TouchEvent'],
        [uievent => 'UIEvent'],
        [uievents => 'UIEvent'];

{
  my $path = path (__FILE__)->parent->parent->child ('local/html-extracted.json');
  my $json = json_bytes2perl $path->slurp;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('div');
  my $processor = Web::IDL::Processor->new;
  my $next_di = 1;
  my $di;
  my $di_to_content = {};
  my @error;
  my $onerror = sub {
    push @error, {@_};
    $error[-1]->{di} = $di if defined $di and not defined $error[-1]->{di};
    if (defined $error[-1]->{di} and defined $error[-1]->{index}) {
      $error[-1]->{fragment} = substr $di_to_content->{$error[-1]->{di}}, $error[-1]->{index}, 20;
    } elsif (defined $error[-1]->{di}) {
      $error[-1]->{fragment} = substr $di_to_content->{$error[-1]->{di}}, 0, 20;
    }
    $error[-1]->{spec} = 'HTML';
  };
  $processor->onerror ($onerror);
  for (sort { $a cmp $b } @{$json->{idl_fragments} or []}) {
    $di = $next_di++;
    $el->inner_html ($_);
    my $idl = $el->text_content;
    next if $idl =~ /^\s*interface\s+Example\b/;
    $di_to_content->{$di} = $idl;
    my $parser = Web::IDL::Parser->new;
    $parser->onerror ($onerror);
    $parser->parse_char_string ($idl);
    $processor->process_parsed_struct ($di, $parser->parsed_struct);
  }
  $processor->end_processing;
  my $data = $processor->processed;
  for (keys %$data) {
    $Data->{$_} = $data->{$_};
  }
  $Data->{_idl_errors} = \@error;
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
