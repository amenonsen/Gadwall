# This plugin rejects POST requests without a valid CSRF token.

package Mojolicious::Plugin::Csrf;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ($self, $app, $opts) = @_;

    $app->hook(
        after_static_dispatch => sub {
            my ($c) = @_;

            return if $c->res->code;
            return unless $c->req->method eq 'POST';

            my $ctoken = $c->session('token');
            my $ptoken = $c->param('__token');
            if (my $json = $c->req->json) {
                $ptoken = $json->{__token};
            }

            return if $ctoken && $ptoken && $ctoken eq $ptoken;

            # If a callback is specified, let it handle the failure.
            # Otherwise we log an error with as much User-Agent and
            # Referer data as we can get, and deny the request.

            if (my $cb = $opts->{cb}) {
                return $cb->();
            }

            $ptoken = $ptoken ? "'$ptoken'" : "(no token)";
            $ctoken = "'$ctoken'" if $ctoken;
            unless ($ctoken) {
                local $" = ",";
                $ctoken = $c->req->cookie('mojolicious') ?
                    "(no token (@{[keys %{$c->session}]}))" :
                    "(no cookie)";
            }

            $c->app->log->error(
                "CSRF: POST ". $c->req->url->path .
                " from ". $c->tx->remote_address .
                " (". ($c->req->headers->user_agent||"no user-agent") .
                ", ". ($c->req->headers->referrer||"no referrer") ."): ".
                "form: $ptoken, cookie: $ctoken"
            );

            $c->render(
                status => 403, format => 'txt', text => "Permission denied"
            );
        }
    );
}

1;
