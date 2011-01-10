package Gadwall;

use strict;
use warnings;

use DBI;

use base 'Mojolicious';

sub development_mode {
    my $self = shift;
    $self->log->path(undef);
}

sub startup {
    my $app = shift;

    my $conf = $app->plugin(
        json_config => {
            ext => 'conf',
            default => {
                "db-name" => "gadwall", "db-user" => "gadwall", "db-pass" => "",
                secret => $main::random_secret
            }
        }
    );

    $app->secret($conf->{secret});

    (ref $app)->attr(
        db => sub {
            my ($db, $user, $pass) = @$conf{qw/db-name db-user db-pass/};
            my $dbh = DBI->connect(
                "dbi:Pg:database=$db", $user, $pass,
                {RaiseError => 0}
            ) or die $DBI::errstr;
            return $dbh;
        }
    );

    # Don't show anything sensitive in case of exceptions
    delete @$conf{qw/secret db-pass/};

    my $r = $app->routes;

    $r->any('/' => sub {
        shift->render_text("Quack!", format => 'txt')
    });
    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

1;
