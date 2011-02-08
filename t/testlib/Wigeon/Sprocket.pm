package Wigeon::Sprocket;

use strict;
use warnings;

use parent "Gadwall::Row";

sub is_red {
    my $self = shift;
    return $self->{colour} eq "red";
}

1;
