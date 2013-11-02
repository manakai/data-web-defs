use strict;
use warnings;
use Encode;
use Path::Class;
use lib glob file (__FILE__)->dir->subdir ('modules', '*', 'lib');
use Web::XML::Parser;
use Web::DOM::Document;

my $doc = Web::DOM::Document->new;
{
  local $/ = undef;
  Web::XML::Parser->new->parse_char_string
      ((decode 'utf-8', scalar <>) => $doc);
}

my @scheme;
for (@{$doc->query_selector_all ('table > tbody > tr > td:first-child')}) {
  my $code = $_->query_selector ('code');
  my $scheme;
  if ($code) {
    $scheme = $code->text_content;
  } else {
    $scheme = $_->text_content;
  }
  $scheme =~ s/\]\]$//;
  $scheme =~ s/:$//;
  next unless $scheme =~ /\A[0-9A-Za-z_+.%*-]*\z/;
  $scheme =~ tr/A-Z/a-z/;
  $scheme =~ s/(%[0-9A-Fa-f]{2})/uc $1/ge;
  push @scheme, $scheme;
}

for my $scheme (@scheme) {
  print "$scheme:\n";
  unless ($scheme =~ /\A[a-z*][*0-9a-z+.-]*\z/) {
    print "  ill-formed\n";
  }
  if ($scheme =~ /\*/ and $scheme ne 'ht*tp') {
    print "  wildcard\n";
  }
}

## License: Public Domain.
