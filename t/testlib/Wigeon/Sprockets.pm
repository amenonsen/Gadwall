package Wigeon::Sprockets;

use strict;
use warnings;

use base 'Gadwall::Table';

sub cache_rows { 1 }

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

sub approximate_blueness {
    my $self = shift;
    my $s = $self->select_by_key($self->param("sprocket_id"));
    $self->render(
        text => $s && $s->is_red ? "not blue" : "maybe blue",
        format => 'txt'
    );
}

1;
