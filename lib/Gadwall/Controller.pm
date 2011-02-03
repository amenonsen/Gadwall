package Gadwall::Controller;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Mojo::Loader;

# Takes the name of a class, like Sprockets, and returns its full name,
# like Wigeon::Sprockets (or Gadwall::Sprockets, if that is not found).
# Returns undef if neither is found.

sub class_name {
    my ($self, $name) = @_;

    if (!defined $name || $name =~ /::/) {
        return $name;
    }

    my $class;
    for my $p (ref $self->app, "Gadwall") {
        my $s = "${p}::$name";
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

# Helper functions to return JSON responses
#
# return $self->json_fragment(a => 1, b => "two")
# => {"a": 1, "b": "two"}

sub json_fragment {
    return shift->render(json => { @_ })
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
    my ($self, $error) = @_;

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

1;
