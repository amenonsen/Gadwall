package Wigeon::Widgets;

use strict;
use warnings;

use base 'Gadwall::Controller';

sub sprocket_colours {
    my $self = shift;
    my $ss = $self->new_controller('Sprockets');
    my $s = $ss->select_by_key(sprocket_name => "a");
    my $t = $ss->select_by_key(sprocket_name => "b");
    $self->render(text => $s->{colour}." ".$t->{colour}, format => 'txt');
}

sub sprocket_redness {
    my $self = shift;
    my $ss = $self->new_controller('Sprockets');
    my $s = $ss->select_by_key(
        sprocket_name => $self->param("sprocket_name")
    );
    $self->render(
        text => $s && $s->is_red ? "red" : "not red",
        format => 'txt'
    );
}

1;
