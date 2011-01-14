package Gadwall;

use strict;
use warnings;

use DBI;

use base 'Mojolicious';

sub development_mode {
    my $app = shift;
    $app->log->path(undef);
}

sub config_defaults {
    my $self = shift;
    my $name = lc ref $self;

    return {
        "db-name" => $name, "db-user" => $name, "db-pass" => "",
        secret => $main::random_secret
    };
}

sub gadwall_setup {
    my $app = shift;

    my $conf = $app->plugin(
        json_config => { ext => 'conf', default => $app->config_defaults }
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
}

sub startup {
    my $app = shift;

    $app->gadwall_setup;

    my $r = $app->routes;

    $r->any('/' => sub {
        shift->render_text("Quack!", format => 'txt')
    });
    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

1;
