# This plugin adds /login and /logout routes, and returns a bridge that
# allows only authenticated users through. It's a convenient wrapper for
# the Gadwall::Auth controller.

package Mojolicious::Plugin::Login;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $opts) = @_;

    my $r = $app->routes;

    # First, some convenient route shortcuts.

    $r->add_shortcut(allow_roles => sub {
        return shift->bridge->to('auth#allow_roles', roles => @_);
    });
    $r->add_shortcut(allow_if => sub {
        return shift->bridge->to('auth#allow_if', cond => @_);
    });

    # Everything that requires authentication also requires HTTPS.

    my $secure = $r->bridge->to('auth#allow_secure')->name('secure');

    # We establish a route only to handle the actual login request. If a
    # separate route is needed to display the login form (as opposed to
    # just having it be served by auth#allow_users), the application is
    # responsible for creating it ($r->get('/login') will work).

    $secure->route('/login')->via('post')->to('auth#login')->name('login');

    # The application can create routes under $auth (which we return),
    # and requests to them will be allowed only for authenticated users.

    my $auth = $secure->bridge->to('auth#allow_users')->name('auth');

    $auth->route('/logout')->via('post')->to('auth#logout')->name('logout');

    return $auth;
}

1;
