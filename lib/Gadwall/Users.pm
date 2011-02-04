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

1;
