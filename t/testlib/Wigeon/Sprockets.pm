package Wigeon::Sprockets;

use strict;
use warnings;

use base 'Gadwall::Table';

use Wigeon::Sprocket;

sub columns {
    my $self = shift;
    return (
        sprocket_name => {
            required => 1,
            validate => qr/^[a-z]+$/
        },
        colour => {
            validate => qr/^(?:red|blue|green)$/i
        },
        teeth => {
            required => 1,
            validate => $self->valid('nznumber')
        }
    );
}

sub rowclass { "Wigeon::Sprocket" }
sub cache_rows { 1 }

sub approximate_blueness {
    my $self = shift;
    my $s = $self->select_by_key(
        sprocket_name => $self->param("sprocket_name")
    );
    $self->render(
        text => $s && $s->is_red ? "not blue" : "maybe blue",
        format => 'txt'
    );
}

1;
