use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Web::DOM::Document;

my $Data = {};

sub sp ($) {
  my $s = shift;
  $s =~ s/^\s+//;
  $s =~ s/\s+$//;
  $s =~ s/\s+/ /g;
  return $s;
} # sp

my $d = file (__FILE__)->dir->parent->subdir ('local/www.whatwg.org/specs/web-apps/current-work/multipage/');
my $index_doc;
my $input_table;
for my $f (($d->children)) {
  next unless $f =~ /\.html$/;
  my $doc = Web::DOM::Document->new;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $f->slurp);
  $index_doc = $doc if $f =~ /section-index/;
  $input_table ||= $doc->get_element_by_id ('input-type-attr-summary');

  for my $dl (@{$doc->query_selector_all ('dl.element')}) {
    my $heading = $dl->previous_element_sibling;
    while ($heading) {
      last if $heading->local_name =~ /^h[1-6]$/;
    }
    next unless $heading;
    next unless $heading->id =~ /^the-([0-9a-z_-]+)-element$/; # h1-h6 do not match
    my $local_name = $1;
    my $props = {id => "the-$local_name-element"};
    my $field;
    for (@{$dl->children}) {
      if ($_->local_name eq 'dt') {
        my $a = $_->first_element_child;
        if ($a and ($a->title =~ /^element-dfn-(.+)$/)) {
          $field = $1;
        } else {
          undef $field;
        }
      } elsif ($_->local_name eq 'dd') {
        next unless defined $field;
        if ($field eq 'attributes') {
          my $text = $_->text_content;
          if ($text eq 'Global attributes' or
              $text eq 'Any other attribute that has no namespace (see prose).') {
            #
          } elsif ($text =~ /^If the element is a child of an ol element: value \x{2014}/) {
            $props->{attrs}->{value}->{id} = 'attr-li-value';
            $props->{attrs}->{value}->{desc} = [split /\x{2014}\s*/, $text, 2]->[1];
          #} elsif ($text =~ /^Also, /) {
          #  #
          } else {
            my $code = $_->first_element_child;
            if ($code and
                $code->local_name eq 'code' and
                $code->title =~ /^(?:attr|handler)-/) {
              my $attr = $code->text_content;
              $props->{attrs}->{$attr}->{id} = $code->title;
              $props->{attrs}->{$attr}->{desc} = [split /\x{2014}\s*|has special semantics on this element:\s*/, $text, 2]->[1];
            } else {
              push @{$Data->{_errors} ||= []},
                  ['attrs', $local_name, $_->inner_html];
            }
          }
        } elsif ($field eq 'categories') {
          my $text = $_->text_content;
          my $a = $_->first_element_child;
          if ($text =~ /^(\S+ \S+)\.$/ and $a and $a->local_name eq 'a') {
            my $title = $a->title || lc sp $a->text_content;
            $props->{categories}->{$title} = 1;
          } elsif ($text =~ /^\S+ form-associated element\.$/ or
                   $text =~ /^\S+ and reassociateable form-associated element\.$/ or
                   $text =~ /^(?:\S+, )+and reassociateable form-associated element\.$/) {
            for my $a (@{$_->query_selector_all ('a')}) {
              my $title = $a->title || lc sp $a->text_content;
              $props->{categories}->{$title} = 1;
            }
          } elsif ($text =~ /^If the element/ or
                   $text =~ /^If the \S+ (?:attribute|element) is/ or
                   $text =~ /^Otherwise/) {
            $props->{categories}->{_complex} = 1;
          } elsif ($text eq 'None.') {
            #
          } else {
            push @{$Data->{_errors} ||= []},
                ['categories', $local_name, $_->inner_html];
          }
        } elsif ($field eq 'content-model') {
          my $text = $_->text_content;
          my $a = $_->first_element_child;
          if ($text =~ /^(\S+ \S+|Text|Transparent)\.$/ and
              $a and $a->local_name eq 'a') {
            my $title = $a->title || lc sp $a->text_content;
            $props->{content_model}->{$title} = 1;
          } elsif ($text eq 'Empty.') {
            $props->{content_model}->{empty} = 1;
          } elsif ($text =~ /[Pp]rose/ or
                   $text =~ /followed by/ or
                   $text =~ /[Dd]epends on/ or
                   $text =~ /^(?:Or|Either|Otherwise|If|When)/ or
                   $text =~ /but there must be no/ or
                   $text =~ /but with no/ or
                   $text =~ /except for/ or
                   $text =~ /One or more/ or
                   $text =~ /Zero or more/ or
                   $text =~ /that is not/) {
            $props->{content_model}->{_complex} = 1;
          } else {
            push @{$Data->{_errors} ||= []},
                ['content_model', $local_name, $_->inner_html];
          }
        } elsif ($field eq 'tag-omission') {
          my $text = $_->text_content;
          if ($text eq 'Neither tag is omissible.') {
            #
          } elsif ($text eq 'No end tag.') {
            $props->{end_tag} = 'never';
          } elsif ($text =~ /start\s+tag\s+can\s+be\s+omitted/) {
            $props->{start_tag} = 'optional';
          } elsif ($text =~ /end\s+tag\s+can\s+be\s+omitted/) {
            $props->{end_tag} = 'optional';
          } else {
            push @{$Data->{_errors} ||= []},
                ['tag_omission', $local_name, $_->inner_html];
          }
        } # $field
      }
    }
    $Data->{elements}->{$local_name} = $props;
  }
}

