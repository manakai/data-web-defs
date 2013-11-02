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

my %scheme;
for (@{$doc->document_element->child_nodes}) {
  next unless $_->local_name eq 'registry';
  my $title = $_->query_selector ('title')->text_content;
  $title =~ s/ URI Schemes$//;
  $title =~ tr/A-Z/a-z/;
  for (@{$_->children}) {
    next unless $_->local_name eq 'record';
    my $scheme = $_->query_selector ('value')->text_content;
    $scheme{$scheme} = $title;
  }
}

for my $scheme (sort { $a cmp $b } keys %scheme) {
  print "$scheme:\n";
  print "  iana=$scheme{$scheme}\n";
}

## License: Public Domain.
