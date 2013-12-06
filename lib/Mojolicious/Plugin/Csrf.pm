# This plugin changes form_for to include a CSRF token in POST forms,
# and rejects POST requests without a valid CSRF token.

package Mojolicious::Plugin::Csrf;

use Mojo::Base 'Mojolicious::Plugin';

use Gadwall::Util;

sub register {
    my ($self, $app, $opts) = @_;

    # Adds a hidden CSRF __token field to forms that have method=POST.

    $app->helper(form_for => sub {
        my $c = shift;
        my @url = (shift);
        push @url, shift if ref $_[0] eq 'HASH';
        my $cb = pop @_ if ref $_[-1] eq 'CODE';
        my $content = @_ % 2 ? pop : undef;
        my %attrs = @_;
        my $post = 0;

        my ($key) = grep { lc $_ eq 'method' } keys %attrs;
        if ($key && uc $attrs{$key} eq 'POST') {
            $post = 1;
        }

        my $r = $c->app->routes->lookup($url[0]);
        if (!$post && $r) {
            my %methods = (GET => 1, POST => 1);
            do {
                my @via = @{$r->via || []};
                %methods = map { $_ => 1 } grep { $methods{$_} } @via if @via;
            } while $r = $r->parent;

            if ($methods{POST} && !$methods{GET}) {
                unshift @_, (method => 'POST');
                $post = 1;
            }
        }

        if ($post) {
            my $token = $c->session('token');
            unless ($token) {
                $token = Gadwall::Util->csrf_token();
                $c->session(token => $token);
            }

            my $field = $c->hidden_field(__token => $token);

            my $oldcb = $cb;
            $cb = sub {
                if ($oldcb) {
                    return "\n". $field . $oldcb->();
                }
                else {
                    return $field . $content;
                }
            };
        }

        push @_, $content if defined $content;
        push @_, $cb if defined $cb;

        return $c->tag('form', action => $c->url_for(@url), @_);
    });

    $app->helper(post_form => sub {
        my $c = shift;
        my @url = (shift);
        push @url, shift if ref $_[0] eq 'HASH';

        return $c->form_for(@url, method => 'POST', @_);
    });

    $app->hook(
        before_routes => sub {
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
}

1;