if ($index_doc) {
  my $els = $index_doc->query_selector ('caption:-manakai-contains("List of elements")');
  if ($els) {
    $els = $els->parent_node;
    for my $tr (@{$els->rows}) {
      my $th = $tr->first_element_child;
      next unless $th->local_name eq 'th';
      my $a = $th->first_element_child or next;
      my $td = $th->next_element_sibling or next;
      $Data->{elements}->{$a->text_content}->{desc} = $td->text_content;
    }
  }

  my $attrs = $index_doc->query_selector ('caption:-manakai-contains("List of attributes")');
  if ($attrs) {
    $attrs = $attrs->parent_node;
    for my $tr (@{$attrs->rows}) {
      my $th = $tr->first_element_child;
      next unless $th->local_name eq 'th';
      my $a = $th->first_element_child or next;
      my $td = $th->next_element_sibling or next;
      if ($td->text_content =~ /HTML\s+elements/) {
        my $td2 = $td->next_element_sibling;
        my $desc = sp $td2->text_content;
        $Data->{global_attrs}->{$a->text_content}
            = {id => $td->first_element_child->title, desc => $desc};
      }
    }
  }

  $attrs = $index_doc->query_selector ('caption:-manakai-contains("List of event handler content attributes")');
  if ($attrs) {
    $attrs = $attrs->parent_node;
    for my $tr (@{$attrs->rows}) {
      my $th = $tr->first_element_child;
      next unless $th->local_name eq 'th';
      my $a = $th->first_element_child or next;
      my $td = $th->next_element_sibling or next;
      my $td2 = $td->next_element_sibling;
      my $desc = sp $td2->text_content;
      if ($td->text_content =~ /HTML\s+elements/) {
        $Data->{global_attrs}->{$a->text_content}
            = {id => $td->first_element_child->title, desc => $desc};
      } else {
        my $a2 = $td->first_element_child or next;
        $Data->{elements}->{$a2->text_content}->{attrs}->{$a->text_content}
            ->{desc} ||= $desc;
      }
    }
  }
}

{
  my @header;
  my @rows = @{$input_table->rows};
  for my $th (@{(shift @rows)->cells}) {
    push @header, [map { s/^attr-input-type-//; $_ } grep { /^attr-input-type-/ } map { $_->title } @{$th->get_elements_by_tag_name ('a')}];
  }
  for my $tr (@rows) {
    my @cell = @{$tr->cells};
    my @link = @{(shift @cell)->get_elements_by_tag_name ('code')};
    next unless @link;
    my @content = map { $_->text_content } grep { $_->title =~ /^attr-/ } @link;
    my @idl = map { $_->text_content } grep { $_->title =~ /^dom-/ } @link;
    my @idl_attr = grep { not /\(/ } @idl;
    my @method = map { s/\(\)$//; $_ } grep { /\(/ } @idl;
    my @event = map { $_->text_content } grep { $_->title =~ /^event-/ } @link;
    my $i = 1;
    for my $td (@cell) {
      my $value = $td->text_content;
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;
      if ($value eq 'Yes') {
        $value = 1;
      } elsif ($value eq 'Yes*') {
        $value = 'if-not-multiple';
      } elsif ($value eq 'Yes**') {
        $value = 'if-multiple';
      } elsif ($value =~ /^([\x20-\x7E]+)$/) {
        #
      } else {
        undef $value;
      }
      if (defined $value) {
        for my $type (@{$header[$i]}) {
          $Data->{input}->{content_attrs}->{$_}->{$type} = $value for @content;
          $Data->{input}->{idl_attrs}->{$_}->{$type} = $value for @idl_attr;
          $Data->{input}->{methods}->{$_}->{$type} = $value for @method;
          $Data->{input}->{events}->{$_}->{$type} = $value for @event;
        }
      }
      $i++;
    }
  }
}

use JSON::Functions::XS qw(perl2json_bytes_for_record);
print perl2json_bytes_for_record $Data;

## License: Public Domain.
