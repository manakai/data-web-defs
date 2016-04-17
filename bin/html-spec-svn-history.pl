use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use lib glob path (__FILE__)->parent->parent->child ('local/modules/*/lib');
use Git::Parser::Log;
use Web::DOM::Document;

my $dir = $ENV{HTML_REPO_DIR} or die "No |HTML_REPO_DIR| environment variable";

my $log = `cd $dir && git log --raw --format=raw` or die "git log failed";

my $parsed = Git::Parser::Log->parse_format_raw ($log);

my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
$doc->inner_html (q{
  <!DOCTYPE HTML>
  <title>HTML revision history 2004-2015</title>
  <style>
    table {
      width: 100%;
    }
    tr:nth-child(2n) {
      background: #eee;
      color: black;
    }
    th {
      height: 2em;
    }
    th {
      white-space: nowrap;
    }
    td.date span {
      white-space: nowrap;
      font-size: 90%;
    }
    td.topics {
      text-align: center;
    }
    td.topics > p {
      margin: 0;
      padding: 0;
      font-size: 80%;
    }
    td.bug {
      text-align: center;
      font-size: 90%;
    }
    td.body {
      word-break: break-word;
    }
  </style>
  <table>
    <thead>
      <tr>
        <th title="Subversion revision number">SVN #
        <th>Date
        <th>Topics
        <th title="W3C Bugzilla">Bug #
        <th>Commit message
    <tbody>
  </table>
});
my $tbody = $doc->get_elements_by_tag_name ('tbody')->[0];

for my $rev (reverse @{$parsed->{commits}}) {
  next unless defined $rev->{svn_revision};

  my $tr = $doc->create_element ('tr');
  for my $th ($doc->create_element ('th')) {
    my $a = $doc->create_element ('a');
    $a->text_content ($rev->{svn_revision});
    $a->href ('https://github.com/whatwg/html/commit/' . $rev->{commit});
    $th->append_child ($a);
    $tr->append_child ($th);
  }
  for my $td ($doc->create_element ('td')) {
    my $time = $doc->create_element ('time');
    my @t = gmtime $rev->{author}->{time};
    $time->datetime (sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3]);
    $time->inner_html (sprintf '%04d <span>%02d-%02d</span>', $t[5]+1900, $t[4]+1, $t[3]);
    $td->append_child ($time);
    $td->set_attribute (class => 'date');
    $tr->append_child ($td);
  }
  my $body = $rev->{body};
  $body =~ s/\x0A+git-svn-id: .+$//s;
  $body =~ s/^\[\w*\]\s*//;
  $body =~ s/^\([0-9]+\)\s*//;
  my @topic;
  if ($body =~ s/\s+Affected topics: (.+)$//) {
    @topic = split /, /, $1;
  }
  my $w3c_bug;
  if ($body =~ s{\s+Fixing https?://www.w3.org/Bugs/Public/show_bug.cgi\?id=([0-9]+)$}{}) {
    $w3c_bug = $1;
  }
  for my $td ($doc->create_element ('td')) {
    $td->set_attribute (class => 'topics');
    for (@topic) {
      my $p = $doc->create_element ('p');
      $p->text_content ($_);
      $td->append_child ($p);
    }
    $tr->append_child ($td);
  }
  for my $td ($doc->create_element ('td')) {
    if (defined $w3c_bug) {
      my $a = $doc->create_element ('a');
      $a->href ('https://www.w3.org/Bugs/Public/show_bug.cgi?id=' . $w3c_bug);
      $a->text_content ($w3c_bug);
      $td->append_child ($a);
    }
    $td->set_attribute (class => 'bug');
    $tr->append_child ($td);
  }
  for my $td ($doc->create_element ('td')) {
    $td->text_content ($body);
    $td->set_attribute (class => 'body');
    $tr->append_child ($td);
  }
  $tbody->append_child ($tr);
}

binmode STDOUT, qw(:encoding(utf-8));
print $doc->inner_html;

## License: Public Domain.
