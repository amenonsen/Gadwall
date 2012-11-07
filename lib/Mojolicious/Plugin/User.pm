# This plugin adds routes for common user management functions (e.g.
# changing your password or email address) handled by Gadwall::Users.

package Mojolicious::Plugin::User;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $opts) = @_;

    my $r = $app->routes;

    my $secure = $r->find('secure');
    unless ($secure) {
        # Just a precaution; it's not worth trying to establish the
        # route if it doesn't exist.
        die "Please use the 'login' plugin before the 'user' plugin\n";
    }

    # We handle forgotten passwords as follows:
    #
    # 1. Click on "Forgot password?" link, GET /passwords/forgot
    # 2. Fill in the email form and submit, POST /passwords/forgot

    $secure->route('/forgot-password')
        ->to('users#forgot_password')
        ->name('forgot_password')
        ->via(qw/get post/);

    # 3. Click on the email link, GET /passwords/reset
    # 4. Fill in a new password, POST /passwords/reset

    my $confirm = $secure->bridge->to('confirm#by_url');

    $confirm->route('/reset-password')
        ->to('users#reset_password')
        ->name('reset_password')
        ->via(qw/get post/);

    # TODO
    # There are many more functions that should be routed here (e.g.
    # changing your password, changing your email address, etc.).
}

1;
