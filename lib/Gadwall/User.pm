package Gadwall::User;

use Mojo::Base 'Gadwall::Db::Row';

use Gadwall::Util qw(bcrypt);

sub username {
    my $u = shift;

    return join('/', grep defined, ($u->{login}, $u->{email}));
}

sub display_hash {
    my $self = shift;
    my $hash = $self->SUPER::display_hash();

    my $n = 0;
    my @roles;
    my $d = $self->role_descriptions;
    foreach my $r ($self->role_names()) {
        if ($self->{roles} & (1<<$n)) {
            $hash->{"is_$r"} = 1;
            push @roles, $d->{$r} || $r;
        }
        $n++;
    }
    $hash->{roles} = [ @roles ];

    delete @$hash{qw/password/};
    return $hash;
}

# Takes a password and returns true if it is the user's password, and
# false otherwise. Always returns false if the password is unset.

sub has_password {
    my ($self, $p) = @_;

    return $self->{password} &&
        bcrypt($p, $self->{password}) eq $self->{password};
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

sub role_descriptions {
    return {
        admin => "Administrator"
    }
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

sub roles_from_set {
    my ($class, %set) = @_;

    my $i = 30;
    my @roles = (0)x31;
    foreach my $r ($class->role_names()) {
        if ($set{"is_$r"}) {
            $roles[$i] = 1;
        }
        $i--;
    }

    return (roles => join "", @roles);
}

1;
