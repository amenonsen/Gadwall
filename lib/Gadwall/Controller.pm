package Gadwall::Controller;

use strict;
use warnings;

use base 'Mojolicious::Controller';

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