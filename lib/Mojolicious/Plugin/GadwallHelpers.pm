package Mojolicious::Plugin::GadwallHelpers;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::ByteStream 'b';
use Gadwall::Util;

sub register {
    my ($self, $app) = @_;

    # widget is like "include", but it allows the included template to
    # be wrapped around provided begin/end block of content. It also
    # localises stash values for convenience.

    $app->helper(widget => sub {
        my $self = shift;
        my $file = shift;
        my $stash = $self->stash;

        if (ref $_[-1] && ref $_[-1] eq 'CODE') {
            my $block = pop;
            push @_, content => b($block->());
        }
        else {
            push @_, content => "";
        }

        my %args = @_;

        my $key;
        LOCALIZE:
            $key = (keys %args)[0];
            local $stash->{$key} = delete $args{$key};
        goto LOCALIZE while keys %args;

        return $self->render_partial("widgets/$file");
    });

    # The next few helpers are used to manage CSS and Javascript
    # dependencies for the current page.
    #
    # "requires" declares that we need an external stylesheet or script.
    # (Redundant/repeated requires are safe; any given URL will only be
    # referenced once in the final page.)
    #
    # % requires '.../some.css', '.../some.js';

    $app->helper(requires => sub {
        my $self = shift;
        my $stash = $self->stash;

        my @deps;
        foreach (@_) {
            if ($_ eq 'js' || $_ eq 'css') {
                push @deps, {type => $_, url => shift};
            }
            elsif ($_ =~ /^jquery(-ui)?$/) {
                push @deps, {
                    type => 'js',
                    url => "https://ajax.googleapis.com/ajax/libs/jquery/1.4.4/jquery.min.js"
                };
                push @deps, {
                    type => 'js',
                    url => "https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.6/jquery-ui.min.js"
                } if /-ui/;
            }
            elsif (/\.(js|css)$/) {
                push @deps, {type => $1, url => $_};
            }
            else {
                return;
            }
        }
        foreach (@deps) {
            my ($type, $url) = @$_{qw/type url/};
            next if exists $stash->{_g_deps_seen}{$url};
            if ($type eq 'css') {
                push @{$stash->{_g_stylesheets}},
                    qq{<link rel=stylesheet type="text/css" href="$url">};
            }
            elsif ($type eq 'js') {
                push @{$stash->{_g_scripts}},
                    qq{<script type="text/javascript" src="$url"></script>};
            }
            $stash->{_g_deps_seen}{$url}++;
        }

        return;
    });

    # css adds local stylesheet rules to the ones imported from external
    # stylesheets. All css blocks will be coalesced into a single style
    # element in the HEAD of the final document (which occurs after any
    # external stylesheet references).
    #
    # <% css begin %>
    #  body { font-size: 85%; }
    # <% end %>

    $app->helper(css => sub {
        my $self = shift;
        my $stash = $self->stash;

        if (@_) {
            my $block = shift;
            $stash->{_g_css} .= $block->();
            return;
        }

        my @styles = (
            qq{<link rel=stylesheet type="text/css" href="/default.css">}
        );
        if ($stash->{_g_stylesheets}) {
            push @styles, @{$stash->{_g_stylesheets}};
        }
        if ($stash->{_g_css}) {
            push @styles,
                qq{<style type="text/css">}.
                    $stash->{_g_css}.
                qq{</style>};
        }

        return unless @styles;
        return b(join "\n", @styles);
    });

    # js adds local javascript code. All js blocks will be coalesced
    # into a single script element at the end of the document's body.
    #
    # <% js begin %>
    # function x () { ... }
    # <% end %>

    $app->helper(js => sub {
        my $self = shift;
        my $stash = $self->stash;

        if (@_) {
            my $block = shift;
            $stash->{_g_js} .= $block->();
            return;
        }

        my @scripts;
        if ($stash->{_g_scripts}) {
            push @scripts, @{$stash->{_g_scripts}};
        }
        if ($stash->{_g_js} || $stash->{_g_js_ready}) {
            if ($stash->{_g_js_ready}) {
                $stash->{_g_js} ||= "\n";
                $stash->{_g_js} .=
                    q#$(document).ready(function () {#.
                        $stash->{_g_js_ready}.
                    qq#});\n#
            }
            push @scripts,
                qq{<script type="text/javascript">}.
                    $stash->{_g_js}.
                qq{</script>};
        }

        return unless @scripts;
        return b(join "\n", @scripts);
    });

    # This is a sub-helper for "js", which wraps the code into a single
    # $(document).ready(function () { ... }) before including it.

    $app->helper(ready => sub {
        my $self = shift;
        my $stash = $self->stash;

        if (@_) {
            my $block = shift;
            $stash->{_g_js_ready} .= $block->();
        }

        return;
    });

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
                return "\n" . $self->_tag(
                    'input', name => "__token", type => "hidden",
                    value => $c->session('token')
                ).$cb->();
            };
        }

        return $self->_tag(
            'form', method => "post", action => $c->url_for(@url), @_
        );
    });
}

# Copied verbatim from Mojolicious::Plugin::TagHelpers, because that
# is still marked EXPERIMENTAL. Otherwise I could have tried calling
# $c->app->renderer->helpers->{tag}->() myself.

sub _tag {
  my $self = shift;
  my $name = shift;

  # Callback
  my $cb = defined $_[-1] && ref($_[-1]) eq 'CODE' ? pop @_ : undef;
  pop if @_ % 2;

  # Tag
  my $tag = "<$name";

  # Attributes
  my %attrs = @_;
  for my $key (sort keys %attrs) {
    my $value = $attrs{$key};
    $tag .= qq/ $key="$value"/;
  }

  # Block
  if ($cb) {
    $tag .= '>';
    $tag .= $cb->();
    $tag .= "<\/$name>";
  }

  # Empty element
  else { $tag .= ' />' }

  # Prevent escaping
  return b($tag);
}

1;
