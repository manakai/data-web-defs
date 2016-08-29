use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $RootPath = path (__FILE__)->parent->parent;
my $Data = {};

for ($RootPath->child ('src/task-sources.txt')->lines_utf8) {
  if (/^\s*#/) {
    #
  } elsif (/^(~|)([0-9A-Za-z_.: -]+?)(\*|)(?:\[([A-Z0-9:._-]+)\]|)$/) {
    $Data->{task_sources}->{$2} ||= {};
    $Data->{task_sources}->{$2}->{multiple} = 1 if $3;
    $Data->{task_sources}->{$2}->{spec} = $4 if defined $4;
    $Data->{task_sources}->{$2}->{id} = $2 if defined $4 and $4 eq 'HTML';
    $Data->{task_sources}->{$2}->{status} = 'Obsolete' if $1;
  } elsif (/\S/) {
    die "Broken line: $_";
  }
}

{
  my $json = json_bytes2perl $RootPath->child ('data/dom.json')->slurp;
  my $rp = $json->{idl_defs}->{ReferrerPolicy};
  my $value = $rp->[1]->{value};
  for (keys %{$value->[1]}) {
    $Data->{referrer_policies}->{$_}->{value} = $_;
    $Data->{referrer_policies}->{$_}->{idl} = 'MAY';
    $Data->{referrer_policies}->{$_}->{http} = 'MAY';
    $Data->{referrer_policies}->{$_}->{meta} = 'MAY';
    $Data->{referrer_policies}->{$_}->{attr} = 'MAY';
    $Data->{referrer_policies}->{$_}->{attr_state} = '"'.$_.'"';
    $Data->{referrer_policies}->{$_}->{url} = 'https://w3c.github.io/webappsec-referrer-policy/#referrer-policy-' . $_;
    $Data->{referrer_policies}->{$_}->{attr_keyword_url} = 'https://html.spec.whatwg.org/#attr-referrerpolicy-' . $_ . '-keyword';
  }
  $Data->{referrer_policies}->{''}->{url} = 'https://w3c.github.io/webappsec-referrer-policy/#referrer-policy-empty-string';
  $Data->{referrer_policies}->{''}->{attr_keyword_url} = 'https://html.spec.whatwg.org/#referrer-policy-attribute';
  $Data->{referrer_policies}->{''}->{attr_state} = 'empty string';
  $Data->{referrer_policies}->{$_}->{meta} = 'MUST NOT',
  $Data->{referrer_policies}->{$_}->{url} = 'https://html.spec.whatwg.org/#meta-referrer'
      for qw(always never default origin-when-crossorigin);
  $Data->{referrer_policies}->{always}->{preferred} = 'unsafe-url';
  $Data->{referrer_policies}->{never}->{preferred} = 'no-referrer';
  $Data->{referrer_policies}->{default}->{preferred} = 'no-referrer-when-downgrade';
  $Data->{referrer_policies}->{'origin-when-crossorigin'}->{preferred} = 'origin-when-cross-origin';
  $Data->{referrer_policies}->{'no-referrer'}->{rel} = 'noreferrer';
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
