# This plugin rejects POST requests without a valid CSRF token, and adds
# a post_form helper to include CSRF tokens into forms.

package Mojolicious::Plugin::Csrf;

use Mojo::Base 'Mojolicious::Plugin';

use Gadwall::Util;

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

            my $cb = $opts->{cb};
            if ($cb) {
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

    # post_form behaves like the built-in TagHelpers' form_for helper,
    # but it always adds a hidden field with the session's CSRF token.

    $app->helper(post_form => sub {
        my $c = shift;
        my @url = (shift);
        push @url, shift if ref $_[0] eq 'HASH';

        my $token = $c->session('token');
        unless ($token) {
            $c->session(token => Gadwall::Util->csrf_token());
        }

        if (ref $_[-1] eq 'CODE') {
            my $cb = pop @_;
            push @_, sub {
                return "\n".
                    $c->hidden_field(__token => $c->session('token')).
                    $cb->();
            };
        }

        return $c->tag(
            'form', method => "post", action => $c->url_for(@url), @_
        );
    });
}

1;
