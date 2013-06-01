package Gadwall::Controller;

use Mojo::Base 'Mojolicious::Controller';

use Gadwall::Db::Table;

# Aliases to reduce the tedium of typing $self->app->log() etc.

sub db { shift->app->db }
sub log { shift->app->log }

# Takes the name of a class, like Sprockets, and returns its full name,
# like Wigeon::Sprockets (or Gadwall::Sprockets, if that is not found).
# Returns undef if neither is found.

sub class_name {
    my ($self, $name) = @_;

    return unless defined $name;

    my $class;
    for my $p ("", ref $self->app, "Gadwall") {
        my $s = $p ? "${p}::$name" : $name;
        unless (my $e = Mojo::Loader->load($s)) {
            $class = $s;
            last;
        }
        else {
            die $e if ref $e;
        }
    }

    return $class;
}


# Returns a new controller initialised with the app, stash, and tx of
# the current controller. The controller to create may be identified by
# its full package name (e.g. "Gadwall::Users") or just the unique part
# (i.e. "Users" in this case).

sub new_controller {
    my ($self, $class) = @_;

    $class = $self->class_name($class);
    return $class->new(
        app => $self->app, stash => $self->stash, tx => $self->tx
    );
}

# Returns the canonical URL for this web site, if configured, or the
# best we can do under the circumstances if not.

sub canonical_url {
    my ($self, $scheme, $path) = @_;

    my $url = $self->req->url->base->clone;

    $scheme ||= 'http';
    my $host = $self->config("canonical_url");
    my $port = $self->config("canonical_${scheme}_port");

    $url->scheme($scheme);
    $url->host($host) if $host;
    $url->port($port) if $port;
    $url->path($path) if $path;

    return $url;
}

# This function saves having to type "format => 'txt'" everywhere.

sub render_text {
    shift->render(format => 'txt', text => @_);
}

# This function may be used by any controller/action/bridge at any time
# if it thinks something shady is going on.

sub denied {
    shift->render_text("Permission denied", status => 403);
    return 0;
}

# Shorthand for the commonest redirect_to invocation.

sub redirect {
    my $self = shift;
    my $url = $self->url_for(@_);

    $self->redirect_to($url)->render_text(
        "Redirecting to $url"
    );
}

# Helper functions to return JSON responses
#
# return $self->json_fragment(a => 1, b => "two")
# => {"a": 1, "b": "two"}

sub json_fragment {
    my $self = shift;
    my $format = $self->stash('json_format');
    if ($format && $format eq 'textarea') {
        my $json = $self->render(json => { @_ }, partial => 1);
        $self->render(text => "<textarea>$json</textarea>", format => 'html');
    }
    else {
        $self->render(json => { @_ });
    }
    return;
}

# return $self->json_ok("Success!", extra => "data")
# => {"status": "ok", "message": "Success!", "extra": "data"}

sub json_ok {
    my $self = shift;
    return $self->json_fragment(
        status => 'ok', message => shift, @_
    );
}

# return $self->json_error("Failed!")
# => {"status": "error", "message": "Failed!"}
#
# return $self->json_error("Failed!", extra => "data")
# OR:
# $self->stash(error => {message => "Failed!", extra => "data"});
# return $self->json_error
# OR:
# return $self->json_error({message => "Failed!", extra => "data"})
# => {"status": "error", "message": "Failed!", "extra": "data"}

sub json_error {
    my $self = shift;
    my $error = shift;

    my %error;

    $error ||= $self->stash('error');
    if (ref $error) {
        %error = %{ $error };
    }
    else {
        %error = (
            message => $error || $self->message('bad'), @_
        );
    }

    return $self->json_fragment(
        status => 'error', %error
    );
}

# Any framework code that wants to display a message about "x" will use
# the text returned by message("x"). Subclasses must override messages()
# to return a hash of messages.

sub messages {
    return (
        bad => "Invalid request"
    );
}

sub message {
    my ($self, $name) = @_;
    my %messages = $self->messages;
    return $messages{$name} || $name;
}

# Returns an object of the subclass of G::Db::Table corresponding to the
# given name (or the caller's class name, if none is given).

sub table {
    my $self = shift;
    my $name = shift;

    unless ($name) {
        ($name = ref $self) =~ s/^[^:]*:://;
        if (my $dbclass = $self->can('dbclass')) {
            $name = $self->$dbclass();
        }
    }

    return Gadwall::Db::Table->new_table($self, $name, @_);
}

1;
