use strict;
use warnings;

use Data::Transform::ExplicitMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 5;

{
    package HasStringOverload;
    use overload '""' => sub { $_[0]->{value} };
    sub new {
        my($class, $val) = @_;
        my %self = ( value => $val );
        bless \%self, $class;
    }
}

my $obj1 = HasStringOverload->new(1);
my $obj2 = HasStringOverload->new(1);

# Create a list with things that stringify to the same value:
#   * two elements are the same object instance
#   * a unique instance
#   * a raw value
my $original = [
    $obj1,
    $obj1,
    $obj2,
    1,
];
my $encoded = encode($original);
ok($encoded, 'encoded');

my $decoded = decode($encoded);
ok($decoded, 'decoded');

is(refaddr($decoded->[0]), refaddr($decoded->[1]), 'First and second element decode to the same instance');
isnt(refaddr($decoded->[0]), refaddr($decoded->[2]), 'First and third element are different');
isnt(refaddr($decoded->[0]), refaddr($decoded->[3]), 'First and fourth element are different');
