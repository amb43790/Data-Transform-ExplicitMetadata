package Data::Transform::WithMetadata;

use strict;
use warnings;

use Scalar::Util;
use Symbol;
use Carp;

use base 'Exporter';

our @EXPORT_OK = qw( encode decode );

sub encode {
    my $value = shift;
    my $path_expr = shift;
    my $seen = shift;

    if (!ref($value)) {
        my $ref = ref(\$value);
        # perl 5.8 - ref() with a vstring returns SCALAR
        if ($ref eq 'GLOB'
            or
            $ref eq 'VSTRING' or Scalar::Util::isvstring($value)
        ) {
            $value = encode(\$value, $path_expr, $seen);
            delete $value->{__refaddr};
        }
        return $value;
    }

    $path_expr ||= '$VAR';
    $seen ||= {};

    if (ref $value) {
        my $reftype     = Scalar::Util::reftype($value);
        my $refaddr     = Scalar::Util::refaddr($value);
        my $blesstype   = Scalar::Util::blessed($value);

        if ($seen->{$value}) {
            my $rv = {  __reftype => $reftype,
                        __refaddr => $refaddr,
                        __recursive => 1,
                        __value => $seen->{$value} };
            $rv->{__blessed} = $blesstype if $blesstype;
            return $rv;
        }
        $seen->{$value} = $path_expr;

        # Build a new path string for recursive calls
        my $_p = sub {
            return '$'.$path_expr if ($reftype eq 'SCALAR' or $reftype eq 'REF');

            my @bracket = $reftype eq 'ARRAY' ? ( '[', ']' ) : ( '{', '}' );
            return sprintf('%s->%s%s%s', $path_expr, $bracket[0], $_, $bracket[1]);
        };

        if (my $tied = _is_tied($value, $reftype)) {
            local $_ = 'tied';  # &$_p needs this
            my $rv = {  __reftype => $reftype,
                        __refaddr => $refaddr,
                        __tied    => 1,
                        __value   => encode($tied, &$_p, $seen) };
            $rv->{__blessed} = $blesstype if $blesstype;
            return $rv;
        }

        if ($reftype eq 'HASH') {
            $value = { map { $_ => encode($value->{$_}, &$_p, $seen) } sort(keys %$value) };

        } elsif ($reftype eq 'ARRAY') {
            $value = [ map { encode($value->[$_], &$_p, $seen) } (0 .. $#$value) ];

        } elsif ($reftype eq 'GLOB') {
            local $_ = 'glob';  # &$_p needs this
            my %tmpvalue = map { $_ => encode(*{$value}{$_}, &$_p, $seen) }
                           grep { *{$value}{$_} }
                           qw(HASH ARRAY SCALAR);
            if (*{$value}{CODE}) {
                $tmpvalue{CODE} = encode(*{$value}{CODE}, &$_p, $seen);
            }
            if (*{$value}{IO}) {
                $tmpvalue{IO} = encode(fileno(*{$value}{IO}), &$_p, $seen);
            }
            $value = \%tmpvalue;
        } elsif (($reftype eq 'REGEXP')
                    or ($reftype eq 'SCALAR' and defined($blesstype) and $blesstype eq 'Regexp')
        ) {
            $reftype = 'REGEXP';
            undef($blesstype) unless $blesstype ne 'Regexp';
            $value = $value . '';
        } elsif ($reftype eq 'CODE') {
            (my $copy = $value.'') =~ s/^(\w+)\=//;  # Hack to change CodeClass=CODE(0x123) to CODE=(0x123)
            $value = $copy;
        } elsif ($reftype eq 'REF') {
            $value = encode($$value, &$_p, $seen );
        } elsif (($reftype eq 'VSTRING') or Scalar::Util::isvstring($$value)) {
            $reftype = 'VSTRING';
            $value = [ unpack('c*', $$value) ];
        } elsif ($reftype eq 'SCALAR') {
            $value = encode($$value, &$_p, $seen);
        }

        $value = { __reftype => $reftype, __refaddr => $refaddr, __value => $value };
        $value->{__blessed} = $blesstype if $blesstype;
    }

    return $value;
}

sub _is_tied {
    my($ref, $reftype) = @_;

    my $tied;
    if    ($reftype eq 'HASH')   { $tied = tied %$ref }
    elsif ($reftype eq 'ARRAY')  { $tied = tied @$ref }
    elsif ($reftype eq 'SCALAR') { $tied = tied $$ref }
    elsif ($reftype eq 'GLOB')   { $tied = tied *$ref }

    return $tied;
}

sub decode {
    my($input, $recursive_queue, $recurse_fill) = @_;

    unless (ref $input) {
        return $input;
    }

    _validate_decode_structure($input);

    my($value, $reftype, $refaddr, $blessed) = @$input{'__value','__reftype','__refaddr','__blesstype'};
    my $rv;
    my $is_first_invocation = ! $recursive_queue;
    $recursive_queue ||= [];

    if ($input->{__recursive}) {
        my $path = $input->{__value};
        push @$recursive_queue,
            sub {
                my $VAR = shift;
                $recurse_fill->(eval $path);
            };

    } elsif ($reftype eq 'SCALAR') {
        $rv = \$value;

    } elsif ($reftype eq 'ARRAY') {
        $rv = [];
        for (my $i = 0; $i < @$value; $i++) {
            my $idx = $i;
            push @$rv, decode($value->[$i], $recursive_queue, sub { $rv->[$idx] = shift });
        }

    } elsif ($reftype eq 'HASH') {
        $rv = {};
        foreach my $key ( sort keys %$value ) {
            my $k = $key;
            $rv->{$key} = decode($value->{$key}, $recursive_queue, sub { $rv->{$k} = shift });
        }

    } elsif ($reftype eq 'GLOB') {
        $rv = Symbol::gensym();

        foreach my $type ( keys %$value ) {
            if ($type eq 'IO') {
                if (my $fileno = $value->{IO}) {
                    open($rv, '>&=', $fileno)
                        || Carp::carp("Couldn't open filehandle for descriptor $fileno");
                }
            } elsif ($type eq 'CODE') {
                *{$rv} = \&_dummy_sub;

            } else {
                *{$rv} = decode($value->{$type}, $recursive_queue, sub { *{$rv} = shift });
            }
        }

        $rv = *$rv unless $refaddr;

    } elsif ($reftype eq 'CODE') {
        $rv = \&_dummy_sub;

    } elsif ($reftype eq 'REF') {
        my $ref;
        $ref = decode($value, $recursive_queue, sub { $ref = shift });
        $rv = \$ref;

    } elsif ($reftype eq 'REGEXP') {
        my($options,$regex) = $value =~ m/^\(\?(\w*)-.*?:(.*)\)$/;
        $rv = eval "qr($regex)$options";

    } elsif ($reftype eq 'VSTRING') {
        my $vstring = eval 'v' . join('.', @$value);
        $rv = $refaddr ? \$vstring : $vstring;

    }

    if ($is_first_invocation) {
        $_->($rv) foreach @$recursive_queue;
    }

    return $rv;
}

sub _dummy_sub {
    'Put in place by ' . __PACKAGE__ . ' when it could not find the named sub';
}

sub _validate_decode_structure {
    my $input = shift;

    ref($input) eq 'HASH'
        or Carp::croak('Invalid decode data: expected hashref but got '.ref($input));

    exists($input->{__value})
        or Carp::croak('Invalid decode data: expected key __value');
    exists($input->{__reftype})
        or Carp::croak('Invalid decode data: expected key __reftype');

    my($reftype, $value, $blesstype) = @$input{'__reftype','__value','__blesstype'};
    $reftype eq 'GLOB'
        or $reftype eq 'VSTRING'
        or exists($input->{__refaddr})
        or Carp::croak('Invalid decode data: expected key __refaddr');

    ($blesstype and $reftype)
        or !$blesstype
        or Carp::croak('Invalid decode data: Cannot have __blesstype without __reftype');

    my $compatible_references =
            (   ( $reftype eq 'SCALAR' and ! ref($value) )
                or
                ( $reftype eq ref($value) )
                or
                ( $reftype eq 'GLOB' and exists($value->{SCALAR}))
                or
                ( $reftype eq 'CODE' and $value and ref($value) eq '' )
                or
                ( $reftype eq 'REF' and ref($value) eq 'HASH' and exists($value->{__reftype}) )
                or
                ( $reftype eq 'REGEXP' and $value and ref($value) eq '' )
                or
                ( $reftype eq 'VSTRING' and ref($value) eq 'ARRAY' )
                or
                ( $reftype and ! ref($input->{value}) and $input->{__recursive} )
            );
    $compatible_references or Carp::croak('Invalid decode data: __reftype is '
                        . $input->{__reftype}
                        . ' but __value is a '
                        . ref($input->{__value}));
    return 1;
}

1;

=pod

=head1 NAME

Data::Serialize::JSON - Encode Perl values in a json-friendly way

=head1 SYNOPSIS

  use Data::Serialize::JSON qw(to_json from_json);

  my $val = encode_perl_data($some_data_structure);
  $io->print( JSON::encode_json( $val ));

=head1 DESCRIPTION

This utility module is used to take an arbitrarily nested data structure, and
return a value that may be safely JSON-encoded.

=head2 Functions

=over 4

=item encode_perl_data

Accepts a single value and returns a value that may be safely passed to
JSON::encode_json().  encode_json() cannot handle Perl-specific data like
blessed references or typeglobs.  Non-reference scalar values like numbers
and strings are returned unchanged.  For all references, encode_perl_data()
returns a hashref with these keys
  __reftype     String indicating the type of reference, as returned
                by Scalar::Util::reftype()
  __refaddr     Memory address of the reference, as returned by
                Scalar::Util::refaddr()
  __blessed     Package this reference is blessed into, as returned
                by Scalar::Util::blessed.
  __value       Reference to the unblessed data.
  __tied        Flag indicating this variable is tied
  __recursive   Flag indicating this reference was seen before

If the reference was not blessed, then the __blessed key will not be present.
__value is generally a copy of the underlying data.  For example, if the input
value is an hashref, then __value will also be a hashref containing the input
value's kays and values.  For typeblobs and glob refs, __value will be a
hashref with the keys SCALAR, ARRAY, HASH, IO and CODE.  For coderefs,
__value will be the stringified reference, like "CODE=(0x12345678)".  For
v-strings and v-string refs, __value will by an arrayref containing the
integers making up the v-string.  For tied objects, __tied will be true
and __value will contain the underlying tied data.

if __recursive is true, then __value will contain a string representation
of the first place this reference was seen in the data structure.

encode_perl_data() handles arbitrarily nested data structures, meaning that
values in the __values slot may also be encoded this way.

=back

=head1 SEE ALSO

Devel::hdb

=head1 AUTHOR

Anthony Brummett <brummett@cpan.org>

=head1 COPYRIGHT

Copyright 2014, Anthony Brummett.  This module is free software. It may
be used, redistributed and/or modified under the same terms as Perl itself.
