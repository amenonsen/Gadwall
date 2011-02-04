package Gadwall::Users;

use strict;
use warnings;

use base 'Gadwall::Table';

use Gadwall::Util qw(bcrypt);

sub columns {
    my $self = shift;
    return (
        login => {},
        email => {
            required => 1,
        },
        password => {
            fields => [qw/pass1 pass2/],
            required => 1,
            validate => sub {
                my (%p) = @_;
                return unless $p{pass1} eq $p{pass2};
                return (password => bcrypt($p{pass1}));
            },
            error => "Please enter the same password twice"
        },
        roles => {
            fields => qr/^is_[a-z]+$/,
            validate => sub {
                my (%set) = @_;

                my $i = 30;
                my @roles = (0)x31;
                my $class = $self->class_name($self->rowclass);
                foreach my $r ($class->role_names()) {
                    if ($set{"is_$r"}) {
                        $roles[$i] = 1;
                    }
                    $i--;
                }

                return (roles => join "", @roles);
            }
        }
    );
}

sub extra_columns { qw(roles::int) }

# Takes the current password and (two copies of) a new password and
# changes the user's password. Expects the router to set user_id in
# the stash. Users should have access to only their own password.
#
# $auth->route('/users/:user_id/password')->to('users#password');

sub password {
    my $self = shift;

    my $u = $self->stash('user');
    my $id = $self->stash($self->primary_key);
    my $passwd = $self->param('password');

    unless (($u->has_role("admin") && $u->{user_id} != $id) ||
            ($passwd && $u->has_password($passwd)))
    {
        return $self->json_error("Incorrect password");
    }

    my %set = $self->_validate(
        { $self->columns }, {
            pass1 => $self->param('pass1'),
            pass2 => $self->param('pass2')
        }
    );

    unless (%set && $self->_update($id, %set)) {
        return $self->json_error;
    }

    $self->app->log->info(
        "Password changed by $u->{email}".
        $u->{user_id} ne $id ? " (for user $id)" : ""
    );
    return $self->json_ok("Password changed");
}

1;
