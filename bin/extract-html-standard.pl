use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use JSON::PS;
use MIME::Base64;
use Web::DOM::Document;

my $Data = {};

sub sp ($) {
  my $s = shift;
  $s =~ s/^\s+//;
  $s =~ s/\s+$//;
  $s =~ s/\s+/ /g;
  return $s;
} # sp

my $XRefNormalizeMap = {};
for my $s (
  'metadata content',
  'flow content',
  'phrasing content',
  'embedded content',
  'palpable content',
  'heading content',
  'sectioning content',
  'sectioning root',
  'interactive content',
  'form-associated element',
  'script-supporting elements',
  'text content',
) {
  my $t = $s;
  $t =~ s/ /-/g;
  $XRefNormalizeMap->{$t} = $s;
  $XRefNormalizeMap->{$t . '-2'} = $s;
  $XRefNormalizeMap->{$t . '-category'} = $s;
}

my $XRefLabelToActualIDMap = {};
sub normalize_xref ($) {
  my $mapped = $XRefNormalizeMap->{$_[0]} // $_[0];
  unless ($_[0] eq $mapped) {
    $XRefLabelToActualIDMap->{$mapped} = $_[0];
  }
  return $mapped;
} # normalize_xref

sub xref ($) {
  my $a = shift or return undef;
  if ($a->get_attribute ('href') =~ /#(.+)$/) {
    return normalize_xref $1;
  } else {
    return sp $a->text_content;
  }
} # xref

