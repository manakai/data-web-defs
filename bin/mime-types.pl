use strict;
use warnings;
use Encode;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules', '*', 'lib');
use JSON::PS;
use Web::XML::Parser;
use Web::DOM::Document;

sub parse ($) {
  my @doc;
  for (glob path (__FILE__)->parent->parent->child ('local', $_[0])) {
    my $path = path ($_);
    warn "$path...\n";
    my $doc = Web::DOM::Document->new;
    local $/ = undef;
    if ($_[0] =~ /html/) {
      $doc->manakai_is_html (1);
      $doc->inner_html (decode 'utf-8', $path->slurp);
    } else {
      Web::XML::Parser->new->parse_char_string
          ((decode 'utf-8', $path->slurp) => $doc);
    }
    push @doc, $doc;
  }
  return @doc;
} # parse

my $Data = {};
for my $doc (parse 'sw-mime-types-xml-*') {
  for (@{$doc->query_selector_all ('table > tbody > tr')}) {
    my $cells = $_->query_selector_all ('td');
    my $type = ($cells->[0] or next)->text_content;
    $type =~ m{^\s*([0-9A-Za-z_+./*-]+)\s*$} or next;
    $type = $1;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type}
        = $type =~ m{\A[^/]*\*[^/]*\z} ? 'type_only_pattern'
        : $type =~ m{\A[^/]+\z} ? 'type_only'
        : $type =~ m{\A[^/*]+/\*\z} ? 'type'
        : $type =~ m{\A\*/\*\+[^/*]+\z} ? 'suffix'
        : $type =~ m{\*} ? 'pattern'
        : 'subtype';
    if ($Data->{$type}->{type} eq 'suffix' and
        defined $cells->[2] and
        $cells->[2]->text_content =~ m{^\s*([0-9A-Za-z_+.-]+/[0-9A-Za-z_+.-]+)\s*$}) {
      $Data->{$type}->{structured_syntax_type} = lc $1;
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/iana/mime-types.json');
  my $json = json_bytes2perl $path->slurp;
  for my $t (keys %{$json->{registries}}) {
    my $type = $t;
    $type =~ tr/A-Z/a-z/;
    $Data->{"$type/*"}->{type} = 'type';
    $Data->{"$type/*"}->{iana} = 'permanent';
    for my $record (@{$json->{registries}->{$t}->{records}}) {
      my $subtype = $record->{name};
      my $info = '';
      if ($subtype =~ s/\s+-\s+(.+)$//s) {
        $info = $1;
      } elsif ($subtype =~ s/\s+\((.+)\)\s*$//s) {
        $info = $1;
      } elsif (not $subtype =~ /\A[A-Za-z0-9+._-]+\z/) {
        die "Badly formed MIME subtype |$subtype|";
      }
      $subtype =~ tr/A-Z/a-z/;
      $Data->{"$type/$subtype"}->{type} = 'subtype';
      $Data->{"$type/$subtype"}->{iana} = 'permanent';
      $Data->{"$type/$subtype"}->{iana_template_url} = "https://www.iana.org/assignments/media-types/" . $record->{file}
          if length $record->{file};
      $Data->{"$type/$subtype"}->{deprecated} ||= 'deprecated'
          if $info =~ /^DEPRECATED/;
      $Data->{"$type/$subtype"}->{deprecated} ||= 'obsolete'
          if $info =~ /^OBSOLETE/;
      if ($info =~ m{in favor of (\S+/\S+)}) {
        $Data->{"$type/$subtype"}->{preferred_type} = lc $1;
      }
      warn "$type/$subtype $info"
          if length $info and not $info =~ /^(?:DEPRECATED|OBSOLETE)/;
    }
  }
}

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/iana/mime-type-provisional.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{'provisional-standard-types'}->{records}}) {
    my $type = $record->{name};
    $type =~ m{\A[0-9A-Za-z_.+/-]+\z} or next;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} = 'subtype';
    $Data->{$type}->{iana} ||= 'provisional';
  }
}

{
  my $path = path (__FILE__)->parent->parent->child
      ('intermediate/mime-type-provisional.json');
  my $json = json_bytes2perl $path->slurp;
  for my $type (keys %{$json->{mime_types}}) {
    $type =~ m{\A[0-9A-Za-z_.+/-]+\z} or next;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} = 'subtype';
  }
}

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/iana/mime-type-suffixes.json');
  my $json = json_bytes2perl $path->slurp;
  for my $record (@{$json->{registries}->{'structured-syntax-suffix'}->{records}}) {
    my $suffix = $record->{suffix};
    $suffix =~ /\A\+[0-9A-Za-z_.-]+\z/ or next;
    $suffix =~ tr/A-Z/a-z/;
    $Data->{"*/*$suffix"}->{type} = 'suffix';
    $Data->{"*/*$suffix"}->{iana} = 'permanent';
  }
}

{
  my $path = path (__FILE__)->parent->parent->child
      ('local/jshttp-mime-types.json');
  my $json = json_bytes2perl $path->slurp;
  for my $type (keys %$json) {
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} ||= 'subtype';
    $Data->{$type}->{extensions}->{lc $_} = 1 for @{$json->{$type}->{extensions} or []};
    $Data->{$type}->{compressible} = $json->{$type}->{compressible}
        if defined $json->{$type}->{compressible};
  }
}

for (split /\x0D?\x0A/, path (__FILE__)->parent->parent->child ('local/apache-mime-types')->slurp) {
  if (m{\A(?:\# )?([0-9A-Za-z_+.-]+/[0-9A-Za-z_+.-]+)\s*([0-9A-Za-z_-][0-9A-Za-z_\s-]*)?\z}) {
    my $type = $1;
    my $exts = [split /\s+/, lc ($2 // '')];
    $Data->{$type}->{type} ||= 'subtype';
    $Data->{$type}->{extensions}->{$_} = 1 for @$exts;
  }
}

my $type;
my $attr;
for (split /\x0D?\x0A/, path (__FILE__)->parent->parent->child ('src/mime-types.txt')->slurp) {
  if (m{^([0-9A-Za-z_+./*\#-]+)$}) {
    $type = $1;
    $type =~ tr/A-Z/a-z/;
    $Data->{$type}->{type} ||= $type =~ m{/\*$} ? 'type' : $type =~ m{^\*/\*\+} ? 'suffix' : $type =~ /\*/ ? 'pattern' : 'subtype';
    undef $attr;
    my $t2 = $type;
    $t2 =~ s{/.+$}{/*}s;
    if (not $type eq $t2 and $t2 =~ m{/\*$}) {
      $Data->{$t2} ||= {type => 'type'};
    }
  } elsif (m{^  ([0-9A-Za-z_-]+)$}) {
    $Data->{$type}->{$1} ||= 1;
  } elsif (m{^  ([0-9A-Za-z_.-]+)=""$}) {
    $attr = $1;
    $attr =~ tr/A-Z/a-z/;
    $Data->{$type}->{params}->{$attr} ||= {};
  } elsif (m{^  ([0-9A-Za-z_-]+):(\S+)$}) {
    $Data->{$type}->{$1} ||= $2;
  } elsif (m{^  ([0-9A-Za-z_-]+)\@(.+)$}) {
    my $prop = $1;
    my $values = [split /\s+/, $2];
    if ($prop eq 'mac') {
      $prop = 'mac_types';
      $values = [map { substr ($_ . '   ', 0, 4) } @$values];
    } elsif ($prop eq 'mac_creator') {
      $prop = 'mac_creator';
    } elsif ($prop eq 'ext') {
      $prop = 'extensions';
      $values = [map { lc $_ } @$values];
    }
    $Data->{$type}->{$prop}->{$_} = 1 for @$values;
  } elsif (m{^  ->\s*(\S+)\s*\((SHOULD)\)$}) {
    $Data->{$type}->{deprecated} = $2;
    $Data->{$type}->{preferred_type} = $1;
  } elsif (m{^  ->\s*(\S+)$}) {
    $Data->{$type}->{preferred_type} = $1;
  } elsif (m{^  #(\S+)$}) {
    $Data->{$type}->{fragment} = $1;
    if ($1 eq 'xpointer:rfc7303') {
      $Data->{$type}->{xpointer_schemes}->{''}->{element} = 'MUST';
      $Data->{$type}->{xpointer_schemes}->{'#'}->{shorthand} = 'MUST';
      $Data->{$type}->{xpointer_schemes}->{'#'}->{other} = 'MAY';
    }
  } elsif (m{^  ## }) {
    #
  } elsif (defined $attr and m{^    (\S+)$}) {
    $Data->{$type}->{params}->{$attr}->{$1} = 1;
  } elsif (/\S/) {
    die "Broken line: $_";
  }
}

for (split /\x0D?\x0A/, path (__FILE__)->parent->parent->child ('src/mime.types')->slurp) {
  if (/^([^\s;]+)\s+(\S.*)/) {
    my $type = lc $1;
    my $exts = [split /\s+/, lc $2];
    $Data->{$type}->{type} = 'subtype';
    $Data->{$type}->{extensions}->{$_} = 1 for @$exts;
  } elsif (/^([^\s;]+)\s*$/) {
    $Data->{lc $1}->{type} = 'subtype';
  } elsif (/^([^\s;]+); ([^=]+)=(.*?)\s*$/) {
    $Data->{lc $1}->{type} = 'subtype';
    $Data->{lc $1}->{params}->{lc $2}->{values}->{$3} ||= {};
  } elsif (/\S/) {
    die "Broken line |$_|";
  }
}

{
  my $path = path (__FILE__)->parent->parent->child ('local/wpa-mime-types.json');
  my $json = json_bytes2perl $path->slurp;
  for my $key (keys %$json) {
    my $type = $key;
    $type =~ tr/A-Z/a-z/;
    next unless $Data->{$type};
    next if $json->{$key}->{parse_error};
    my $ext = $json->{$key}->{exts};
    if (defined $ext) {
      for my $ext (ref $ext ? keys %$ext : $ext) {
        $ext =~ tr/A-Z/a-z/;
        $Data->{$type}->{extensions}->{$ext} = 1;
      }
    }
    if (defined $json->{$key}->{intended_usage}) {
      $Data->{$type}->{iana_intended_usage} = $json->{$key}->{intended_usage};
      if ($json->{$key}->{intended_usage} eq 'obsolete') {
        $Data->{$type}->{obsolete} = 1;
      }
    }
  }
}

for (split /\x0D?\x0A/, path (__FILE__)->parent->parent->child ('src/mime-type-related.txt')->slurp) {
  my ($t1, $t2) = split /\s+/, $_;
  next unless defined $t2;
  next unless length $t1;
  $t1 = lc $t1;
  $t2 = lc $t2;
  $Data->{$t1} ||= {type => 'subtype'};
  $Data->{$t2} ||= {type => 'subtype'};
  $Data->{$t1}->{related}->{$t2} ||= {};
  $Data->{$t2}->{related}->{$t1} ||= {};
}

$Data->{'/'}->{type} = 'type_only';
$Data->{'*/*'}->{type} = 'subtype';
$Data->{'drawing/x-dwf (old)'}->{type} = 'subtype';
$Data->{'drawing/x-dwf (old)'}->{extensions}->{dwf} = 1;
for (keys %$Data) {
  if ($Data->{$_}->{params} and $Data->{$_}->{params}->{charset}) {
    $Data->{$_}->{text} = 1 unless m{^(?:text|message/multipart)/};
  }
  $Data->{$_}->{preferred_cte} ||= 'quoted-printable' if $Data->{$_}->{text};
}

{
  my @type = keys %$Data;
  for (@type) {
    if (m{^([^/]+)/}) {
      $Data->{"$1/*"} ||= {type => 'type'};
    }
    if (m{\+([^/+]+)$}) {
      $Data->{"*/*+$1"} ||= {type => 'suffix'};
    }
  }
}

for my $type (keys %$Data) {
  $Data->{$type}->{any_xml} = 1 if $Data->{$type}->{xml};
  $Data->{$type}->{text} = 1 if $Data->{$type}->{any_xml};
  $Data->{$type}->{text} = 1 if $Data->{$type}->{json};
  $Data->{$type}->{navigate_text} = 1 if $Data->{$type}->{json};
  $Data->{$type}->{navigate_text} = 1 if $Data->{$type}->{javascript};
  $Data->{$type}->{obsolete} = 1
      if ($Data->{$type}->{deprecated} // '') eq 'obsolete';
}
delete $Data->{$_}->{deprecated},
delete $Data->{$_}->{obsolete} for qw(text/javascript);

my $ExtsData = {};
for my $type (keys %$Data) {
  my $def = $Data->{$type};
  next unless $def->{type} eq 'subtype';
  for (keys %{$def->{extensions} or {}}) {
    $ExtsData->{$_}->{mime_types}->{$type} = 1;
  }
}
my $ExtToGenericMIMETypes = {qw(
  htm text/html
  html text/html
  txt text/plain
  text text/plain
  dat application/octet-stream
  xml text/xml
  _ application/xml
  json application/json
)};
my $GenericMIMETypes = {reverse %$ExtToGenericMIMETypes};
delete $ExtToGenericMIMETypes->{_};
for my $ext (keys %$ExtsData) {
  my $mimes = $ExtsData->{$ext}->{mime_types};
  next unless keys %$mimes;
  $ExtsData->{$ext}->{mime_type} = [sort {
    my $at = $Data->{$a};
    my $bt = $Data->{$b};
    ($GenericMIMETypes->{$a} || '') cmp ($GenericMIMETypes->{$b} || '') ||
    ($bt->{browser} || 0) <=> ($at->{browser} || 0) ||
    ($bt->{iana} || '') cmp ($at->{iana} || '') ||
    (length $a) <=> (length $b) ||
    $b cmp $a;
  } keys %$mimes]->[0];
}
for (keys %$ExtToGenericMIMETypes) {
  $ExtsData->{$_}->{mime_type} = $ExtToGenericMIMETypes->{$_};
}
my $ExtToMIMETypes = {qw(
  ogg application/ogg
  xht application/xhtml+xml
  xhtml application/xhtml+xml
  mp3 audio/mpeg
)};
for (keys %$ExtToMIMETypes) {
  $ExtsData->{$_}->{mime_type} = $ExtToMIMETypes->{$_};
  $ExtsData->{$_}->{mime_types}->{$ExtToMIMETypes->{$_}} = 1;
}
for (values %$ExtsData) {
  my @t = keys %{$_->{mime_types} or {}};
  for my $t1 (@t) {
    for my $t2 (@t) {
      $Data->{$t1}->{related}->{$t2} ||= {};
      $Data->{$t2}->{related}->{$t1} ||= {};
    }
  }
}
for (keys %$Data) {
  delete $Data->{$_}->{related}->{$_} if $Data->{$_}->{related};
}

path (__FILE__)->parent->parent->child ('data/mime-types.json')->spew
    (perl2json_bytes_for_record $Data);
path (__FILE__)->parent->parent->child ('data/file-name-extensions.json')->spew
    (perl2json_bytes_for_record $ExtsData);

## License: Public Domain.
