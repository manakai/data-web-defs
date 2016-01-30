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
    my $kwd = $row->{Keyword} // '';
    $div->inner_html ($kwd);
    $kwd = _t $div->text_content;
    die "Broken data: ", perl2json_bytes_for_record $row unless defined $kwd;

    $div->inner_html ($row->{Status} // '');
    my $status = lc _t $div->text_content;
    if ($status =~ /\A(proposal|incomplete proposal|proposed|unendorsed)\z/) {
      #
    } elsif ($status eq "doesn't belong in this registry") {
      next;
    } else {
      push @{$Data->{_errors} ||= []}, "Unknown status |$status| (meta $kwd)";
      $status = undef;
    }

    my $key = $kwd;
    $key =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

    my $data = $Data->{metadata_names}->{$key} ||= {};
    warn "Duplicate metadata name: |$kwd|" if defined $data->{name};
    $data->{name} = $kwd;

    $data->{whatwg_wiki_status} = $status;
    $data->{conforming} = 1 if defined $status and $status eq 'proposal';

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
  my $path = path (__FILE__)->parent->parent->child ('src/html-meta-names.txt');
  my $src_url;
  my $key;
  my $data;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^<(.+)>$/) {
      $src_url = $1;
      next;
    } elsif (/^(\S+(?> \S+)*)$/) {
      my $name = $1;
      $key = $name;
      $key =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if (defined $src_url and $src_url =~ m{^https://html.spec.whatwg.org/}) {
        $data = $Data->{metadata_names}->{$key} = {};
      } else {
        $data = $Data->{metadata_names}->{$key} ||= {};
      }
      $data->{name} ||= $name;
      $data->{url} ||= $src_url if defined $src_url;
      next;
    }

    if (/^  value (text|set of comma-separated tokens|color)$/) {
      #warn "Duplicate value type for |$key|" if defined $data->{value_type};
      $data->{value_type} ||= $1;
    } elsif (/^  item (text)$/) {
      warn "Duplicate item value type for |$key|" if defined $data->{item_type};
      $data->{item_type} = $1;
    } elsif (/^  enum (.+)$/) {
      $data->{allowed_values}->{$1} = 1;
    } elsif (/^  (unique|conforming)$/) {
      $data->{$1} = 1;
    } elsif (/^  unique per lang$/) {
      $data->{unique_per_lang} = 1;
    } elsif (/^  (non-conforming) -> (.+)$/) {
      $data->{preferred} = {type => 'meta', name => $2};
      delete $data->{conforming};
    } elsif (/^  -> <(\S+)>$/) {
      $data->{preferred} = {type => 'html_element', name => $1};
    } elsif (/^  -> rel=(\S+)$/) {
      $data->{preferred} = {type => 'rel', name => $1};
    } elsif (/^  spec (.+)$/) {
      $data->{url} = $1 if defined $src_url and $data->{url} eq $src_url;
      $data->{url} ||= $1;
    } elsif (/\S/) {
      die "Bad line: |$_|";
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
      if ($a =~ /\A(not allowed|external resource|hyperlink|annotation)\z/) {
        $data->{html_a} = $a;
      } elsif ($a eq 'img pop-up') {
        $data->{html_a} = 'hyperlink';
      } elsif ($a eq 'contextual external resource') {
        $data->{html_a} = 'external resource';
      } elsif ($a eq 'hyperlink annotation') {
        $data->{html_a} = 'annotation';
      } else {
        warn "Unknown effect |$a| ($kwd)";
      }
    }

    my $li = lc _t ($row->{'Effect on link'} // '');
    if (length $li) {
      if ($li =~ /\A(not allowed|external resource|hyperlink|annotation)\z/) {
        $data->{html_link} = $li;
      } else {
        warn "Unknown effect |$li| ($kwd)";
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
    if ($status =~ /\A(proposed|ratified)\z/) {
      $data->{microformats_wiki_status} = $1;
      $data->{conforming} = 1;
    } else {
      push @{$Data->{_errors} ||= []}, "Unknown status |$status| (rel $kwd)";
    }

    my $synonyms = _t ($row->{Synonyms} // '');
    if (length $synonyms) {
      $div->inner_html ($synonyms);
      $data->{microformats_wiki_synonyms_html} = _html $div;
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('src/html-link-types.txt');
  my $src_url;
  my $key;
  my $long_name;
  my $long_src_url;
  my $data;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^\s*#/) {
      next;
    } elsif (/^<(.+)>$/) {
      $src_url = $1;
      undef $key;
      undef $long_name;
      undef $long_src_url;
      next;
    } elsif (/^(\S+)$/) {
      my $name = $1;
      $key = $name;
      $key =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if (defined $src_url and $src_url =~ m{^https://html.spec.whatwg.org/}) {
        $data = $Data->{link_types}->{$key} = {};
      } else {
        $data = $Data->{link_types}->{$key} ||= {};
      }
      $data->{name} ||= $name;
      if (defined $src_url) {
        $data->{url} ||= $src_url;
        $data->{url} = $src_url if $src_url =~ /spec.whatwg.org/;
      }
      undef $long_name;
      undef $long_src_url;
      next;
    }

    if (/^  (conforming)$/) {
      $data->{$1} = 1;
    } elsif (/^  (non-conforming)$/) {
      delete $data->{conforming};
    } elsif (/^  (non-conforming) -> (.+)$/) {
      $data->{preferred} ||= {type => 'rel', name => $2};
      delete $data->{conforming};
    } elsif (/^  (whatwg wiki accepted)$/) {
      $data->{conforming} = 1;
    } elsif (/^  (a|link|rev) (hyperlink|external resource|annotation|not allowed)$/) {
      $data->{"html_$1"} = $2;
    } elsif (/^  (a|link) can support$/) {
      $data->{"html_${1}_supportable"} = 1;
    } elsif (/^  (atom)$/) {
      $data->{atom} = 1;
      $data->{atom_feed} = 1;
      $data->{atom_entry} = 1;
      unless ($key =~ /:/) {
        $long_name = q<http://www.iana.org/assignments/relation/> . $key;
        $Data->{link_types}->{$long_name}->{name} ||= $long_name;
        $Data->{link_types}->{$long_name}->{atom} ||= 1;
        $Data->{link_types}->{$long_name}->{atom_feed} ||= 1;
        $Data->{link_types}->{$long_name}->{atom_entry} ||= 1;
        $Data->{link_types}->{$long_name}->{url} ||= $long_src_url || $src_url if defined $long_src_url or defined $src_url;
        $Data->{link_types}->{$long_name}->{preferred} ||= {type => 'rel', name => $key};
      }
    } elsif (/^  (atom03|hal|http link|opensearch|maze|collection\+json|xml2rfc|core|xrd|webfinger|rdap|atom feed|atom entry)$/) {
      my $k = $1;
      $k =~ tr/ +/__/;
      $data->{$k} = 1;
      if (($k eq 'atom_feed' or $k eq 'atom_entry') and not $key =~ /:/) {
        $long_name = q<http://www.iana.org/assignments/relation/> . $key;
        $Data->{link_types}->{$long_name}->{name} ||= $long_name;
        $Data->{link_types}->{$long_name}->{atom_feed} ||= 1;
        $Data->{link_types}->{$long_name}->{atom_entry} ||= 1;
        $Data->{link_types}->{$long_name}->{url} ||= $long_src_url || $src_url if defined $long_src_url or defined $src_url;
        $Data->{link_types}->{$long_name}->{preferred} ||= {type => 'rel', name => $key};
      }
    } elsif (/^  (link|a)$/) {
      $data->{"html_$1"} ||= 1;
    } elsif (/^  (html)$/) {
      $data->{html_a} ||= 1;
      $data->{html_link} ||= 1;
    } elsif (/^  spec (.+)$/) {
      $data->{url} = $1 if defined $src_url and $data->{url} eq $src_url;
      $data->{url} ||= $1;
      $long_src_url = $1 || $src_url;
      $Data->{link_types}->{$long_name}->{url} = $long_src_url if defined $long_name;
    } elsif (/\S/) {
      die "Bad line: |$_|";
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/iana/link-relations.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{'link-relations-1'}->{records}}) {
    my $value = $record->{value};
    $value =~ tr/A-Z/a-z/;
    my $data = $Data->{link_types}->{$value} ||= {};
    $data->{name} ||= $record->{value};

    $data->{iana} = 1;
    my $spec = $record->{spec} // '';
    if ($spec =~ /^\[RFC([0-9]+)\]$/) {
      $data->{url} ||= qq<http://tools.ietf.org/html/rfc$1>;
    } elsif ($spec =~ /^\[(http:.+)\]$/) {
      $data->{url} ||= $1;
    }
  }
}

$Data->{link_types}->{made}->{preferred} = {type => 'rel', name => 'author'};

for (values %{$Data->{link_types}}) {
  if (not $_->{html_a} and not $_->{html_link} and not $_->{atom03} and not $_->{opensearch} and
      ($_->{atom} or $_->{http_link} or $_->{hal} or $_->{collection_json} or $_->{xml2rfc} or $_->{core} or $_->{xrd})) {
    $_->{conforming} ||= 1 if $_->{iana};
    $_->{conforming} ||= 1 if $_->{name} =~ /:/;
  }

  if ($_->{conforming}) {
    $_->{html_a} ||= 'not allowed';
    $_->{html_link} ||= 'not allowed';
  }
}

for (values %{$Data->{metadata_names}}, values %{$Data->{link_types}}) {
  if (defined $_->{url}) {
    if ($_->{url} =~ m{^https://html.spec.whatwg.org/#(.+)$}) {
      $_->{spec} = 'HTML';
      $_->{id} = $1;
      delete $_->{url};
    } elsif ($_->{url} =~ m{^https?://tools.ietf.org/html/rfc([0-9]+)$}) {
      $_->{spec} = 'RFC' . $1;
      delete $_->{url};
    } elsif ($_->{url} =~ m{^https?://tools.ietf.org/html/rfc([0-9]+)#(.+)$}) {
      $_->{spec} = 'RFC' . $1;
      $_->{id} = $2;
      delete $_->{url};
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
