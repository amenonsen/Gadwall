# This plugin defines helpers for the construction of HTML pages, such
# as reusable components and ways to manage CSS and Javascript content.
# For more details, see docs/gadwall/page-construction.

package Mojolicious::Plugin::PageConstruction;

use Mojo::Base 'Mojolicious::Plugin';

use Mojo::ByteStream 'b';

sub register {
    my ($self, $app) = @_;

    # This helper includes a named template like "include" does, but it
    # also takes some content (a string or a begin…end block) and makes
    # it available as $content to the included template. This allows a
    # template to be wrapped around caller-specified content.

    $app->helper(widget => sub {
        my $c = shift;
        my $file = shift;
        my $block = pop @_ if ref $_[-1] eq 'CODE';
        my $content = pop @_ if @_ % 2;

        if ($block) {
            $content = b($block->());
        }
        push @_, (content => $content);

        my %args = @_;
        delete @args{qw/extends layout/};

        my @keys = keys %args;
        local @{$c->stash}{@keys} = @args{@keys};
        return $c->include("widgets/$file");
    });

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

            my $src = $url;
            if ($url =~ m#^/#) {
                $src = timestamped_filename($app, $src);
            }

            if ($type eq 'css') {
                push @{$stash->{_g_stylesheets}},
                    qq{<link rel=stylesheet href="$src">};
            }
            elsif ($type eq 'js') {
                push @{$stash->{_g_scripts}},
                    qq{<script src="$src"></script>};
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
    #     body { font-size: 85%; }
    # <% end %>

    $app->helper(css => sub {
        my $self = shift;
        my $stash = $self->stash;

        if (@_) {
            my $block = shift;
            $stash->{_g_css} .= $block->();
            return;
        }

        my $default = timestamped_filename($app, '/css/default.css');
        my @styles = (
            qq{<link rel=stylesheet href="$default">}
        );
        if ($stash->{_g_stylesheets}) {
            push @styles, @{$stash->{_g_stylesheets}};
        }
        if ($stash->{_g_css}) {
            push @styles,
                qq{<style>\n}. $stash->{_g_css} .qq{</style>};
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
                    qq#\$(document).ready(function () {\n#.
                        $stash->{_g_js_ready}.
                    qq#});\n#
            }
            push @scripts,
                qq{<script>\n}. $stash->{_g_js} .qq{</script>};
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
}

# Takes /foo.css, returns /foo.css?1389469626 if possible.

sub timestamped_filename {
    my ($app, $filename) = @_;

    # XXX In theory, the file may be somewhere other than under public/.
    # We could use $app->static->file("$filename")->path to find it, but
    # that represents a larger number of hoops than we ever want to jump
    # through in practice.

    my $path = $app->home->rel_file("public/$filename");
    if (-r $path) {
        $filename .= "?" . (stat(_))[9]
    }

    return $filename;
}

1;
