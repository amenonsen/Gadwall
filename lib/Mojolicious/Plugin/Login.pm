# This plugin adds /login and /logout routes, and returns a bridge that
# allows only authenticated users through. It's a convenient wrapper for
# the Gadwall::Auth controller.

package Mojolicious::Plugin::Login;

use strict;
use warnings;

use base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $r = $app->routes;
    $r->route('/login')->via('post')->to('auth#login');
    my $auth = $r->bridge->to('auth#allow_users');
    $auth->route('/logout')->to('auth#logout');
    return $auth;
}

1;
