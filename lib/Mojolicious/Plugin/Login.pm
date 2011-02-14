# This plugin adds /login and /logout routes, and returns a bridge that
# allows only authenticated users through. It's a convenient wrapper for
# the Gadwall::Auth controller.

package Mojolicious::Plugin::Login;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $conf) = @_;

    $app->hook(
        after_static_dispatch => sub {
            my ($c) = @_;

            return if $c->res->code;
            return unless $c->req->method eq 'POST';

            my $ctoken = $c->session('token');
            my $ptoken = $c->param('__token');
            return if $ctoken && $ptoken && $ctoken eq $ptoken;

            my @err;
            push @err, "no cookie token" unless $ctoken;
            push @err, "no form token" unless $ptoken;
            unless (@err || $ctoken eq $ptoken) {
                push @err, "tokens don't match";
            }

            $c->app->log->error(
                "CSRF: POST ". $c->req->url->path .
                " from ". $c->tx->remote_address .
                " (". ($c->req->headers->user_agent||"no user-agent") .
                ", ". ($c->req->headers->referrer||"no referrer") ."): ".
                join(", ", @err)
            );
            $c->render(
                status => 403, format => 'txt', text => "Permission denied"
            );
        }
    );

    my $r = $app->routes;
    $r->route('/login')->via('post')->to('auth#login')->name('login');
    my $auth = $r->bridge->to('auth#allow_users')->name('auth');
    $auth->route('/logout')->to('auth#logout')->name('logout');
    return $auth;
}

1;
