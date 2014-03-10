use strict;
use warnings;

use Data::Transform::WithMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 8;

recurse_array();
recurse_hash();
recurse_ref1();

sub recurse_array {
    my $idx_2 = [ 2 ];
    push @$idx_2, $idx_2;
    my $original = [ 0, 1, $idx_2 ];

    my $expected = {
        __refaddr => refaddr($original),
        __reftype => 'ARRAY',
        __value => [
            0,
            1,
            {
                __refaddr => refaddr($idx_2),
                __reftype => 'ARRAY',
                __value => [
                     2,
                    {
                        __refaddr => refaddr($idx_2),
                        __reftype => 'ARRAY',
                        __recursive => 1,
                        __value => '$VAR->[2]',
                    },
                ],
            },
        ],
    };

    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode recursive data structure');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode recursive data structure');
}

sub recurse_hash {
    my $nested = { bar => 'bar' };
    $nested->{nested} = $nested;
    my $original = { foo => 'foo', nested => $nested };

    my $expected = {
        __refaddr => refaddr($original),
        __reftype => 'HASH',
        __value => {
            foo => 'foo',
            nested => {
                __refaddr => refaddr($nested),
                __reftype => 'HASH',
                __value => {
                    bar => 'bar',
                    nested => {
                        __refaddr => refaddr($nested),
                        __reftype => 'HASH',
                        __recursive => 1,
                        __value => '$VAR->{nested}'
                    }
                }
            }
        }
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode recursive hash');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode recursive hash');
}

sub recurse_ref1 {
    my $a = 1;
    my $b = \$a;
    my $original = \$b;
    $a = \$original;

    my $expected = {
        __refaddr => refaddr($original),
        __reftype => 'REF',
        __value => {
            __refaddr => refaddr($b),
            __reftype => 'REF',
            __value => {
                __refaddr => refaddr($a),
                __reftype => 'REF',
                __value => {
                    __refaddr => refaddr($original),
                    __reftype => 'REF',
                    __recursive => 1,
                    __value => '$VAR',
                }
            }
        }
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode ref reference');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode ref reference');

    undef($a); # break the cycle
}

