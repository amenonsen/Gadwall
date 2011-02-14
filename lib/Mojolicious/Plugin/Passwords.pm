package Mojolicious::Plugin::Passwords;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    my $secure = $app->routes->bridge->to('auth#allow_secure');
    $secure->route('/forgot-password')->via(qw/get post/)->to(
        'users#forgot_password'
    )->name('forgot_password');

    my $confirm = $secure->bridge->to('confirm#by_url');
    $confirm->route('')->via(qw/get post/)->to(
        'users#reset_password'
    )->name('reset_password');
}

1;
