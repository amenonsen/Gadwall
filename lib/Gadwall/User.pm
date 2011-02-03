package Gadwall::User;

use strict;
use warnings;

use base "Gadwall::Row";

use Gadwall::Util qw(bcrypt);

sub display_hash {
    my $hash = shift->SUPER::display_hash();
    delete $hash->{password};
    return $hash;
}

# Takes a password and returns true if it is the user's password, and
# false otherwise.

sub has_password {
    my ($self, $p) = @_;

    return bcrypt($p, $self->{password}) eq $self->{password};
}

# A user's roles are represented in the database as a 31-bit vector.
# Each bit corresponds to one of the following roles numbered from 0
# upwards. An unprivileged user has no bits set. (31 so that integer
# arithmetic with 32 bits is good enough.)
#
# Don't try to reorder role names.

sub role_names {
    qw(admin)
}

sub role_bit {
    my ($self, $r) = @_;

    my $i = 0;
    my %roles = map { $_ => $i++ } $self->role_names();

    return $roles{$r};
}

sub has_role {
    return shift->has_any_role(@_);
}

sub has_any_role {
    my $self = shift;

    my $i = 0;
    my %roles = map { $_ => $i++ } $self->role_names();

    my $n = 0;
    foreach (@_) {
        if (exists $roles{$_}) {
            $n |= (1 << $roles{$_});
        }
    }

    return $n && $self->{roles} & $n;
}

sub roles {
    my $self = shift;

    my $i = 0;
    my %roles = map { $_ => $i++ } $self->role_names();

    my @roles;
    my $roles = $self->{roles};
    foreach my $r ($self->role_names) {
        if ($roles & 1<<$roles{$r}) {
            push @roles, $r;
        }
    }

    return @roles;
}

1;