my $d = file (__FILE__)->dir->parent->subdir ('local/html.spec.whatwg.org/multipage/');
my $index_doc;
my $input_table;
my $xml_doc;
my @idl;
for my $f (($d->children)) {
  next unless $f =~ /\.html$/;
  my $doc = Web::DOM::Document->new;
  $doc->manakai_is_html (1);
  $doc->inner_html (decode 'utf-8', scalar $f->slurp);
  $index_doc = $doc if $f =~ /indices/;
  $xml_doc = $doc if $f =~ /xhtml/;
  $input_table ||= $doc->get_element_by_id ('input-type-attr-summary');

  for my $dl (@{$doc->query_selector_all ('dl.element')}) {
    my $heading = $dl->previous_element_sibling;
    while ($heading) {
      last if $heading->local_name =~ /^h[1-6]$/;
      $heading = $heading->previous_element_sibling;
    }
    next unless $heading;
    my $id = $heading->id;
    my $local_name;
    my $more_names = [];
    if ($id =~ /^the-([0-9a-z_-]+)-element$/) {
      $local_name = $1;
    } elsif ($id eq 'the-h1,-h2,-h3,-h4,-h5,-and-h6-elements') {
      $local_name = 'h1';
      push @$more_names, qw(h2 h3 h4 h5 h6);
    } elsif ($id eq 'the-sub-and-sup-elements') {
      $local_name = 'sub';
      push @$more_names, qw(sup);
    } elsif ($id eq 'custom-elements-core-concepts') {
      $local_name = '*-*';
      $id = 'autonomous-custom-element';
    } else {
      warn $id;
      next;
    }
    my $props = $Data->{elements}->{$local_name} ||= {};
    push @{$props->{additional_local_names} ||= []}, $_ for @$more_names;
    $props->{id} ||= $id;
    my $field;
    for (@{$dl->children}) {
      if ($_->local_name eq 'dt') {
        my $a = $_->first_element_child;
        if ($a and ($a->get_attribute ('href') =~ /#concept-element-(.+)$/)) {
          $field = $1;
        } else {
          undef $field;
        }
      } elsif ($_->local_name eq 'dd') {
        next unless defined $field;
        if ($field eq 'attributes') {
          my $text = $_->text_content;
          if ($text eq 'Global attributes' or
              $text eq 'Global attributes, except the is attribute' or
              $text eq 'Any other attribute that has no namespace (see prose).') {
            #
          } elsif ($text =~ /^If the element is not a child of an? ul or menu element: value \x{2014}/) {
            $props->{attrs}->{value}->{id} = 'attr-li-value';
            $props->{attrs}->{value}->{desc} = [split /\x{2014}\s*/, $text, 2]->[1];
          #} elsif ($text =~ /^Also, /) {
          #  #
          } else {
            my $code = $_->first_element_child;
            if ($code and
                $code->local_name eq 'code' and
                $code->first_child and
                $code->first_child->local_name eq 'a') {
              my $attr = $code->text_content;
              if (not $props->{attrs}->{$attr} or
                  $props->{attrs}->{$attr}->{id} eq 'attr-picture-source-type') {
                $props->{attrs}->{$attr}->{id} = xref $code->first_child;
                $props->{attrs}->{$attr}->{desc} = [split /\x{2014}\s*|has special semantics on this element:\s*/, $text, 2]->[1];
              } else {
                push @{$Data->{_errors} ||= []},
                    ['attrs', $local_name, 'Duplicate', $_->inner_html];
              }
            } else {
              push @{$Data->{_errors} ||= []},
                  ['attrs', $local_name, $_->inner_html];
            }
          }
        } elsif ($field eq 'categories') {
          my $text = $_->text_content;
          my $a = $_->first_element_child;
          if ($text =~ /^(\S+ \S+)\.$/ and $a and $a->local_name eq 'a') {
            my $title = xref $a || lc sp $a->text_content;
            $props->{categories}->{$title} = 1;
          } elsif ($text =~ /^(\S+ element inner content elements)\.$/ and $a and $a->local_name eq 'a') {
            my $title = xref $a || lc sp $a->text_content;
            $props->{categories}->{$title} = 1;
          } elsif ($text =~ /^If the (?:element has an? |)([a-z0-9-]+) attribute(?: is present|): ([a-zA-Z0-9- ]+ content)\.$/ and
                   defined ($a = $_->last_element_child) and
                   $a->local_name eq 'a') {
            my $attr_name = $1;
            my $title = xref $a || lc sp $a->text_content;
            $props->{states}->{"$attr_name-attr"}->{categories}->{$title} = 1;
          } elsif ($text =~ /^If the element is allowed in the body: ([a-zA-Z0-9- ]+ content)\.$/ and
                   defined ($a = $_->last_element_child) and
                   $a->local_name eq 'a') {
            my $attr_name = $1;
            my $title = xref $a || lc sp $a->text_content;
            $props->{states}->{"itemprop-attr"}->{categories}->{$title} = 1;
            $props->{states}->{"body-ok"}->{categories}->{$title} = 1;
          } elsif ($text =~ /^If the type attribute is (not |)in the Hidden state: / or
                   $text =~ /^.+ form-associated element\.$/) {
            my $key = defined $1 ? $1 ? 'categories_unless_hidden' : 'categories_if_hidden' : 'categories';
            for my $a (@{$_->query_selector_all ('a')}) {
              my $title = xref $a || lc sp $a->text_content;
              next if $title eq 'hidden-state-(type=hidden)';
              next if $title eq 'attr-input-type';
              $props->{$key}->{$title} = 1;
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
          if ($text =~ /^(\S+ \S+|Text|Transparent)\.?$/ and
              $a and $a->local_name eq 'a') {
            my $title = xref $a || lc sp $a->text_content;
            $props->{content_model}->{$title} = 1;
          } elsif ($text =~ /^(\S+ \S+), optionally intermixed with (\S+ \S+)\.?$/ and
                   $a and $a->local_name eq 'a') {
            my $title = xref $a || lc sp $a->text_content;
            $props->{content_model}->{$title} = 1;
            my $a2 = $_->last_element_child;
            my $title2 = xref $a2 || lc sp $a2->text_content;
            $props->{content_model}->{$title2} = 1;
          } elsif ($text eq 'Nothing.' or
                   $text eq 'Empty.' or
                   $text =~ /^Nothing \([^()]+\)\.$/) {
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
          } elsif ($text eq 'Same as for the source element.') {
            #
          } elsif ($text eq 'Text that gives a conformant style sheet.') {
            #
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
  } # dl.element

  for my $pre (@{$doc->query_selector_all ('pre > code.idl')}) {
    my $idl_html = $pre->inner_html;
    next if $idl_html =~ m{interface(?:(?> |<[^<>]+>)+)Example};
    if ($f =~ /obsolete/) {
      push @idl, '[*obsolete*]' . $idl_html;
    } else {
      push @idl, $idl_html;
    }
  }
} # files

$Data->{idl_fragments} = \@idl;

if ($index_doc) {
  for my $els (
    $index_doc->query_selector ('caption:-manakai-contains("List of elements")'),
  ) {
    $els = $els->parent_node;
    for my $tr (@{$els->query_selector_all ('tbody > tr')}) {
      my @cell = @{$tr->cells};
      next unless @cell >= 2;
      my $th = $cell[0];
      next unless $th->local_name eq 'th';
      my $td = $cell[1];
      my $a = $th->query_selector ('code > a') or next;
      $Data->{elements}->{$a->text_content}->{desc} = $td->text_content;
    }
  } # $els

  for my $attrs (
    $index_doc->query_selector ('caption:-manakai-contains("List of attributes")'),
    $index_doc->query_selector ('caption:-manakai-contains("List of event handler content attributes")'),
  ) {
    next unless defined $attrs;
    $attrs = $attrs->parent_node;
    for my $tr (@{$attrs->query_selector_all ('tbody > tr')}) {
      my @cell = @{$tr->cells};
      next unless @cell >= 3;
      my $th = $cell[0];
      next unless $th->local_name eq 'th';
      my $td = $cell[1];
      my $attr_name = sp $th->text_content;
      if ($td->text_content =~ /HTML\s+elements/) {
        my $a = $td->query_selector ('a') or next;
        my $desc = sp $cell[2]->text_content;
        $Data->{global_attrs}->{$attr_name}
            = {id => xref $a, desc => $desc};
      } elsif ($attr_name =~ /^on/) {
        my $a = $td->query_selector ('a') or next;
        my $desc = sp $cell[2]->text_content;
        $Data->{elements}->{$a->text_content}->{attrs}->{$attr_name}
            ->{desc} ||= $desc;

      }
    }
  } # $attrs
}

{
  my @header;
  my @rows = @{$input_table->query_selector_all ('tr')};
  for my $th (@{(shift @rows)->cells}) {
    push @header, [map {
      my $href = $_->get_attribute ('href');
      my @type;
      while ($href =~ /\(type=(.+?)\)/g) {
        push @type, $1;
      }
      @type;
    } @{$th->get_elements_by_tag_name ('a')}];
  }
  for my $tr (@rows) {
    my @cell = @{$tr->cells};
    my @link = @{(shift @cell)->query_selector_all ('code > a')};
    next unless @link;
    my @content = map { $_->text_content } grep { xref ($_) =~ /^attr-/ } @link;
    my @idl = map { $_->text_content } grep { xref ($_) =~ /^dom-/ } @link;
    my @idl_attr = grep { not /\(/ } @idl;
    my @method = map { s/\(\)$//; $_ } grep { /\(/ } @idl;
    my @event = map { $_->text_content } grep { xref ($_) =~ /^event-/ } @link;
    my $i = 1;
    for my $td (@cell) {
      my $value = sp $td->text_content;
      if ($value eq 'Yes') {
        $value = 1;
      } elsif ($value eq 'Yes*') {
        $value = 'if-not-multiple';
      } elsif ($value eq "Yes\x{2020}") {
        $value = 'if-text-field';
      } elsif ($value eq 'default' or
               $value eq 'default/on' or
               $value eq 'value' or
               $value eq 'filename') {
        #
      } elsif ($value =~ /^([\x20-\x7E]+)$/) {
        push @{$Data->{_errors} ||= []}, "Unparsable |input| cell: |$value|";
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

$Data->{category_label_to_id} = $XRefLabelToActualIDMap;

print perl2json_bytes_for_record $Data;

if ($xml_doc) {
  my $a = $xml_doc->query_selector ('a[href^="data:application/xml-dtd;"]');
  if (defined $a) {
    my $data = $a->get_attribute ('href');
    $data =~ s{^data:application/xml-dtd;base64,}{};
    $data =~ s/%([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
    $data = MIME::Base64::decode_base64 $data;

    my $dtd_f = file (__FILE__)->dir->parent->file ('data', 'xhtml-charrefs.dtd');
    print { $dtd_f->openw } $data;
  } else {
    warn "WARNING! XHTML DTD not found";
  }
} else {
  warn "WARNING! XHTML spec not found";
}

## License: Public Domain.
