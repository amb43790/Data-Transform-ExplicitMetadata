use strict;
use warnings;

use Data::Transform::WithMetadata qw(encode decode);

use Scalar::Util qw(refaddr);
use Test::More tests => 8;
use IO::Handle;

test_tied_scalar();
test_tied_array();
test_tied_hash();
test_tied_handle();

sub test_tied_scalar {
    my $original = 1;
    my $tied_value = 'tied scalar';
    tie $original, 'Data::Transform::WithMetadata::TiedScalar', $tied_value;
    my $expected = {
        __reftype => 'SCALAR',
        __refaddr => refaddr(\$original),
        __tied => 1,
        __value => {
            __reftype => 'ARRAY',
            __refaddr => refaddr(tied $original),
            __blessed => 'Data::Transform::WithMetadata::TiedScalar',
            __value => [ $tied_value ],
        }
    };
    my $encoded = encode(\$original);
    is_deeply($encoded, $expected, 'encode tied scalar');

    my $decoded = decode($encoded);
    is($$decoded, $tied_value, 'decode tied scalar')
}

sub test_tied_array {
    my @original = ( 'an','array');
    my $tied_value = 'haha';
    tie @original, 'Data::Transform::WithMetadata::TiedArray', $tied_value;
    my $expected = {
        __reftype => 'ARRAY',
        __refaddr => refaddr(\@original),
        __tied => 1,
        __value => {
            __reftype => 'SCALAR',
            __refaddr => refaddr(tied @original),
            __blessed => 'Data::Transform::WithMetadata::TiedArray',
            __value => $tied_value,
        }
    };
    my $encoded = encode(\@original);
    is_deeply($encoded, $expected, 'encode tied array');

    my $decoded = decode($encoded);
    is($decoded->[2], $tied_value, 'decode tied array');
}

sub test_tied_hash {
    my %original = ( one => 1 );
    my $tied_value = 'secret';
    tie %original, 'Data::Transform::WithMetadata::TiedHash', $tied_value;
    my $expected = {
        __reftype => 'HASH',
        __refaddr => refaddr(\%original),
        __tied => 1,
        __value => {
            __reftype => 'SCALAR',
            __refaddr => refaddr(tied %original),
            __blessed => 'Data::Transform::WithMetadata::TiedHash',
            __value => $tied_value,
        }
    };
    my $encoded = encode(\%original);
    is_deeply($encoded, $expected, 'encode tied hash');

    my $decoded = decode($encoded);
    is($decoded->{foo}, $tied_value, 'decode tied hash');
}

sub test_tied_handle {
    my $original = IO::Handle->new();
    my $tied_value = 'secret';
    tie *$original, 'Data::Transform::WithMetadata::TiedHandle', $tied_value;
    my $expected = {
        __reftype => 'GLOB',
        __refaddr => refaddr($original),
        __blessed => 'IO::Handle',
        __tied => 1,
        __value => {
            __reftype => 'SCALAR',
            __refaddr => refaddr(tied *$original),
            __blessed => 'Data::Transform::WithMetadata::TiedHandle',
            __value => $tied_value,
        }
    };
    my $encoded = encode($original);
    is_deeply($encoded, $expected, 'encode tied handle');

    my $decoded = decode($encoded);
    is(scalar(<$decoded>), $tied_value, 'decode tied handle');
}

package Data::Transform::WithMetadata::TiedScalar;

sub TIESCALAR {
    my $class = shift;
    my @self = @_;
    return bless \@self, __PACKAGE__;
}

sub FETCH {
    my $self = shift;
    return join(' ', @$self);
}

package Data::Transform::WithMetadata::TiedArray;

sub TIEARRAY {
    my $class = shift;
    my $self = shift;
    return bless \$self, __PACKAGE__;
}

sub FETCH {
    my($self, $idx) = @_;
    return $$self;
}

sub FETCHSIZE {
    return 100;
}

package Data::Transform::WithMetadata::TiedHash;

sub TIEHASH {
    my $class = shift;
    my $self = shift;
    return bless \$self, __PACKAGE__;
}

sub FETCH {
    my($self, $idx) = @_;
    return $$self;
}

package Data::Transform::WithMetadata::TiedHandle;

sub TIEHANDLE {
    my $class = shift;
    my $self = shift;
    return bless \$self, __PACKAGE__;
}

sub READLINE {
    my($self, $idx) = @_;
    return $$self;
}


