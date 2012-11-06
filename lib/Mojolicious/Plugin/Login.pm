# This plugin adds /login and /logout routes, and returns a bridge that
# allows only authenticated users through. It's a convenient wrapper for
# the Gadwall::Auth controller.

package Mojolicious::Plugin::Login;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $opts) = @_;

    my $r = $app->routes;
    $r->route('/login')->via('post')->to('auth#login')->name('login');

    if ($opts->{reset_passwords}) {
        my $secure = $r->bridge('/passwords')->to('auth#allow_secure');
        $secure->route('/forgot')->via(qw/get post/)->to(
            'users#forgot_password'
        )->name('forgot_password');
        my $confirm = $secure->bridge->to('confirm#by_url');
        $confirm->route('/reset')->via(qw/get post/)->to(
            'users#reset_password'
        )->name('reset_password');
    }

    if ($opts->{change_email}) {
        my $secure = $r->bridge('/email')->to('auth#allow_secure');
        my $confirm = $secure->bridge->to('confirm#by_url');
        $confirm->route('/confirm')->via('get')
            ->to('users#confirm_email')
            ->name('confirm_email');
    }

    my $auth = $r->bridge->to('auth#allow_users')->name('auth');
    $auth->route('/logout')->via('post')->to('auth#logout')->name('logout');

    $r->add_shortcut(allow_roles => sub {
        return shift->bridge->to('auth#allow_roles', roles => @_);
    });
    $r->add_shortcut(allow_if => sub {
        return shift->bridge->to('auth#allow_if', cond => @_);
    });

    return $auth;
}

1;
