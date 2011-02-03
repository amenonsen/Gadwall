# This plugin adds /login and /logout routes, and returns a bridge that
# allows only authenticated users through. It's a convenient wrapper for
# the Gadwall::Auth controller.

package Mojolicious::Plugin::Login;

use strict;
use warnings;

use base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $pkg = ref $app;
    if (my $e = Mojo::Loader->load("${pkg}::Auth")) {
        die $e if ref $e;
        $pkg = "Gadwall";
    }

    my $r = $app->routes;
    $r->route('/login')->via('post')->to('auth#login', namespace => $pkg);
    my $auth = $r->bridge->to('auth#allow_users', namespace => $pkg);
    $auth->route('/logout')->to('auth#logout', namespace => $pkg);
    return $auth;
}

1;
