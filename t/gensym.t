use strict;
use warnings;

use Data::Transform::ExplicitMetadata qw(encode decode);
use Symbol;

use Scalar::Util qw(refaddr reftype);
use Test::More tests => 7;

my $sym = Symbol::gensym;
my $iosym = Symbol::geniosym;
my $iosym_open = Symbol::geniosym;
open($iosym_open, __FILE__);

my $original = [ $sym, $iosym, $iosym_open ];

my $expected = {
    __refaddr => refaddr($original),
    __reftype => 'ARRAY',
    __value => [
        {
            __reftype => 'GLOB',
            __refaddr => refaddr($sym),
            __value => {
                'SCALAR' => {
                    __refaddr => refaddr(*$sym{SCALAR}),
                    __reftype => 'SCALAR',
                    __value   => undef,
                },
                'PACKAGE' => 'Symbol',
                'NAME'    => 'GEN0',
            },
        },
        {
            __reftype => 'IO',
            __refaddr => refaddr($iosym),
            __blessed => 'IO::File',
            __value   => {
                IO => undef,
            }
        },
        {
            __reftype => 'IO',
            __refaddr => refaddr($iosym_open),
            __blessed => 'IO::File',
            __value => {
                IO => fileno($iosym_open),
                IOmode => '<',
                IOseek => '0 but true',
            }
        },
    ],
};
my $encoded = encode($original);

is_deeply($encoded, $expected, 'encode array with symbols');

my $decoded = decode($encoded);
is(scalar(@$decoded), 3, 'Decoded to 3-elt array');

is(ref($decoded->[0]), 'GLOB', 'elt 0 is a GLOB ref');

is(ref($decoded->[1]), 'IO::File', 'elt 1 is a filehandle');
is(reftype($decoded->[1]), 'IO', 'elt 1 is an IO ref');

is(ref($decoded->[2]), 'IO::File', 'elt 2 is a filehandle');
is(reftype($decoded->[2]), 'IO', 'elt 2 is an IO ref');
