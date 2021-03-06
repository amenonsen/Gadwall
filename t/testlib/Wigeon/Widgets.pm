package Wigeon::Widgets;

use Mojo::Base 'Gadwall::Controller';

sub sprocket_colours {
    my $self = shift;
    my $ss = $self->table('Sprockets');
    my $s = $ss->select_by_key(1);
    my $t = $ss->select_by_key(2);
    $self->render_text($s->{colour}." ".$t->{colour});
}

sub sprocket_redness {
    my $self = shift;
    my $ss = $self->table('Sprockets');
    my $s = $ss->select_by_key($self->param("sprocket_id"));
    $self->render_text(
        $s && $s->is_red ? "red" : "not red"
    );
}

1;
