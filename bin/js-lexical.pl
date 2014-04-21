use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->child ('modules/*/lib');
use JSON::Functions::XS qw(perl2json_bytes_for_record);

my $Data = {};

## <http://es5.github.io/#x7.8.4>
$Data->{escape}->{string}->{$_->[0]} = ['char', $_->[1]]
    for
    ['b' => "\x08"],
    ['t' => "\x09"],
    ['n' => "\x0A"],
    ['v' => "\x0B"],
    ['f' => "\x0C"],
    ['r' => "\x0D"],
    ['"' => '"'],
    ["'" => "'"],
    ['\\' => '\\'];

## <http://es5.github.io/#x15.10.2.10>
$Data->{escape}->{regexp}->{$_->[0]} = ['char', $_->[1]]
    for
    ['t' => "\x09"],
    ['n' => "\x0A"],
    ['v' => "\x0B"],
    ['f' => "\x0C"],
    ['r' => "\x0D"];

## <http://es5.github.io/#x15.10.2.12>
$Data->{escape}->{regexp}->{$_} = ['class', $_]
    for qw(d s w);
$Data->{escape}->{regexp}->{$_} = ['class-not', lc $_]
    for qw(D S W);

$Data->{escape}->{regexp}->{$_} = ['special']
    for qw(b);

## ECMA-404
$Data->{escape}->{json}->{$_->[0]} = ['char', $_->[1]]
    for
    ['"' => '"'],
    ['\\' => '\\'],
    ['/' => '/'],
    ['b' => "\x08"],
    ['f' => "\x0C"],
    ['n' => "\x0A"],
    ['r' => "\x0D"],
    ['t' => "\x09"];

print perl2json_bytes_for_record $Data;

## License: Public Domain.
