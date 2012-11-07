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

    # Forgotten passwords are a special case, handled as follows:
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

    # Other user management features are accessed through /users/$id/…
    # (apart from admins, users are allowed access only to their own
    # account settings).

    my $auth = $r->find('auth');
    my $users = $auth->bridge('/users/:user_id', user_id => qr/[1-9][0-9]*/)
        ->name('user_settings')
        ->to('auth#allow_if', cond => sub {
            my ($c, $u) = @_;
            return $c->stash('user_id') == $u->{user_id} ||
                $u->has_role('admin');
        });

    $users->post('/password')->to('users#password')->name('change_password');
    $users->post('/email')->to('users#email')->name('change_email');

    # The final step in changing one's email address is to confirm the
    # change through an email link. That has to be handled separately:

    $confirm->route('/confirm-email')
        ->to('users#confirm_email')
        ->name('confirm_email')
        ->via('get');
}

1;
