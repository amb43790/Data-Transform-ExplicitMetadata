use strict;
use warnings;

use Data::Transform::WithMetadata qw(encode decode);

use Scalar::Util;
use Test::More tests => 12;

test_scalar();
test_arrayref();
test_hashref();

sub test_scalar {
    my $tester = sub {
        my($original, $desc) = @_;
        my $encoded = encode($original);
        is($encoded, $original, "encode $desc");
        my $decoded = decode($encoded);
        is($decoded, $original, "decode $desc");
    };

    $tester->(1, 'number');
    $tester->('a string', 'string');
    $tester->('', 'empty string');
    $tester->(undef, 'undef');
}

sub test_arrayref {
    my $original = [ 1, 2, 3 ];
    my $encoded = encode($original);

    _test_simple_reference($encoded, $original, 'encode arrayref');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode arrayref');
}

sub test_hashref {
    my $original = { one => 1, two => 2, string => 'a string' };
    my $encoded = encode($original);

    _test_simple_reference($encoded, $original, 'encode hashref');

    my $decoded = decode($encoded);
    is_deeply($decoded, $original, 'decode hashref')
}

sub _test_simple_reference {
    my($encoded, $original, $desc) = @_;

    my $compare = {
        __value => $original,
        __reftype => Scalar::Util::reftype($original),
        __refaddr => Scalar::Util::refaddr($original),
    };

    $compare->{__blesstype} = Scalar::Util::blessed($original) if Scalar::Util::blessed($original);

    is_deeply($encoded, $compare, $desc);
}
