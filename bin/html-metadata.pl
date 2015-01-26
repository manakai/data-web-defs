use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::PS;
use Web::DOM::Document;

my $Data = {};
my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
my $div = $doc->create_element ('div');

sub _t ($) {
  my $s = shift;
  $s =~ s/\A\s+//;
  $s =~ s/\s+\z//;
  return $s;
} # _t

sub _html ($) {
  my $el = shift;
  for ($el->query_selector_all ('a')->to_list) {
    $_->href ($_->href);
  }
  return $el->inner_html;
} # _html

{
  $doc->manakai_set_url ('https://wiki.whatwg.org/wiki/MetaExtensions');
  my $path = path (__FILE__)->parent->parent->child ('local/MetaExtensions.json');
  my $table = json_bytes2perl $path->slurp;
  for my $row (@{$table->{rows}}) {

    $div->inner_html ($row->{Status} // '');
    my $status = lc _t $div->text_content;
    if ($status =~ /\A(proposal|incomplete proposal|unendorsed)\z/) {
      #
    } elsif ($status eq "doesn't belong in this registry") {
      next;
    } else {
      warn "Unknown status |$status|";
      $status = undef;
    }

    my $kwd = $row->{Keyword} // '';
    $div->inner_html ($kwd);
    $kwd = _t $div->text_content;
    die "Broken data: ", perl2json_bytes_for_record $row unless defined $kwd;
    my $key = $kwd;
    $key =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

    my $data = $Data->{metadata_names}->{$key} ||= {};
    warn "Duplicate metadata name: |$kwd|" if defined $data->{name};
    $data->{name} = $kwd;

    $data->{whatwg_wiki_status} = $status;
    $data->{conforming} = 1 if $status eq 'proposal';

    my $desc = _t ($row->{'Brief description'} // '');
    if (length $desc) {
      my $d = $desc;
      $d =~ s{<br\s*/?>}{\n}g;
      $div->inner_html ($d);
      if ($d =~ /</) {
        $data->{desc} = $div->text_content;
        $data->{whatwg_wiki_desc_html} = _html $div;
      } else {
        $data->{desc} = $div->text_content;
      }
    }

    my $link = _t ($row->{'Link to specification'} // $row->{'Link to more details'} // '');
    if (length $link and not $link eq 'No specification yet' and not $link eq 'none') {
      $div->inner_html ($link);
      if ($link =~ m{^<a [^<>]+>[^<]+</a>$}) {
        $data->{whatwg_wiki_spec_link_label} = $div->text_content;
        $data->{url} = $div->first_child->href;
      } else {
        $data->{whatwg_wiki_spec_link_html} = _html $div;
      }
    }
    if (defined $row->{'Link to more details'} and defined $row->{'Link to specification'}) {
      warn "There are both |Link to more details| and |Link to specification| fields";
    }

    my $synonyms = _t ($row->{Synonyms} // '');
    if (length $synonyms) {
      $div->inner_html ($synonyms);
      $data->{whatwg_wiki_synonyms_html} = _html $div;
    }

    $div->inner_html ($row->{'Registration requirement failure'} // '');
    my $failure = _t $div->inner_html;
    if (length $failure) {
      $data->{whatwg_wiki_failure_reason} = $failure;
    }
  }
}

{
  $doc->manakai_set_url ('http://microformats.org/wiki/existing-rel-values');
  my $path = path (__FILE__)->parent->parent->child ('local/RelExtensions.json');
  my $table = json_bytes2perl $path->slurp;
  for my $row (@{$table->{rows}}) {
    $div->inner_html (_t ($row->{Keyword} // ''));
    my $kwd = $div->text_content;
    my $key = $kwd;
    $key =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    my $data = $Data->{link_types}->{$key} ||= {};
    warn "Duplicate type |$key|" if defined $data->{name};
    $data->{name} = $kwd;
    my $fc = $div->first_element_child;
    if (defined $fc and $fc->local_name eq 'a' and
        not $fc->class_list->contains ('new')) {
      $data->{microformats_wiki_url} = $fc->href;
    }

    my $desc = _t ($row->{'Brief description'} // '');
    if (length $desc) {
      my $d = $desc;
      $d =~ s{<br\s*/?>}{\n}g;
      $div->inner_html ($d);
      if ($d =~ /</) {
        $data->{desc} = $div->text_content;
        $data->{microformats_wiki_desc_html} = _html $div;
      } else {
        $data->{desc} = $div->text_content;
      }
    }

    my $a = lc _t ($row->{'Effect on a, area'} // '');
    if (length $a) {
      if ($a =~ /\A(not allowed|external resource|hyperlink)\z/) {
        $data->{html_a} = $a;
      } elsif ($a eq 'img pop-up' or $a eq 'contextual external resource') {
        $data->{html_a} = 'hyperlink';
      } else {
        warn "Unknown effect |$a|";
      }
    }

    my $li = lc _t ($row->{'Effect on link'} // '');
    if (length $li) {
      if ($li =~ /\A(not allowed|external resource|hyperlink)\z/) {
        $data->{html_link} = $li;
      } else {
        warn "Unknown effect |$li|";
      }
    }

    my $link = _t ($row->{'Link to specification'} // '');
    if (length $link and not $link eq 'No formal specification') {
      $div->inner_html ($link);
      if ($link =~ m{^<a [^<>]+>[^<]+</a>$}) {
        $data->{microformats_wiki_spec_link_label} = $div->text_content;
        $data->{url} = $div->first_child->href;
      } else {
        $data->{microformats_wiki_spec_link_html} = _html $div;
      }
    }

    $div->inner_html ($row->{Status} // '');
    my $status = lc _t $div->text_content;
    if ($status =~ /\A(proposed)\z/) {
      $data->{microformats_wiki_status} = $1;
    } else {
      warn "Unknown status |$status|";
    }

    my $synonyms = _t ($row->{Synonyms} // '');
    if (length $synonyms) {
      $div->inner_html ($synonyms);
      $data->{microformats_wiki_synonyms_html} = _html $div;
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
