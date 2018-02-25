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
  my $json = json_bytes2perl $RootPath->child ('data/fetch.json')->slurp;
  $Data->{referrer_policies} = $json->{referrer_policy}->{values};
  for (values %{$Data->{referrer_policies}}) {
    if (delete $_->{ReferrerPolicy}) {
      $_->{idl} = 'MAY';
      if (defined $_->{enumerated_attr_state}) {
        $_->{attr} = 'MAY';
        $_->{attr_state} = delete $_->{enumerated_attr_state};
        $_->{attr_keyword_url} = $_->{url};
      }
      $_->{preferred} = $_->{preferred}->{value} if defined $_->{preferred};
    }
  }
}

{
  my $json = json_bytes2perl $RootPath->child ('intermediate/ua-names.json')->slurp;
  for my $type (keys %$json) {
    for my $os (keys %{$json->{$type}}) {
      for my $mode (keys %{$json->{$type}->{$os}}) {
        my $ua = $json->{$type}->{$os}->{$mode};
        my $v = $Data->{user_agents}->{$type}->{$os}->{$mode} = {};
        $v->{userAgent} = $ua;
        my $ver = $ua;
        $ver =~ s{^Mozilla/}{};
        if ($mode eq 'gecko') {
          $ver =~ s{;.*}{}s;
          $ver = '5.0 (Windows' if $ver =~ m{^5\.0 \(Windows};
          $ver .= ')';
        }
        $v->{appVersion} = $ver;
        $v->{platform} = {
          'windows' => ($mode eq 'gecko' ? 'Win64' : 'Win32'),
          mac => 'MacIntel',
          ipad => 'iPad',
          iphone => 'iPhone',
          linux => 'Linux x86_64',
          android => 'Linux armv7l',
        }->{$os} // '';
        if ($mode eq 'gecko') {
          if ($v->{platform} eq 'Win64') {
            $v->{oscpu} = 'Windows NT 10.0; Win64; x64';
          } else {
            $v->{oscpu} = $v->{platform};
          }
        }
        $v->{newline} = $os eq 'windows' ? "\x0D\x0A" : "\x0A";
      }
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.
