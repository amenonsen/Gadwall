package Wigeon::Sprocket;

use Mojo::Base "Gadwall::Db::Row";

sub is_red {
    my $self = shift;
    return $self->{colour} eq "red";
}

1;
