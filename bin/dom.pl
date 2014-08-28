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
  my $html_path = path (__FILE__)->parent->parent->child ('local/html-extracted.json');
  my $html_json = json_bytes2perl $html_path->slurp;

  my $path = path (__FILE__)->parent->parent->child ('local/idl-extracted.json');
  my $json = json_bytes2perl $path->slurp;
  $json->{HTML} = [sort { $a cmp $b } @{$html_json->{idl_fragments}}];

  my $idl_path = path (__FILE__)->parent->parent->child ('src/idl');
  push @{$json->{''} ||= []},
      map { '<plaintext>' . $idl_path->child ($_)->slurp_utf8 }
      qw(webidl.idl html-additional.idl xpath.idl xpath-whatwgwiki.idl);

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  my $el = $doc->create_element ('div');
  my $processor = Web::IDL::Processor->new;
  my $next_di = 1;
  my $di;
  my $di_to_content = {};
  my $spec;
  my $di_to_spec = [];
  my @error;
  my $current_idl;
  my $onerror = sub {
    push @error, {@_};
    $error[-1]->{di} = $di if defined $di and not defined $error[-1]->{di};
    if (defined $error[-1]->{di} and defined $error[-1]->{index}) {
      $error[-1]->{fragment} = substr $di_to_content->{$error[-1]->{di}}, $error[-1]->{index}, 100;
    } elsif (defined $error[-1]->{di}) {
      $error[-1]->{fragment} = substr $di_to_content->{$error[-1]->{di}}, 0, 100;
    }
    $error[-1]->{spec} = $di_to_spec->[$di]
        if length $di_to_spec->[$di];
    warn "$error[-1]->{type} - >>@{[substr $current_idl, $error[-1]->{index}-10,10]}\@\@\@\@@{[substr $current_idl, $error[-1]->{index}, 10]}<< {{{$current_idl}}}" if $error[-1]->{type} =~ /parse/;
  };
  $processor->onerror ($onerror);
  for (sort { $a cmp $b } keys %$json) {
    $spec = $_;
    for (@{$json->{$spec}}) {
      $di = $next_di++;
      $di_to_spec->[$di] = $spec;
      $el->inner_html ($_);
      for (@{$el->query_selector_all ('a[href], dfn[id]')}) {
        my $title = $_->get_attribute ('href') || $_->id;
        if ($title =~ /#(.+)$/) {
          $title = $1;
        }
        next unless $title;
        next if not $_->local_name eq 'dfn' and $title eq lc $_->text_content;
        next if $title =~ /^idl-/;
        my $prev = $_->previous_sibling;
        if (defined $prev and $prev->node_type == $prev->TEXT_NODE) {
          my $v = $prev->text_content;
          if ($v =~ /"$/) {
            $v =~ s/"$/[*id="$title"*]"/;
            $prev->text_content ($v);
            next;
          } elsif ($v =~ m{"" /\* $}) {
            $v =~ s{"" /\* $}{[*id="$title"*]"" /* };
            $prev->text_content ($v);
            next;
          } elsif ($v =~ m{\b_$}) {
            $v =~ s{_$}{[*id="$title"*]_};
            $prev->text_content ($v);
            next;
          }
        }
        $_->text_content ('[*id="' . $title . '"*]' . $_->text_content);
      }
      my $idl = $el->text_content;
      $idl = '[*spec='.$spec.'*]' . $idl if length $spec;
      next if $spec eq 'HTML' and $idl =~ m{^\s*\[\*[^*]*\*\]\s*interface\s+(?:\[\*[^*]*\*\]|)?Example\b};
      next if $spec eq 'HTML' and $idl =~ /^\s*\[\*[^*]*\*\]\s*void\s+\[\*[^*]*\*\]select/;
      $di_to_content->{$di} = $idl;
      my $parser = Web::IDL::Parser->new;
      $parser->onerror ($onerror);
      $current_idl = $idl;
      $parser->parse_char_string ($idl);
      $processor->process_parsed_struct ($di, $parser->parsed_struct);
    }
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
