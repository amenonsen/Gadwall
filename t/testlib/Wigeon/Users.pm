package Wigeon::Users;
use Mojo::Base 'Gadwall::Users';

sub wrapped_json {
    my $self = shift;
    $self->stash(format => 'textarea');
    $self->json_ok("Foo");
}

1;
