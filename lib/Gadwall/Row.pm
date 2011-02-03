package Gadwall::Row;

use strict;
use warnings;

# This is a base class for everything that is mentioned in a rowclass()
# in a Gadwall::Table subclass. It doesn't do much, and that's probably
# the way it should be.

sub new {
    # Defined only to make Mojo::Loader happy.
}

# This function returns an unblessed hash of display fields for
# conversion to JSON.

sub display_hash {
    my $self = shift;
    return { %$self };
}

1;
