use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $path = path (shift or die "Usage: perl $0 input.txt > output.json");

my $Data = {};

{
  my $alts = {};
  my $target;
  for (split /\x0D?\x0A/, $path->slurp_utf8) {
    if (/^#/ or /^\s+##/) {
      #
    } elsif (/^<(\S+)>$/) {
      die "$path: No alternative is specified for @$target" if $target;
      $target = [$1];
    } elsif (/^<\* role=(\S+)>$/) {
      die "$path: No alternative is specified for @$target" if $target;
      $target = ['ROLE', $1];
    } elsif (/^<(\S+) (\S+)>$/) {
      die "$path: No alternative is specified for @$target" if $target;
      $target = [$1, $2];
    } elsif (defined $target and /^  (.+)$/) {
      my $alt = $1;
      if ($alt eq '<math>') {
        $alts->{"@$target"} = {type => 'math'};
      } elsif ($alt =~ /^<(\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_element', name => $1};
      } elsif ($alt =~ /^<\* (\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_attr', name => $1};
      } elsif ($alt =~ /^<(input) (type)=(\S+)>$/) {
        $alts->{"@$target"} = {type => 'input', name => $3};
      } elsif ($alt =~ /^<th scope=(\S+)>$/) {
        $alts->{"@$target"} = {type => 'th', scope => $1};
      } elsif ($alt =~ /^<(\S+) (\S+)>$/) {
        $alts->{"@$target"} = {type => 'html_attr', name => $2, element => $1};
      } elsif ($alt =~ /^-$/) {
        $alts->{"@$target"} = {type => 'omit'};
      } elsif ($alt =~ /^([a-z-]+): (\S+)$/) {
        $alts->{"@$target"} = {type => 'css_prop', name => $1, value => $2};
      } elsif ($alt =~ /^([a-z-]+)$/) {
        $alts->{"@$target"} = {type => 'css_prop', name => $1};
      } elsif ($alt =~ /^#(script|progressive|comment|vcard|vevent|math|css|counter|text|textbox|title)$/) {
        $alts->{"@$target"} = {type => $1};
      } elsif ($alt =~ m{^N/A$}) {
        $alts->{"@$target"} = {type => 'none'};
      } else {
        die "$path: broken line: |  $alt|";
      }
      undef $target;
    } elsif (/\S/) {
      die "$path: broken line: |$_|";
    }
  }

  for (sort { $a cmp $b } keys %$alts) {
    my ($el, $attr) = split / /, $_;
    my $v = $Data->{elements}->{'http://www.w3.org/1999/xhtml'}->{$el} ||= {};
    $v = $v->{attrs}->{''}->{$attr} ||= {} if defined $attr;
    $v = $Data->{roles}->{$attr} ||= {} if $el eq 'ROLE';
    $v->{preferred} = $alts->{$_};
  }
}

print perl2json_bytes $Data;

## License: Public Domain.
