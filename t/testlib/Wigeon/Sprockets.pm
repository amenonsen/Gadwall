package Wigeon::Sprockets;

use strict;
use warnings;

use base 'Gadwall::Table';

sub columns {(
    sprocket_name => {
        required => 1,
        validate => qr/^[a-z]+$/
    },
    colour => {
        validate => qr/^(?:red|blue|green)$/i
    },
    teeth => {
        required => 1,
        validate => qr/^[1-9][0-9]*$/
    }
)}

1;
