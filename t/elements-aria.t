use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $path = path (__FILE__)->parent->parent->child ('data/elements.json');
my $aria_path = path (__FILE__)->parent->parent->child ('data/aria.json');
my $Data = json_bytes2perl $path->slurp;
my $ARIAData = json_bytes2perl $aria_path->slurp;
my $Failed = 0;

sub error ($) {
  warn "$_[0]\n";
  $Failed = 1;
} # error

sub error_ignore ($) {
  warn "$_[0]\n";
} # error_ignore

for my $ns (keys %{$Data->{elements}}) {
  for my $ln (keys %{$Data->{elements}->{$ns}}) {
    next if $ln eq '*';
    my $edef = $Data->{elements}->{$ns}->{$ln};
    my $aria = $edef->{aria} || $Data->{elements}->{$ns}->{'*'}->{aria} || {};
    for my $cond (keys %$aria) {
      for my $role ($aria->{$cond}->{default_role},
                    keys %{$aria->{$cond}->{allowed_roles} or {}}) {
        next unless defined $role;
        my $role_def = $ARIAData->{roles}->{$role};

        for my $category (keys %{$role_def->{categories}}) {
          if ($edef->{categories}->{$category}) {
            #
          } elsif ($category eq 'interactive content') {
            #
          } elsif (($category eq 'phrasing content' or
                    $category eq 'heading content') and
                   $edef->{categories}->{'flow content'}) {
            #
          } else {
            if ({
              ## Known brokenly-modelled elements
              ## <https://wiki.suikawiki.org/n/category$32093#anchor-11>
              li => 1, dt => 1, dd => 1, td => 1, th => 1,
              figcaption => 1, legend => 1,
              optgroup => 1, rt => 1, rp => 1,
              body => 1, link => 1,
            }->{$ln}) {
              #
            } elsif ($edef->{conforming}) {
              error "$ns/$ln - role=$role $category";
            }
          }
        } # $category

        unless (defined $role_def->{content_model}) {
          #
        } elsif ($role_def->{content_model} eq 'flow content') {
          if (not defined $edef->{content_model}) {
            if ({
              ## Known brokenly-modelled elements
              ## <https://wiki.suikawiki.org/n/content%20model$4655#anchor-60>
              table => 1, tbody => 1, thead => 1, tfoot => 1, tr => 1,
              ul => 1, ol => 1, dl => 1, menu => 1,
              select => 1, datalist => 1, optgroup => 1,
              figure => 1, details => 1, fieldset => 1,
              video => 1, audio => 1, object => 1,
              div => 1, ruby => 1,
              summary => 1, hgroup => 1,
              svg => 1, math => 1,
            }->{$ln}) {
              #
            } elsif ($edef->{conforming}) {
              error "$ns/$ln requires (unknown) while role=$role requires $role_def->{content_model}";
            }
          } elsif ($edef->{content_model} eq 'flow content') {
            #
          } elsif ($edef->{content_model} eq 'phrasing content' or
                   $edef->{content_model} eq 'text' or
                   $edef->{content_model} eq 'empty' or
                   $edef->{content_model} eq 'transparent') {
            #
          } else {
            error "$ns/$ln requires $edef->{content_model} while role=$role requires $role_def->{content_model}";
          }
        } elsif ($role_def->{content_model} eq 'phrasing content') {
          if (not defined $edef->{content_model}) {
            if ({
              ## Known brokenly-modelled elements
              ## <https://wiki.suikawiki.org/n/content%20model$4655#anchor-60>
              table => 1, tbody => 1, thead => 1, tfoot => 1, tr => 1,
              ul => 1, ol => 1, dl => 1, menu => 1,
              select => 1, datalist => 1, optgroup => 1,
              figure => 1, details => 1, fieldset => 1,
              video => 1, audio => 1, object => 1,
              div => 1, ruby => 1,
              summary => 1, hgroup => 1,
              svg => 1, math => 1,
            }->{$ln}) {
              #
            } elsif ($edef->{conforming}) {
              error "$ns/$ln requires (unknown) while role=$role requires $role_def->{content_model}";
            }
          } elsif ($edef->{content_model} eq 'phrasing content') {
            #
          } elsif ($edef->{content_model} eq 'flow content' or
                   $edef->{content_model} eq 'text' or
                   $edef->{content_model} eq 'empty' or
                   $edef->{content_model} eq 'transparent') {
            #
          } else {
            error "$ns/$ln requires $edef->{content_model} while role=$role requires $role_def->{content_model}";
          }
        }
      }
    }
  }
}

print "1..1\nok\n" unless $Failed;
exit $Failed;

## License: Public Domain.
