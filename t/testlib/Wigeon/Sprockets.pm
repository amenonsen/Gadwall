package Wigeon::Sprockets;

use strict;
use warnings;

use base 'Gadwall::Table';

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

1;
