package Gadwall;

use strict;
use warnings;

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
                secret => $main::random_secret
            }
        }
    );

    $app->secret($conf->{secret});

    # Don't show anything sensitive in case of exceptions
    delete @$conf{qw/secret/};

    my $r = $app->routes;

    $r->any('/' => sub {
        shift->render_text("Quack!", format => 'txt')
    });
    $r->any('/(*whatever)' => sub { shift->render_not_found });
}

1;
