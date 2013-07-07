package Gadwall::Dequeue::Base;

use Mojo::Base -base;

sub new {
    my ($class, %opts) = @_;

    unless ($opts{app}) {
        die "Missing app parameter\n";
    }

    return bless \%opts, $class;
}

sub app {
    shift->{app}
}

1;
