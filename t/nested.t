use strict;
use warnings;

use Data::Transform::WithMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 8;
use vars '$STDOUT';

my $stringref = \'a string';

our $overloaded_glob = 1;
our @overloaded_glob = ( 1 );
our %overloaded_glob = ( one => 1 );
sub overloaded_glob { 1 }
my $globref = \*overloaded_glob;

my $stdoutref = \*STDOUT;

my $arrayref = [
    1,
    2,
    $stringref,
    $stdoutref,
];

my $original = {
    one => 1,
    two => 2,
    array => $arrayref,
    glob => $globref,
};

my $expected = {
    __refaddr => refaddr($original),
    __reftype => 'HASH',
    __value => {
        one => 1,
        two => 2,
        array => {
            __refaddr => refaddr($arrayref),
            __reftype => 'ARRAY',
            __value => [
                1,
                2,
                {
                    __refaddr => refaddr($stringref),
                    __reftype => 'SCALAR',
                    __value => $$stringref,
                },
                {
                    __reftype => 'GLOB',
                    __refaddr => refaddr($stdoutref),
                    __value => {
                        IO => fileno(STDOUT),
                        SCALAR => {
                            __reftype => 'SCALAR',
                            __value => undef,
                            __refaddr => refaddr(\$STDOUT),
                        }
                    }
                },
            ],
        },
        glob => {
            __refaddr => refaddr($globref),
            __reftype => 'GLOB',
            __value => {
                SCALAR => {
                    __reftype => 'SCALAR',
                    __refaddr => refaddr(\$overloaded_glob),
                    __value => 1,
                },
                ARRAY => {
                    __reftype => 'ARRAY',
                    __refaddr => refaddr(\@overloaded_glob),
                    __value => [ 1 ],
                },
                HASH => {
                    __reftype => 'HASH',
                    __refaddr => refaddr(\%overloaded_glob),
                    __value => { one => 1 },
                },
                CODE => {
                    __reftype => 'CODE',
                    __refaddr => refaddr(\&overloaded_glob),
                    __value => sprintf('CODE(0x%x)', refaddr(\&overloaded_glob)),
                },
            },
        }
    }
};

my $encoded = encode($original);
is_deeply($encoded, $expected, 'encode nested data structure');

my $decoded = decode($encoded);

# globs need special inspection
my $original_overloaded_glob = delete($original->{glob});
my $decoded_overloaded_glob = delete($decoded->{glob});
my $original_stdout_glob = splice(@{$original->{array}}, 3, 1);
my $decoded_stdout_glob = splice(@{$decoded->{array}}, 3, 1);

is_deeply($decoded, $original, 'decode nested data structure');

ok(defined(fileno $decoded_stdout_glob), 'decoded stdout glob has fileno');
is(fileno($decoded_stdout_glob), fileno($original_stdout_glob), 'decoded stdout glob has correct fileno');

is(ref(*{$decoded_overloaded_glob}{CODE}), 'CODE', 'overloaded glob code');
is_deeply(*{$decoded_overloaded_glob}{SCALAR}, \$overloaded_glob, 'overloaded glob scalar');
is_deeply(*{$decoded_overloaded_glob}{ARRAY}, \@overloaded_glob, 'overloaded glob array');
is_deeply(*{$decoded_overloaded_glob}{HASH}, \%overloaded_glob, 'overloaded glob hash');
