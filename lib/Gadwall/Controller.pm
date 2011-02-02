package Gadwall::Controller;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Mojo::Loader;

# Returns a new controller initialised with the app, stash, and tx of
# the current controller. The controller to create may be identified by
# its full package name (e.g. "Gadwall::Users") or just the unique part
# (i.e. "Users" in this case).

sub new_controller {
    my ($self, $class) = @_;

    my $pkg = ref $self;
    if ($class !~ /::/ && $pkg =~ /::/) {
        $pkg =~ s/::[^:]+$//;
        for my $p ($pkg, "Gadwall") {
            unless (Mojo::Loader->load("${p}::$class")) {
                $class = "${p}::$class";
                last;
            }
        }
    }
    else {
        Mojo::Loader->load($class);
    }

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
