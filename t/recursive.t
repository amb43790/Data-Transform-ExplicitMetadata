use strict;
use warnings;

use Data::Transform::ExplicitMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 11;

recurse_array();
recurse_hash();
recurse_ref1();
recurse_ref2();
recurse_glob();

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

sub recurse_ref2 {
    my $c = 1;
    my $b = \$c;
    $c = \$b;
    my $a = \$b;
    my $original = \$a;

    my $expected = {
        __refaddr => refaddr($original),
        __reftype => 'REF',
        __value => {
            __refaddr => refaddr($a),
            __reftype => 'REF',
            __value => {
                __refaddr => refaddr($b),
                __reftype => 'REF',
                __value => {
                    __refaddr => refaddr($c),
                    __reftype => 'REF',
                    __recursive => 1,
                    __value => '${$VAR}',
                },
            }
        }
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode ref, circularity not at root');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode ref, circularity not at root');

    undef($a);
}

sub recurse_glob {
    use vars '@typeglob','$typeglob';

    @typeglob = (\@typeglob);
    my $original = \*typeglob;

    my $expected = {
        __refaddr => refaddr($original),
        __reftype => 'GLOB',
        __value => {
            NAME => 'typeglob',
            PACKAGE => 'main',
            ARRAY => {
                __refaddr => refaddr(\@typeglob),
                __reftype => 'ARRAY',
                __value => [
                    {
                        __refaddr => refaddr(\@typeglob),
                        __reftype => 'ARRAY',
                        __recursive => 1,
                        __value => '*{$VAR}{ARRAY}'
                    }
                ],
            },
            SCALAR => {
                __refaddr => refaddr(\$typeglob),
                __reftype => 'SCALAR',
                __value => undef,
            },
        },
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode glob');

    my $decoded = decode($encoded);
    is(ref($decoded), 'GLOB', 'decode glob');
    my $decoded_array = *{$decoded}{ARRAY};
    is_deeply($decoded_array, $decoded_array, 'decoded array from glob');
}
