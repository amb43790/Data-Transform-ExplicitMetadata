use strict;
use warnings;

use Data::Transform::ExplicitMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 19;

package TestPackage;
sub test_sub { }
our $test_scalar = 1;
our @test_array = (1);
our %test_hash = ( one => 1 );

package main;
my $encoded = encode(\%TestPackage::);
ok($encoded, 'encode TestPackage:: stash');
is($encoded->{__reftype}, 'HASH', 'encodes to a HASH');
ok($encoded->{__refaddr}, '... and has a refaddr');

foreach my $expected ([ 'test_sub' => 'CODE' ],
                      [ 'test_scalar' => 'SCALAR' ],
                      [ 'test_array' => 'ARRAY' ],
                      [ 'test_hash' => 'HASH' ]
) {
    my($expected_name, $expected_type) = @$expected;
    ok($encoded->{__value}->{$expected_name}, "Saw $expected_name");
    is($encoded->{__value}->{$expected_name}->{__reftype}, 'GLOB', 'is a GLOB');
    ok(! $encoded->{__value}->{$expected_name}->{__refaddr}, '... and not a reference');
    ok($encoded->{__value}->{$expected_name}->{__value}->{$expected_type}, "with embedded $expected_type");
}
